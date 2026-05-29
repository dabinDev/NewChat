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
      databaseOpener: (_,
          {required onCreate, required onOpen, required version}) {
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

  test('close waits for an in-flight open and clears cached state', () async {
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
      databaseOpener: (_,
          {required onCreate, required onOpen, required version}) {
        openCount += 1;
        if (openCount == 1) {
          return completer.future;
        }
        return Future.value(secondDatabase);
      },
    );

    final opening = appDatabase.open();
    final closing = appDatabase.close();
    completer.complete(firstDatabase);

    expect(await opening, same(firstDatabase));
    await closing;
    verify(firstDatabase.close).called(1);

    expect(await appDatabase.open(), same(secondDatabase));
    expect(openCount, 2);
  });
}
