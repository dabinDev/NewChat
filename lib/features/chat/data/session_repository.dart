import 'package:newchat/features/chat/domain/chat_models.dart';

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

  ChatSessionMeta _toMeta(ChatSessionDocument document) {
    final preview = document.messages.reversed
        .expand((message) => message.parts)
        .where((part) => part.type == MessagePartType.text)
        .map((part) => part.text ?? '')
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    final meta = ChatSessionMeta(
      id: document.id,
      title: document.title,
      lastMessagePreview: preview,
      providerId: document.providerId,
      modelId: document.modelId,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
      isDeleted: false,
      schemaVersion: document.schemaVersion,
    );
    return meta;
  }
}
