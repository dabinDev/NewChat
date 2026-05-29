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
      ),
    );
    await load();
  }

  Future<void> deleteSession(String sessionId) async {
    await _repository.deleteSession(sessionId);
    await load();
  }
}
