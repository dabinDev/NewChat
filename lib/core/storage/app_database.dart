import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Database? _database;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'newchat.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (database, version) => _createSchema(database),
      onOpen: _createSchema,
    );
    return _database!;
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
    final existing = _database;
    if (existing == null) {
      return;
    }
    await existing.close();
    _database = null;
  }
}
