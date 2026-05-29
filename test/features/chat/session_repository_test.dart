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
