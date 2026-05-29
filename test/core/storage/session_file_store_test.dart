import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/storage/session_file_store.dart';

void main() {
  group('SessionFileStore path validation', () {
    final store = SessionFileStore(
      documentsDirectoryProvider: () async => Directory.systemTemp,
    );

    test('rejects unsafe session ids', () {
      for (final sessionId in ['', '..', '../x', 'x/y']) {
        expect(
          () => store.attachmentsDirectory(sessionId),
          throwsArgumentError,
          reason: 'Expected "$sessionId" to be rejected.',
        );
      }
    });

    test('rejects unsafe attachment ids', () {
      for (final attachmentId in ['', '..', '../x', 'x/y']) {
        expect(
          () => store.copyAttachmentIntoSession(
            sessionId: 'session-1_2.3',
            source: File('source.txt'),
            attachmentId: attachmentId,
          ),
          throwsArgumentError,
          reason: 'Expected "$attachmentId" to be rejected.',
        );
      }
    });

    test('accepts path-safe ids', () async {
      final root = await Directory.systemTemp.createTemp('session_file_store_');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final source = File('${root.path}${Platform.pathSeparator}source.txt');
      await source.writeAsString('hello');
      final store = SessionFileStore(
        documentsDirectoryProvider: () async => root,
      );

      final directory = await store.attachmentsDirectory('session-1_2.3');
      final copy = await store.copyAttachmentIntoSession(
        sessionId: 'session-1_2.3',
        source: source,
        attachmentId: 'attachment-1_2.3',
      );

      expect(directory.existsSync(), isTrue);
      expect(copy.readAsStringSync(), 'hello');
      expect(copy.path, contains('session-1_2.3'));
      expect(copy.path, contains('attachment-1_2.3'));
    });
  });
}
