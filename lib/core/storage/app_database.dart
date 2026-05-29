import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

typedef DatabasesPathProvider = Future<String> Function();
typedef DatabaseOpener = Future<Database> Function(
  String path, {
  required int version,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseOpenFn onOpen,
});

class AppDatabase {
  AppDatabase({
    DatabasesPathProvider? databasesPathProvider,
    DatabaseOpener? databaseOpener,
  })  : _databasesPathProvider = databasesPathProvider ?? getDatabasesPath,
        _databaseOpener = databaseOpener ?? openDatabase;

  final DatabasesPathProvider _databasesPathProvider;
  final DatabaseOpener _databaseOpener;

  Database? _database;
  Future<Database>? _opening;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final opening = _opening;
    if (opening != null) {
      return opening;
    }

    final nextOpening = _openDatabase();
    _opening = nextOpening;
    try {
      _database = await nextOpening;
      return _database!;
    } finally {
      if (identical(_opening, nextOpening)) {
        _opening = null;
      }
    }
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await _databasesPathProvider();
    final path = p.join(databasesPath, 'newchat.db');
    return _databaseOpener(
      path,
      version: 1,
      onCreate: (database, version) => _createSchema(database),
      onOpen: _createSchema,
    );
  }

  Future<void> _createSchema(Database database) async {
    await database.execute('''
CREATE TABLE IF NOT EXISTS app_kv (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''');
    await database.execute('''
CREATE TABLE IF NOT EXISTS session_metas (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  last_message_preview TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  model_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0
);
''');
    await database.execute('''
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  payload_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''');
  }

  Future<void> close() async {
    final opening = _opening;
    try {
      if (opening != null) {
        await opening;
      }
      final existing = _database;
      if (existing != null) {
        await existing.close();
      }
    } finally {
      _database = null;
      _opening = null;
    }
  }
}
