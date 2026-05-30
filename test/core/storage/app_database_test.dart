import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:newchat/core/storage/app_database.dart';
import 'package:sqflite/sqflite.dart';

class _MockDatabase extends Mock implements Database {}

void main() {
  test('open shares an in-flight database open across concurrent callers',
      () async {
    final completer = Completer<Database>();
    final database = _MockDatabase();
    var openCount = 0;
    when(() => database.isOpen).thenReturn(true);

    final appDatabase = AppDatabase(
      databasesPathProvider: () async => '/tmp',
      databaseOpener: (
        _, {
        required onCreate,
        required onOpen,
        required version,
      }) {
        openCount += 1;
        return completer.future;
      },
    );

    final first = appDatabase.open();
    final second = appDatabase.open();
    await Future<void>.delayed(Duration.zero);

    expect(openCount, 1);

    completer.complete(database);

    expect(await first, same(database));
    expect(await second, same(database));
    expect(openCount, 1);
  });

  test('open callers fail clearly when close is requested while opening',
      () async {
    final completer = Completer<Database>();
    final firstDatabase = _MockDatabase();
    final secondDatabase = _MockDatabase();
    var openCount = 0;
    when(() => firstDatabase.isOpen).thenReturn(true);
    when(() => secondDatabase.isOpen).thenReturn(true);
    when(firstDatabase.close).thenAnswer((_) async {});
    when(secondDatabase.close).thenAnswer((_) async {});

    final appDatabase = AppDatabase(
      databasesPathProvider: () async => '/tmp',
      databaseOpener: (
        _, {
        required onCreate,
        required onOpen,
        required version,
      }) {
        openCount += 1;
        if (openCount == 1) {
          return completer.future;
        }
        return Future.value(secondDatabase);
      },
    );

    final firstOpening = appDatabase.open();
    final secondOpening = appDatabase.open();
    final closing = appDatabase.close();
    completer.complete(firstDatabase);

    await expectLater(firstOpening, throwsA(isA<StateError>()));
    await expectLater(secondOpening, throwsA(isA<StateError>()));
    await closing;
    verify(firstDatabase.close).called(1);

    expect(await appDatabase.open(), same(secondDatabase));
    expect(openCount, 2);
  });

  test('open waits for pending close and returns a fresh database', () async {
    final closeCompleter = Completer<void>();
    final firstDatabase = _MockDatabase();
    final secondDatabase = _MockDatabase();
    var openCount = 0;
    when(() => firstDatabase.isOpen).thenReturn(true);
    when(() => secondDatabase.isOpen).thenReturn(true);
    when(firstDatabase.close).thenAnswer((_) => closeCompleter.future);
    when(secondDatabase.close).thenAnswer((_) async {});

    final appDatabase = AppDatabase(
      databasesPathProvider: () async => '/tmp',
      databaseOpener: (
        _, {
        required onCreate,
        required onOpen,
        required version,
      }) {
        openCount += 1;
        if (openCount == 1) {
          return Future.value(firstDatabase);
        }
        return Future.value(secondDatabase);
      },
    );

    expect(await appDatabase.open(), same(firstDatabase));

    final closing = appDatabase.close();
    await Future<void>.delayed(Duration.zero);
    final opening = appDatabase.open();
    await Future<void>.delayed(Duration.zero);

    expect(openCount, 1);
    closeCompleter.complete();

    expect(await opening, same(secondDatabase));
    await expectLater(closing, completes);
    expect(openCount, 2);
    verify(firstDatabase.close).called(1);
  });

  test('open creates idempotent session meta flag columns', () async {
    final database = _MockDatabase();
    final statements = <String>[];
    when(() => database.isOpen).thenReturn(true);
    when(() => database.execute(any())).thenAnswer((invocation) async {
      statements.add(invocation.positionalArguments.first as String);
    });
    when(() => database.rawQuery('PRAGMA table_info(session_metas)'))
        .thenAnswer(
      (_) async => [
        {'name': 'id'},
        {'name': 'title'},
        {'name': 'last_message_preview'},
        {'name': 'provider_id'},
        {'name': 'model_id'},
        {'name': 'created_at'},
        {'name': 'updated_at'},
        {'name': 'is_deleted'},
      ],
    );

    final appDatabase = AppDatabase(
      databasesPathProvider: () async => '/tmp',
      databaseOpener: (
        _, {
        required onCreate,
        required onOpen,
        required version,
      }) async {
        await onOpen(database);
        return database;
      },
    );

    await appDatabase.open();

    expect(
      statements,
      contains(
        'ALTER TABLE session_metas '
        'ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
      ),
    );
    expect(
      statements,
      contains('ALTER TABLE session_metas ADD COLUMN pinned_at TEXT NULL'),
    );
    expect(
      statements,
      contains(
        'ALTER TABLE session_metas '
        'ADD COLUMN is_unread INTEGER NOT NULL DEFAULT 0',
      ),
    );
  });
}
