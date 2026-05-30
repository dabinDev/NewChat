import 'dart:typed_data';

import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

abstract class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamDelta extends ChatStreamEvent {
  const ChatStreamDelta(this.text);
  final String text;
}

class ChatStreamDone extends ChatStreamEvent {
  const ChatStreamDone();
}

class ChatStreamImage extends ChatStreamEvent {
  const ChatStreamImage({
    required this.bytes,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String mimeType;
}

class ChatStreamFailed extends ChatStreamEvent {
  const ChatStreamFailed(this.error);
  final ChatError error;
}

class ChatRequest {
  const ChatRequest({
    required this.provider,
    required this.model,
    required this.systemPrompt,
    required this.messages,
    required this.stream,
  });

  final ProviderConfig provider;
  final ModelConfig model;
  final String systemPrompt;
  final List<ChatMessage> messages;
  final bool stream;
}

class ConnectionTestRequest {
  const ConnectionTestRequest({
    required this.provider,
    required this.model,
  });

  final ProviderConfig provider;
  final ModelConfig model;
}

class ConnectionTestResult {
  const ConnectionTestResult.success() : error = null;
  const ConnectionTestResult.failure(this.error);

  final ChatError? error;
  bool get isSuccess => error == null;
}

abstract interface class ChatProvider {
  Stream<ChatStreamEvent> sendStream(ChatRequest request);
  Future<ConnectionTestResult> testConnection(ConnectionTestRequest request);
}
