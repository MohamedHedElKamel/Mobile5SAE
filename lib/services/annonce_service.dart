import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/annonce.dart';
import 'database_helper.dart';
import 'photo_storage.dart';

class AnnonceService {
  AnnonceService({DatabaseHelper? databaseHelper, PhotoStorage? photoStorage})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
      _photoStorage = photoStorage ?? PhotoStorage();

  final DatabaseHelper _databaseHelper;
  final PhotoStorage _photoStorage;
  static int _lastId = 0;

  Future<List<Annonce>> lister() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('annonces', orderBy: 'rowid DESC');
    return rows.map(_fromRow).toList();
  }

  Future<List<Annonce>> listerParProprietaire(String proprietaireId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'annonces',
      where: 'proprietaireId = ?',
      whereArgs: [proprietaireId],
      orderBy: 'rowid DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> ajouter(Annonce annonce) async {
    final db = await _databaseHelper.database;
    final photos = await _photoStorage.copierPhotos(annonce.photos);
    try {
      await db.insert(
        'annonces',
        _toRow(annonce.copyWith(id: await _nouvelId(db), photos: photos)),
      );
    } catch (_) {
      for (final photo in photos) {
        await _photoStorage.supprimerSiInterne(photo);
      }
      rethrow;
    }
  }

  Future<void> modifier(Annonce annonce) async {
    final db = await _databaseHelper.database;
    final rows = await db.query('annonces', where: 'id = ?', whereArgs: [annonce.id], limit: 1);
    if (rows.isEmpty) throw StateError('Annonce introuvable: ${annonce.id}');
    final oldPhotos = _decodePhotos(rows.first['photos']);
    final oldSet = oldPhotos.toSet();
    final retained = annonce.photos.where(oldSet.contains).toList();
    final newSources = annonce.photos.where((photo) => !oldSet.contains(photo)).toList();
    final copied = await _photoStorage.copierPhotos(newSources);
    final updatedPhotos = [...retained, ...copied];
    try {
      final count = await db.update(
        'annonces',
        _toRow(annonce.copyWith(photos: updatedPhotos))..remove('id'),
        where: 'id = ?',
        whereArgs: [annonce.id],
      );
      if (count == 0) throw StateError('Annonce introuvable: ${annonce.id}');
    } catch (_) {
      for (final photo in copied) {
        await _photoStorage.supprimerSiInterne(photo);
      }
      rethrow;
    }
    for (final photo in oldPhotos.where((photo) => !updatedPhotos.contains(photo))) {
      await _photoStorage.supprimerSiInterne(photo);
    }
  }

  Future<void> supprimer(String id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query('annonces', columns: ['photos'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    await db.delete('annonces', where: 'id = ?', whereArgs: [id]);
    for (final photo in _decodePhotos(rows.first['photos'])) {
      await _photoStorage.supprimerSiInterne(photo);
    }
  }

  Future<String> _nouvelId(Database db) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastId = now > _lastId ? now : _lastId + 1;
    while ((await db.query(
      'annonces',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: ['$_lastId'],
      limit: 1,
    )).isNotEmpty) {
      _lastId++;
    }
    return '$_lastId';
  }

  Map<String, Object?> _toRow(Annonce annonce) => {
    ...annonce.toJson(),
    'photos': jsonEncode(annonce.photos),
  };

  Annonce _fromRow(Map<String, Object?> row) => Annonce.fromJson({
    ...row,
    'photos': _decodePhotos(row['photos']),
  });

  List<String> _decodePhotos(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    return (decoded as List).map((photo) => photo as String).toList();
  }
}
