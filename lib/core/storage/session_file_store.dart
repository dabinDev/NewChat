import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

class SessionFileStore {
  SessionFileStore({
    DocumentsDirectoryProvider? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final DocumentsDirectoryProvider _documentsDirectoryProvider;

  Future<Directory> attachmentsDirectory(String sessionId) async {
    final safeSessionId = _validatePathSegment(sessionId, 'sessionId');
    final attachmentsRoot = await _attachmentsRoot();
    final directory = Directory(p.join(attachmentsRoot.path, safeSessionId));
    _ensureUnderAttachmentsRoot(
      root: attachmentsRoot,
      targetPath: directory.path,
      operation: 'create attachments directory',
    );
    return directory.create(recursive: true);
  }

  Future<File> copyAttachmentIntoSession({
    required String sessionId,
    required File source,
    required String attachmentId,
  }) async {
    final safeAttachmentId = _validatePathSegment(attachmentId, 'attachmentId');
    final directory = await attachmentsDirectory(sessionId);
    final attachmentsRoot = await _attachmentsRoot();
    final target = File(p.join(directory.path, safeAttachmentId));
    _ensureUnderAttachmentsRoot(
      root: attachmentsRoot,
      targetPath: target.path,
      operation: 'copy attachment',
    );
    return source.copy(target.path);
  }

  Future<void> deleteSessionAttachments(String sessionId) async {
    final safeSessionId = _validatePathSegment(sessionId, 'sessionId');
    final attachmentsRoot = await _attachmentsRoot();
    final directory = Directory(p.join(attachmentsRoot.path, safeSessionId));
    _ensureUnderAttachmentsRoot(
      root: attachmentsRoot,
      targetPath: directory.path,
      operation: 'delete session attachments',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _attachmentsRoot() async {
    final documentsDirectory = await _documentsDirectoryProvider();
    return Directory(p.join(documentsDirectory.path, 'attachments'));
  }

  String _validatePathSegment(String value, String name) {
    final isPathSafe = RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value);
    if (!isPathSafe || value == '.' || value == '..') {
      throw ArgumentError.value(value, name, 'Invalid path segment.');
    }
    return value;
  }

  void _ensureUnderAttachmentsRoot({
    required Directory root,
    required String targetPath,
    required String operation,
  }) {
    final normalizedRoot = _normalizeAbsolute(root.path);
    final normalizedTarget = _normalizeAbsolute(targetPath);
    if (normalizedTarget != normalizedRoot &&
        !p.isWithin(normalizedRoot, normalizedTarget)) {
      throw StateError(
        'Cannot $operation outside attachments root: $normalizedTarget',
      );
    }
  }

  String _normalizeAbsolute(String path) => p.normalize(p.absolute(path));
}
