import 'dart:convert';

import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/storage/app_database.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class SessionRepository {
  Future<List<ChatSessionMeta>> listMetas();
  Future<ChatSessionDocument?> loadDocument(String id);
  Future<void> saveDocument(ChatSessionDocument document);
  Future<void> deleteSession(String id);
}

class InMemorySessionRepository implements SessionRepository {
  final Map<String, ChatSessionDocument> _documents = {};

  @override
  Future<void> deleteSession(String id) async {
    _documents.remove(id);
  }

  @override
  Future<ChatSessionDocument?> loadDocument(String id) async => _documents[id];

  @override
  Future<List<ChatSessionMeta>> listMetas() async {
    final metas = _documents.values.map(_toMeta).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return metas;
  }

  @override
  Future<void> saveDocument(ChatSessionDocument document) async {
    _documents[document.id] = document;
  }

  ChatSessionMeta _toMeta(ChatSessionDocument document) => document.meta;
}

class PersistentSessionRepository implements SessionRepository {
  PersistentSessionRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> deleteSession(String id) async {
    final database = await _appDatabase.open();
    await database.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    await database.delete(
      'session_metas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<ChatSessionDocument?> loadDocument(String id) async {
    final database = await _appDatabase.open();
    final rows = await database.query(
      'sessions',
      columns: const ['payload_json'],
      where: '''
id = ? AND EXISTS (
  SELECT 1
  FROM session_metas
  WHERE session_metas.id = sessions.id
    AND session_metas.is_deleted = 0
)
''',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rows.single['payload_json']! as String)
        as Map<String, Object?>;
    return ChatSessionDocument.fromJson(decoded);
  }

  @override
  Future<List<ChatSessionMeta>> listMetas() async {
    final database = await _appDatabase.open();
    final rows = await database.query(
      'session_metas',
      columns: const [
        'id',
        'title',
        'last_message_preview',
        'provider_id',
        'model_id',
        'created_at',
        'updated_at',
        'is_deleted',
      ],
      where: 'is_deleted = ?',
      whereArgs: const [0],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_metaFromRow).toList();
  }

  @override
  Future<void> saveDocument(ChatSessionDocument document) async {
    final database = await _appDatabase.open();
    await database.insert(
      'sessions',
      {
        'id': document.id,
        'payload_json': jsonEncode(document.toJson()),
        'updated_at': document.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await database.insert(
      'session_metas',
      _metaToRow(document.meta),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, Object?> _metaToRow(ChatSessionMeta meta) => {
        'id': meta.id,
        'title': meta.title,
        'last_message_preview': meta.lastMessagePreview,
        'provider_id': meta.providerId,
        'model_id': meta.modelId,
        'created_at': meta.createdAt.toIso8601String(),
        'updated_at': meta.updatedAt.toIso8601String(),
        'is_deleted': meta.isDeleted ? 1 : 0,
      };

  ChatSessionMeta _metaFromRow(Map<String, Object?> row) => ChatSessionMeta(
        id: row['id']! as String,
        title: row['title']! as String,
        lastMessagePreview: row['last_message_preview']! as String,
        providerId: row['provider_id']! as String,
        modelId: row['model_id']! as String,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
        isDeleted: (row['is_deleted']! as int) != 0,
        schemaVersion: AppConstants.schemaVersion,
      );
}
