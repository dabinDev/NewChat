import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';

final sessionListControllerProvider =
    FutureProvider<List<ChatSessionMeta>>((ref) async {
  final controller = SessionListController(
    repository: ref.watch(sessionRepositoryProvider),
  );
  await controller.load();
  return controller.sessions;
});

class SessionListController {
  SessionListController({
    required SessionRepository repository,
  }) : _repository = repository;

  final SessionRepository _repository;

  List<ChatSessionMeta> _sessions = const [];

  List<ChatSessionMeta> get sessions => _sessions;

  Future<void> load() async {
    _sessions = await _repository.listMetas();
  }

  Future<void> renameSession(String sessionId, String title) async {
    final document = await _repository.loadDocument(sessionId);
    if (document == null) {
      throw StateError('Chat session not found: $sessionId');
    }

    await _repository.saveDocument(
      ChatSessionDocument(
        id: document.id,
        title: title,
        providerId: document.providerId,
        modelId: document.modelId,
        systemPrompt: document.systemPrompt,
        messages: document.messages,
        createdAt: document.createdAt,
        updatedAt: DateTime.now().toUtc(),
        schemaVersion: document.schemaVersion,
        contextSummary: document.contextSummary,
        contextSummaryUpdatedAt: document.contextSummaryUpdatedAt,
        isPinned: document.isPinned,
        pinnedAt: document.pinnedAt,
        isUnread: document.isUnread,
      ),
    );
    await load();
  }

  Future<void> deleteSession(String sessionId) async {
    await _repository.deleteSession(sessionId);
    await load();
  }

  Future<void> pinSession(String sessionId) async {
    await _updateSession(
      sessionId,
      isPinned: true,
      pinnedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> unpinSession(String sessionId) async {
    await _updateSession(sessionId, isPinned: false, pinnedAt: null);
  }

  Future<void> markUnread(String sessionId) async {
    await _updateSession(sessionId, isUnread: true);
  }

  Future<void> markRead(String sessionId) async {
    await _updateSession(sessionId, isUnread: false);
  }

  Future<void> softDeleteSession(String sessionId) async {
    await _repository.softDeleteSession(sessionId);
    await load();
  }

  Future<void> _updateSession(
    String sessionId, {
    bool? isPinned,
    Object? pinnedAt = _unset,
    bool? isUnread,
  }) async {
    final document = await _repository.loadDocument(sessionId);
    if (document == null) {
      throw StateError('Chat session not found: $sessionId');
    }

    await _repository.saveDocument(
      ChatSessionDocument(
        id: document.id,
        title: document.title,
        providerId: document.providerId,
        modelId: document.modelId,
        systemPrompt: document.systemPrompt,
        messages: document.messages,
        createdAt: document.createdAt,
        updatedAt: document.updatedAt,
        schemaVersion: document.schemaVersion,
        contextSummary: document.contextSummary,
        contextSummaryUpdatedAt: document.contextSummaryUpdatedAt,
        isPinned: isPinned ?? document.isPinned,
        pinnedAt: identical(pinnedAt, _unset)
            ? document.pinnedAt
            : pinnedAt as DateTime?,
        isUnread: isUnread ?? document.isUnread,
      ),
    );
    await load();
  }
}

const Object _unset = Object();
