import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../models/complaint_model.dart';
import 'app_database.dart';
import 'complaint_remote_service.dart';

class ComplaintService {
  ComplaintService({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  static final StreamController<String> _changes = StreamController.broadcast();
  final AppDatabase _database;
  final ComplaintRemoteService _remote = ComplaintRemoteService();
  bool _syncing = false;

  Stream<List<ComplaintModel>> watchForUser(String userId) async* {
    yield await getForUser(userId);
    yield* _changes.stream
        .where(
          (changedUserId) => changedUserId == userId || changedUserId == '*',
        )
        .asyncMap((_) => getForUser(userId));
  }

  Stream<List<ComplaintModel>> watchAll() async* {
    yield await _getAll();
    yield* _changes.stream.asyncMap((_) => _getAll());
  }

  Future<List<ComplaintModel>> getForUser(String userId) async {
    final db = await _database.database;
    final rows = await db.query(
      'complaints',
      where: 'userId = ? AND isDeleted = 0',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return Future.wait(rows.map(_fromRow));
  }

  Future<List<ComplaintModel>> _getAll() async {
    final db = await _database.database;
    final rows = await db.query('complaints', where: 'isDeleted = 0', orderBy: 'createdAt DESC');
    return Future.wait(rows.map(_fromRow));
  }

  Future<ComplaintModel?> getById(String complaintId) async {
    final db = await _database.database;
    final rows = await db.query(
      'complaints',
      where: 'id = ?',
      whereArgs: [complaintId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> create(ComplaintModel complaint) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('complaints', {
        'id': complaint.id,
        'userId': complaint.userId,
        'locationId': complaint.locationId.trim(),
        'subject': complaint.subject.trim(),
        'category': complaint.category.name,
        'description': complaint.description.trim(),
        'photos': jsonEncode(complaint.photos),
        'status': complaint.status.name,
        'priority': complaint.priority.name,
        'isDraft': complaint.isDraft ? 1 : 0,
        'syncStatus': complaint.syncStatus.name,
        'createdAt': complaint.createdAt.toUtc().toIso8601String(),
      });
      for (final entry in complaint.history) {
        await txn.insert('complaint_history', {
          'complaintId': complaint.id,
          'status': entry.status.name,
          'date': entry.date.toUtc().toIso8601String(),
        });
      }
      if (complaint.history.isEmpty) {
        await txn.insert('complaint_history', {
          'complaintId': complaint.id,
          'status': complaint.status.name,
          'date': complaint.createdAt.toUtc().toIso8601String(),
        });
      }
    });
    _changes.add('*');
  }

  Future<void> update(ComplaintModel complaint) async {
    final db = await _database.database;
    final previousRows = await db.query(
      'complaints',
      columns: ['photos'],
      where: 'id = ? AND userId = ?',
      whereArgs: [complaint.id, complaint.userId],
      limit: 1,
    );
    await db.transaction((txn) async {
      await txn.update(
        'complaints',
        {
          'locationId': complaint.locationId.trim(),
          'subject': complaint.subject.trim(),
          'category': complaint.category.name,
          'description': complaint.description.trim(),
          'photos': jsonEncode(complaint.photos),
          'priority': complaint.priority.name,
          'isDraft': complaint.isDraft ? 1 : 0,
          'syncStatus': ComplaintSyncStatus.pending.name,
        },
        where: 'id = ? AND userId = ?',
        whereArgs: [complaint.id, complaint.userId],
      );
    });
    _changes.add('*');
    if (previousRows.isNotEmpty) {
      final removedPaths = List<String>.from(
        jsonDecode(previousRows.first['photos']! as String) as List,
      ).where((path) => !complaint.photos.contains(path));
      for (final path in removedPaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // A missing cached photo does not block complaint editing.
        }
      }
    }
  }

  Future<void> updateStatus(String complaintId, ComplaintStatus status) async {
    final db = await _database.database;
    final rows = await db.query(
      'complaints',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [complaintId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    if (rows.first['status'] == status.name) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'complaints',
        {'status': status.name, 'syncStatus': ComplaintSyncStatus.pending.name},
        where: 'id = ?',
        whereArgs: [complaintId],
      );
      await txn.insert('complaint_history', {
        'complaintId': complaintId,
        'status': status.name,
        'date': now,
      });
    });
    _changes.add('*');
  }

  Future<bool> syncNow() async {
    if (_syncing) return false;
    _syncing = true;
    var changed = false;
    try {
      final db = await _database.database;
      final pending = await db.query(
        'complaints',
        where: 'syncStatus = ? AND isDraft = 0',
        whereArgs: [ComplaintSyncStatus.pending.name],
        orderBy: 'createdAt ASC',
      );
      for (final row in pending) {
        final complaint = await _fromRow(row);
        await _remote.upload(_toRemote(complaint));
        await db.update('complaints', {'syncStatus': ComplaintSyncStatus.synced.name}, where: 'id = ?', whereArgs: [complaint.id]);
        changed = true;
      }

      final remoteRows = await _remote.fetchAll();
      for (final row in remoteRows) {
        final localRows = await db.query('complaints', columns: ['syncStatus', 'isDraft', 'isDeleted'], where: 'id = ?', whereArgs: [row['id']], limit: 1);
        if (localRows.isNotEmpty && (localRows.first['isDraft'] == 1 || localRows.first['syncStatus'] == ComplaintSyncStatus.pending.name)) continue;
        if (row['deleted'] == true) {
          await db.delete('complaints', where: 'id = ?', whereArgs: [row['id']]);
          changed = true;
          continue;
        }
        await _saveRemote(db, row);
        changed = true;
      }
      if (changed) _changes.add('*');
      return true;
    } on Object {
      // Keep the local SQLite outbox. A later app resume or retry will sync it.
      return false;
    } finally {
      _syncing = false;
    }
  }

  Map<String, dynamic> _toRemote(ComplaintModel item) => {
    'id': item.id,
    'userId': item.userId,
    'locationId': item.locationId,
    'subject': item.subject,
    'category': item.category.name,
    'description': item.description,
    'status': item.status.name,
    'priority': item.priority.name,
    'createdAt': item.createdAt.toUtc().toIso8601String(),
    'deleted': item.isDeleted,
    'history': item.history.map((entry) => {'status': entry.status.name, 'date': entry.date.toUtc().toIso8601String()}).toList(),
  };

  Future<void> _saveRemote(Database db, Map<String, dynamic> row) async {
    final existingRows = await db.query('complaints', columns: ['photos'], where: 'id = ?', whereArgs: [row['id']], limit: 1);
    final item = {
      'id': row['id'], 'userId': row['userId'], 'locationId': row['locationId'],
      'subject': row['subject'], 'category': row['category'], 'description': row['description'],
      'photos': existingRows.isEmpty ? '[]' : existingRows.first['photos'], 'status': row['status'], 'priority': row['priority'] ?? ComplaintPriority.moyenne.name,
      'createdAt': row['createdAt'], 'isDraft': 0, 'syncStatus': ComplaintSyncStatus.synced.name, 'isDeleted': 0,
    };
    await db.transaction((txn) async {
      final remoteUserId = row['userId'] as String;
      final users = await txn.query('users', columns: ['id'], where: 'id = ?', whereArgs: [remoteUserId], limit: 1);
      if (users.isEmpty) {
        final fakeSalt = base64Encode(utf8.encode('remote-account-no-login'));
        await txn.insert('users', {
          'id': remoteUserId,
          'nom': 'Compte partagé',
          'prenom': 'Utilisateur',
          'email': 'remote_$remoteUserId@studenthub.invalid',
          'telephone': 'remote_$remoteUserId',
          'rolePrincipal': 'locataire',
          'roleSecondaire': null,
          'photo': null,
          'preferences': '{}',
          'passwordHash': fakeSalt,
          'passwordSalt': fakeSalt,
          'createdAt': row['createdAt'],
          'emailVerified': 1,
          'accountStatus': 'approved',
          'isRemote': 1,
        });
      }
      await txn.insert('complaints', item, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('complaint_history', where: 'complaintId = ?', whereArgs: [row['id']]);
      final history = row['history'] is List ? row['history'] as List : const [];
      for (final entry in history) {
        final value = Map<String, dynamic>.from(entry as Map);
        await txn.insert('complaint_history', {'complaintId': row['id'], 'status': value['status'], 'date': value['date']});
      }
    });
  }

  Future<void> delete(String complaintId, {required String userId}) async {
    final db = await _database.database;
    final rows = await db.query(
      'complaints',
      columns: ['photos', 'isDraft'],
      where: 'id = ? AND userId = ?',
      whereArgs: [complaintId, userId],
      limit: 1,
    );
    if (rows.isNotEmpty && rows.first['isDraft'] == 1) {
      await db.delete('complaints', where: 'id = ? AND userId = ?', whereArgs: [complaintId, userId]);
    } else {
      await db.update('complaints', {
        'isDeleted': 1,
        'syncStatus': ComplaintSyncStatus.pending.name,
      }, where: 'id = ? AND userId = ?', whereArgs: [complaintId, userId]);
    }
    _changes.add('*');
    if (rows.isNotEmpty) {
      final paths = List<String>.from(
        jsonDecode(rows.first['photos']! as String) as List,
      );
      for (final path in paths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // A missing cached photo does not block complaint deletion.
        }
      }
    }
  }

  Future<ComplaintModel> _fromRow(Map<String, Object?> row) async {
    final db = await _database.database;
    final historyRows = await db.query(
      'complaint_history',
      where: 'complaintId = ?',
      whereArgs: [row['id']],
      orderBy: 'date ASC',
    );
    return ComplaintModel(
      id: row['id']! as String,
      userId: row['userId']! as String,
      locationId: row['locationId']! as String,
      subject: row['subject']! as String,
      category: ComplaintCategory.values.firstWhere(
        (value) => value.name == row['category'],
        orElse: () => ComplaintCategory.autre,
      ),
      description: row['description']! as String,
      photos: List<String>.from(jsonDecode(row['photos']! as String) as List),
      status: ComplaintStatus.values.firstWhere(
        (value) => value.name == row['status'],
        orElse: () => ComplaintStatus.ouverte,
      ),
      createdAt: DateTime.parse(row['createdAt']! as String),
      priority: ComplaintPriority.values.firstWhere(
        (value) => value.name == row['priority'],
        orElse: () => ComplaintPriority.moyenne,
      ),
      history: historyRows
          .map(
            (entry) => ComplaintHistoryEntry(
              status: ComplaintStatus.values.firstWhere(
                (value) => value.name == entry['status'],
                orElse: () => ComplaintStatus.ouverte,
              ),
              date: DateTime.parse(entry['date']! as String),
            ),
          )
          .toList(),
      isDraft: (row['isDraft'] as int? ?? 0) == 1,
      syncStatus: ComplaintSyncStatus.values.firstWhere(
        (value) => value.name == row['syncStatus'],
        orElse: () => ComplaintSyncStatus.pending,
      ),
      isDeleted: (row['isDeleted'] as int? ?? 0) == 1,
    );
  }
}
