import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SessionFileStore {
  Future<Directory> attachmentsDirectory(String sessionId) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documentsDirectory.path, 'attachments', sessionId),
    );
    return directory.create(recursive: true);
  }

  Future<File> copyAttachmentIntoSession({
    required String sessionId,
    required File source,
    required String attachmentId,
  }) async {
    final directory = await attachmentsDirectory(sessionId);
    final target = File(p.join(directory.path, attachmentId));
    return source.copy(target.path);
  }

  Future<void> deleteSessionAttachments(String sessionId) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documentsDirectory.path, 'attachments', sessionId),
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
