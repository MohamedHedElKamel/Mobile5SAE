import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._({String? path}) : _path = path;

  static final DatabaseHelper instance = DatabaseHelper._();

  /// A separate helper for tests, typically with [path] set to ':memory:'.
  factory DatabaseHelper.forTests({String path = ':memory:'}) =>
      DatabaseHelper._(path: path);

  final String? _path;
  Future<Database>? _opening;

  Future<Database> get database {
    final opened = _opening;
    if (opened != null) return opened;
    final future = _open().catchError((Object error, StackTrace stackTrace) {
      _opening = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _opening = future;
    return future;
  }

  Future<Database> _open() async {
    final path = _path ?? p.join(await getDatabasesPath(), 'studenthub.db');
    return openDatabase(
      path,
      version: 7,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY, nom TEXT NOT NULL, prenom TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE COLLATE NOCASE, telephone TEXT NOT NULL UNIQUE,
        rolePrincipal TEXT NOT NULL, roleSecondaire TEXT, photo TEXT,
        preferences TEXT NOT NULL DEFAULT '{}', passwordHash TEXT NOT NULL,
        passwordSalt TEXT NOT NULL, createdAt TEXT NOT NULL,
        emailVerified INTEGER NOT NULL DEFAULT 0,
        accountStatus TEXT NOT NULL DEFAULT 'pending', isRemote INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute('''
      CREATE TABLE complaints (
        id TEXT PRIMARY KEY, userId TEXT NOT NULL, locationId TEXT NOT NULL,
        subject TEXT NOT NULL, category TEXT NOT NULL, description TEXT NOT NULL,
        photos TEXT NOT NULL DEFAULT '[]', status TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'moyenne', isDraft INTEGER NOT NULL DEFAULT 0,
        syncStatus TEXT NOT NULL DEFAULT 'pending', isDeleted INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE complaint_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT, complaintId TEXT NOT NULL,
        status TEXT NOT NULL, date TEXT NOT NULL,
        FOREIGN KEY (complaintId) REFERENCES complaints(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX complaints_user_date ON complaints(userId, createdAt DESC)');
    await _createAnnonces(db);
  }

  Future<void> _createAnnonces(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE annonces (
        id TEXT PRIMARY KEY,
        titre TEXT NOT NULL,
        description TEXT NOT NULL,
        typeLocation TEXT NOT NULL,
        loyer REAL NOT NULL,
        surface REAL NOT NULL,
        chambres INTEGER NOT NULL,
        etage INTEGER,
        ville TEXT NOT NULL,
        quartier TEXT NOT NULL,
        adresse TEXT NOT NULL,
        photos TEXT NOT NULL DEFAULT '[]',
        statut TEXT NOT NULL DEFAULT 'enAttente',
        proprietaireId TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX annonces_proprietaire ON annonces(proprietaireId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE complaints ADD COLUMN priority TEXT NOT NULL DEFAULT 'moyenne'");
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE users ADD COLUMN emailVerified INTEGER NOT NULL DEFAULT 1');
      await db.execute("ALTER TABLE users ADD COLUMN accountStatus TEXT NOT NULL DEFAULT 'approved'");
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE complaints ADD COLUMN isDraft INTEGER NOT NULL DEFAULT 0');
      await db.execute("ALTER TABLE complaints ADD COLUMN syncStatus TEXT NOT NULL DEFAULT 'pending'");
    }
    if (oldVersion < 5) await db.execute('ALTER TABLE complaints ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
    if (oldVersion < 6) await db.execute('ALTER TABLE users ADD COLUMN isRemote INTEGER NOT NULL DEFAULT 0');
    if (oldVersion < 7) await _createAnnonces(db);
  }

  Future<void> fermer() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    _opening = null;
  }
}

