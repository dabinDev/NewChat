import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:newchat/core/storage/app_database.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:sqflite/sqflite.dart';

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockDatabase extends Mock implements Database {}

void main() {
  test('in-memory repository saves and lists session documents', () async {
    final repository = InMemorySessionRepository();
    final createdAt = DateTime.utc(2026, 5, 30);
    final document = _document(
      id: 'session-1',
      title: 'Hello',
      updatedAt: createdAt,
      messages: [
        _message(
          id: 'message-1',
          parts: const [MessagePart.text('hello')],
          at: createdAt,
        ),
      ],
    );

    await repository.saveDocument(document);

    final loaded = await repository.loadDocument('session-1');
    final metas = await repository.listMetas();

    expect(loaded!.title, 'Hello');
    expect(metas.single.lastMessagePreview, 'hello');
  });

  test('listMetas sorts sessions by updatedAt descending', () async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(
      _document(id: 'old', updatedAt: DateTime.utc(2026, 5, 30, 1)),
    );
    await repository.saveDocument(
      _document(id: 'new', updatedAt: DateTime.utc(2026, 5, 30, 3)),
    );
    await repository.saveDocument(
      _document(id: 'middle', updatedAt: DateTime.utc(2026, 5, 30, 2)),
    );

    final metas = await repository.listMetas();

    expect(metas.map((meta) => meta.id), ['new', 'middle', 'old']);
  });

  test('deleteSession removes a saved session', () async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(_document(id: 'session-1'));

    await repository.deleteSession('session-1');

    expect(await repository.loadDocument('session-1'), isNull);
    expect(await repository.listMetas(), isEmpty);
  });

  test('loadDocument returns null when session is missing', () async {
    final repository = InMemorySessionRepository();

    final loaded = await repository.loadDocument('missing');

    expect(loaded, isNull);
  });

  test('preview skips error and image parts because their type is not text',
      () async {
    final repository = InMemorySessionRepository();
    final document = _document(
      id: 'session-1',
      messages: [
        _message(
          id: 'text',
          parts: const [MessagePart.text('visible text')],
          at: DateTime.utc(2026, 5, 30, 1),
        ),
        _message(
          id: 'image',
          parts: [
            MessagePart.image(
              const AttachmentRef(
                id: 'attachment-1',
                localPath: '/tmp/image.png',
                mimeType: 'image/png',
              ),
            ),
          ],
          at: DateTime.utc(2026, 5, 30, 2),
        ),
        _message(
          id: 'error',
          parts: const [MessagePart.error('error details')],
          at: DateTime.utc(2026, 5, 30, 3),
        ),
      ],
    );

    await repository.saveDocument(document);

    final metas = await repository.listMetas();

    expect(metas.single.lastMessagePreview, 'visible text');
  });

  test('persistent repository reloads documents and metas across instances',
      () async {
    final appDatabase = _MockAppDatabase();
    final database = _MockDatabase();
    final sessionRows = <String, Map<String, Object?>>{};
    final metaRows = <String, Map<String, Object?>>{};
    when(appDatabase.open).thenAnswer((_) async => database);
    when(
      () => database.insert(
        'sessions',
        any(),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      ),
    ).thenAnswer((invocation) async {
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map<String, Object?>,
      );
      sessionRows[values['id']! as String] = values;
      return 1;
    });
    when(
      () => database.insert(
        'session_metas',
        any(),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      ),
    ).thenAnswer((invocation) async {
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map<String, Object?>,
      );
      metaRows[values['id']! as String] = values;
      return 1;
    });
    when(
      () => database.query(
        'sessions',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final id = (invocation.namedArguments[#whereArgs] as List<Object?>).single
          as String;
      final meta = metaRows[id];
      final session = sessionRows[id];
      if (session == null || meta == null || meta['is_deleted'] == 1) {
        return <Map<String, Object?>>[];
      }
      return <Map<String, Object?>>[session];
    });
    when(
      () => database.query(
        'session_metas',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        orderBy: any(named: 'orderBy'),
      ),
    ).thenAnswer((_) async {
      return metaRows.values.where((row) => row['is_deleted'] == 0).toList()
        ..sort(
          (a, b) => (b['updated_at']! as String)
              .compareTo(a['updated_at']! as String),
        );
    });
    when(
      () => database.delete(
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((invocation) async {
      final table = invocation.positionalArguments[0] as String;
      final id = (invocation.namedArguments[#whereArgs] as List<Object?>).single
          as String;
      if (table == 'sessions') {
        return sessionRows.remove(id) == null ? 0 : 1;
      }
      if (table == 'session_metas') {
        return metaRows.remove(id) == null ? 0 : 1;
      }
      return 0;
    });

    final firstRepository = PersistentSessionRepository(appDatabase);
    final older = _document(
      id: 'old-session',
      title: 'Old',
      updatedAt: DateTime.utc(2026, 5, 30, 1),
    );
    final newer = _document(
      id: 'new-session',
      title: 'New',
      updatedAt: DateTime.utc(2026, 5, 30, 2),
      messages: [
        _message(
          id: 'message-1',
          parts: const [MessagePart.text('persisted preview')],
          at: DateTime.utc(2026, 5, 30, 2),
        ),
      ],
    );

    await firstRepository.saveDocument(older);
    await firstRepository.saveDocument(newer);

    final secondRepository = PersistentSessionRepository(appDatabase);
    final metas = await secondRepository.listMetas();
    final loaded = await secondRepository.loadDocument('new-session');

    expect(metas.map((meta) => meta.id), ['new-session', 'old-session']);
    expect(metas.first.title, 'New');
    expect(metas.first.lastMessagePreview, 'persisted preview');
    expect(loaded!.id, 'new-session');
    expect(loaded.title, 'New');
    expect(loaded.messages.single.fullText, 'persisted preview');

    await secondRepository.deleteSession('new-session');

    expect(await secondRepository.loadDocument('new-session'), isNull);
    expect((await secondRepository.listMetas()).map((meta) => meta.id), [
      'old-session',
    ]);
  });

  test('persistent listMetas orders pinned sessions before recent unpinned',
      () async {
    final appDatabase = _MockAppDatabase();
    final database = _MockDatabase();
    final pinnedAt = DateTime.utc(2026, 5, 30, 1, 30).toIso8601String();
    final rows = [
      {
        'id': 'recent-unpinned',
        'title': 'Recent',
        'last_message_preview': 'recent',
        'provider_id': 'provider-1',
        'model_id': 'gpt-4o-mini',
        'created_at': DateTime.utc(2026, 5, 30).toIso8601String(),
        'updated_at': DateTime.utc(2026, 5, 30, 3).toIso8601String(),
        'is_deleted': 0,
        'is_pinned': 0,
        'pinned_at': null,
        'is_unread': 0,
      },
      {
        'id': 'older-pinned',
        'title': 'Pinned',
        'last_message_preview': 'pinned',
        'provider_id': 'provider-1',
        'model_id': 'gpt-4o-mini',
        'created_at': DateTime.utc(2026, 5, 30).toIso8601String(),
        'updated_at': DateTime.utc(2026, 5, 30, 1).toIso8601String(),
        'is_deleted': 0,
        'is_pinned': 1,
        'pinned_at': pinnedAt,
        'is_unread': 0,
      },
    ];

    when(appDatabase.open).thenAnswer((_) async => database);
    when(
      () => database.query(
        'session_metas',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        orderBy: any(named: 'orderBy'),
      ),
    ).thenAnswer((invocation) async {
      final orderBy = invocation.namedArguments[#orderBy] as String?;
      final sorted = List<Map<String, Object?>>.from(rows);
      if (orderBy == 'is_pinned DESC, pinned_at DESC, updated_at DESC') {
        sorted.sort((a, b) {
          final pinned = (b['is_pinned']! as int).compareTo(
            a['is_pinned']! as int,
          );
          if (pinned != 0) {
            return pinned;
          }
          final pinnedAtCompare = (b['pinned_at'] as String? ?? '').compareTo(
            a['pinned_at'] as String? ?? '',
          );
          if (pinnedAtCompare != 0) {
            return pinnedAtCompare;
          }
          return (b['updated_at']! as String).compareTo(
            a['updated_at']! as String,
          );
        });
      } else {
        sorted.sort(
          (a, b) => (b['updated_at']! as String).compareTo(
            a['updated_at']! as String,
          ),
        );
      }
      return sorted;
    });

    final repository = PersistentSessionRepository(appDatabase);

    final metas = await repository.listMetas();

    expect(metas.map((meta) => meta.id), [
      'older-pinned',
      'recent-unpinned',
    ]);
  });

  test('persistent repository round trips pinned and unread metadata',
      () async {
    final appDatabase = _MockAppDatabase();
    final database = _MockDatabase();
    final sessionRows = <String, Map<String, Object?>>{};
    final metaRows = <String, Map<String, Object?>>{};
    when(appDatabase.open).thenAnswer((_) async => database);
    when(
      () => database.insert(
        'sessions',
        any(),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      ),
    ).thenAnswer((invocation) async {
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map<String, Object?>,
      );
      sessionRows[values['id']! as String] = values;
      return 1;
    });
    when(
      () => database.insert(
        'session_metas',
        any(),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      ),
    ).thenAnswer((invocation) async {
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map<String, Object?>,
      );
      metaRows[values['id']! as String] = values;
      return 1;
    });
    when(
      () => database.query(
        'sessions',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final id = (invocation.namedArguments[#whereArgs] as List<Object?>).single
          as String;
      return [sessionRows[id]!];
    });
    when(
      () => database.query(
        'session_metas',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        orderBy: any(named: 'orderBy'),
      ),
    ).thenAnswer((_) async => metaRows.values.toList());
    final pinnedAt = DateTime.utc(2026, 5, 30, 4);
    final repository = PersistentSessionRepository(appDatabase);

    await repository.saveDocument(
      _document(
        id: 'flagged',
        isPinned: true,
        pinnedAt: pinnedAt,
        isUnread: true,
      ),
    );

    final meta = (await repository.listMetas()).single;
    final loaded = await repository.loadDocument('flagged');

    expect(meta.isPinned, isTrue);
    expect(meta.pinnedAt, pinnedAt);
    expect(meta.isUnread, isTrue);
    expect(loaded!.isPinned, isTrue);
    expect(loaded.pinnedAt, pinnedAt);
    expect(loaded.isUnread, isTrue);
  });

  test('persistent repository hides soft deleted sessions', () async {
    final appDatabase = _MockAppDatabase();
    final database = _MockDatabase();
    final sessionRows = <String, Map<String, Object?>>{};
    final metaRows = <String, Map<String, Object?>>{};
    when(appDatabase.open).thenAnswer((_) async => database);
    when(
      () => database.insert(
        'sessions',
        any(),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      ),
    ).thenAnswer((invocation) async {
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map<String, Object?>,
      );
      sessionRows[values['id']! as String] = values;
      return 1;
    });
    when(
      () => database.insert(
        'session_metas',
        any(),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      ),
    ).thenAnswer((invocation) async {
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map<String, Object?>,
      );
      metaRows[values['id']! as String] = values;
      return 1;
    });
    when(
      () => database.update(
        'session_metas',
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((invocation) async {
      final values = invocation.positionalArguments[1] as Map<String, Object?>;
      final id = (invocation.namedArguments[#whereArgs] as List<Object?>).single
          as String;
      metaRows[id] = {...metaRows[id]!, ...values};
      return 1;
    });
    when(
      () => database.query(
        'sessions',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final id = (invocation.namedArguments[#whereArgs] as List<Object?>).single
          as String;
      if (metaRows[id]?['is_deleted'] == 1) {
        return <Map<String, Object?>>[];
      }
      return [sessionRows[id]!];
    });
    when(
      () => database.query(
        'session_metas',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        orderBy: any(named: 'orderBy'),
      ),
    ).thenAnswer((_) async {
      return metaRows.values.where((row) => row['is_deleted'] == 0).toList();
    });
    final repository = PersistentSessionRepository(appDatabase);

    await repository.saveDocument(_document(id: 'visible'));
    await repository.saveDocument(_document(id: 'deleted'));
    await repository.softDeleteSession('deleted');

    expect((await repository.listMetas()).map((meta) => meta.id), ['visible']);
    expect(await repository.loadDocument('deleted'), isNull);
    expect(sessionRows, contains('deleted'));
  });

  test('production session repository is persistent', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(sessionRepositoryProvider),
      isA<PersistentSessionRepository>(),
    );
  });
}

ChatSessionDocument _document({
  required String id,
  String title = 'Title',
  DateTime? updatedAt,
  List<ChatMessage>? messages,
  bool isPinned = false,
  DateTime? pinnedAt,
  bool isUnread = false,
}) {
  final createdAt = DateTime.utc(2026, 5, 30);
  return ChatSessionDocument(
    id: id,
    title: title,
    providerId: 'provider-1',
    modelId: 'gpt-4o-mini',
    systemPrompt: '',
    messages: messages ??
        [
          _message(
            id: 'message-1',
            parts: const [MessagePart.text('hello')],
            at: updatedAt ?? createdAt,
          ),
        ],
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    schemaVersion: 1,
    isPinned: isPinned,
    pinnedAt: pinnedAt,
    isUnread: isUnread,
  );
}

ChatMessage _message({
  required String id,
  required List<MessagePart> parts,
  required DateTime at,
}) =>
    ChatMessage(
      id: id,
      role: ChatRole.user,
      state: MessageState.completed,
      parts: parts,
      createdAt: at,
      updatedAt: at,
    );
