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
  Future<void>? _closing;
  int _lifecycleGeneration = 0;

  static const _openCancelledMessage =
      'Database open was cancelled by close(). Retry open().';

  Future<Database> open() async {
    final closing = _closing;
    if (closing != null) {
      await closing;
    }

    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final opening = _opening;
    if (opening != null) {
      return opening;
    }

    final nextOpening = _openGuarded();
    _opening = nextOpening;
    try {
      return await nextOpening;
    } finally {
      if (identical(_opening, nextOpening)) {
        _opening = null;
      }
    }
  }

  Future<Database> _openGuarded() async {
    final openingGeneration = _lifecycleGeneration;
    final database = await _openDatabase();
    try {
      if (openingGeneration != _lifecycleGeneration) {
        // close() invalidated this open while it was in flight. Fail clearly so
        // callers retry instead of receiving a handle already closed by close().
        throw StateError(_openCancelledMessage);
      }
      _database = database;
      return database;
    } finally {
      if (openingGeneration != _lifecycleGeneration) {
        await database.close();
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
  is_deleted INTEGER NOT NULL DEFAULT 0,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  pinned_at TEXT NULL,
  is_unread INTEGER NOT NULL DEFAULT 0
);
''');
    await _ensureSessionMetaColumns(database);
    await database.execute('''
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  payload_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''');
  }

  Future<void> _ensureSessionMetaColumns(Database database) async {
    final rows = await database.rawQuery('PRAGMA table_info(session_metas)');
    final columnNames =
        rows.map((row) => row['name']).whereType<String>().toSet();

    if (!columnNames.contains('is_pinned')) {
      await database.execute(
        'ALTER TABLE session_metas '
        'ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!columnNames.contains('pinned_at')) {
      await database.execute(
        'ALTER TABLE session_metas ADD COLUMN pinned_at TEXT NULL',
      );
    }
    if (!columnNames.contains('is_unread')) {
      await database.execute(
        'ALTER TABLE session_metas '
        'ADD COLUMN is_unread INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> close() async {
    final opening = _opening;
    _lifecycleGeneration += 1;
    Future<void>? closing;
    try {
      if (opening != null) {
        try {
          await opening;
        } on StateError catch (error) {
          if (error.message != _openCancelledMessage) {
            rethrow;
          }
        }
      }
      final existing = _database;
      _database = null;
      if (existing != null) {
        closing = existing.close();
        _closing = closing;
        await closing;
      }
    } finally {
      _database = null;
      _opening = null;
      if (identical(_closing, closing)) {
        _closing = null;
      }
    }
  }
}
