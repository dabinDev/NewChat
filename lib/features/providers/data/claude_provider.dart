import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/core/network/sse_parser.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/providers/data/openai_provider.dart'
    show AttachmentBytesLoader;
import 'package:newchat/features/providers/domain/provider_models.dart';

Map<String, Object?> buildClaudePayload({
  required ProviderConfig provider,
  required ModelConfig model,
  required String systemPrompt,
  required List<ChatMessage> messages,
  required bool stream,
}) {
  _throwIfImagePartsRequireAsyncBuilder(messages);
  return _buildClaudePayload(
    model: model,
    systemPrompt: systemPrompt,
    messages: messages,
    stream: stream,
    buildContent: _claudeContent,
  );
}

Future<Map<String, Object?>> buildClaudePayloadWithImages({
  required ProviderConfig provider,
  required ModelConfig model,
  required String systemPrompt,
  required List<ChatMessage> messages,
  required bool stream,
  required AttachmentBytesLoader loadAttachmentBytes,
}) async {
  final claudeMessages = <Map<String, Object?>>[];

  for (final message in _claudeHistoryMessages(messages)) {
    final content = await _claudeContentWithImagesOrNull(
      message.parts,
      loadAttachmentBytes: loadAttachmentBytes,
    );
    if (content == null) {
      continue;
    }
    claudeMessages.add({
      'role': _claudeRole(message.role),
      'content': content,
    });
  }

  return _payload(
    model: model,
    systemPrompt: systemPrompt,
    messages: claudeMessages,
    stream: stream,
  );
}

List<String> parseClaudeSse(String chunk) {
  final events = parseSseChunk(chunk);
  return _parseClaudeSseEvents(events);
}

class ClaudeProvider implements ChatProvider {
  ClaudeProvider({
    required Dio dio,
    required Future<String?> Function(String providerId) readApiKey,
    AttachmentBytesLoader? loadAttachmentBytes,
  })  : _dio = dio,
        _readApiKey = readApiKey,
        _loadAttachmentBytes = loadAttachmentBytes ??
            ((attachment) => File(attachment.localPath).readAsBytes());

  final Dio _dio;
  final Future<String?> Function(String providerId) _readApiKey;
  final AttachmentBytesLoader _loadAttachmentBytes;

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) async* {
    try {
      final apiKey = await _readApiKey(request.provider.id);
      if (apiKey == null || apiKey.trim().isEmpty) {
        yield const ChatStreamFailed(
          ChatError(
            type: ChatErrorType.authentication,
            message: 'API key is missing.',
          ),
        );
        return;
      }

      final response = await _dio.postUri<Object?>(
        _messagesUri(request.provider),
        data: await buildClaudePayloadWithImages(
          provider: request.provider,
          model: request.model,
          systemPrompt: request.systemPrompt,
          messages: request.messages,
          stream: request.stream,
          loadAttachmentBytes: _loadAttachmentBytes,
        ),
        options: Options(
          responseType:
              request.stream ? ResponseType.stream : ResponseType.json,
          headers: {
            'x-api-key': apiKey.trim(),
            'anthropic-version': '2023-06-01',
            if (request.stream) 'Accept': 'text/event-stream',
          },
        ),
      );

      if (!request.stream) {
        yield* _emitNonStreamingResponse(response.data);
        return;
      }

      final body = response.data;
      if (body is! ResponseBody) {
        yield const ChatStreamFailed(
          ChatError(
            type: ChatErrorType.parsing,
            message: 'Expected streaming response body.',
          ),
        );
        return;
      }

      final parser = SseParser();
      var sawStop = false;
      await for (final chunk in utf8.decoder.bind(body.stream)) {
        for (final event in parser.addChunk(chunk)) {
          for (final text in _parseClaudeSseEvents([event])) {
            yield ChatStreamDelta(text);
          }
          if (_isClaudeStopEvent(event)) {
            sawStop = true;
            yield const ChatStreamDone();
          }
        }
      }

      for (final event in parser.close()) {
        for (final text in _parseClaudeSseEvents([event])) {
          yield ChatStreamDelta(text);
        }
        if (_isClaudeStopEvent(event)) {
          sawStop = true;
          yield const ChatStreamDone();
        }
      }

      if (!sawStop) {
        yield const ChatStreamDone();
      }
    } on DioException catch (error) {
      yield ChatStreamFailed(_chatErrorFromDio(error));
    } on FormatException catch (error) {
      yield ChatStreamFailed(
        ChatError(
          type: ChatErrorType.parsing,
          message: 'Failed to parse Claude response.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      yield ChatStreamFailed(
        ChatError(
          type: ChatErrorType.unknown,
          message: 'Claude request failed.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    try {
      final events = sendStream(
        ChatRequest(
          provider: request.provider,
          model: request.model,
          systemPrompt: '',
          messages: [
            ChatMessage(
              id: 'connection-test',
              role: ChatRole.user,
              state: MessageState.completed,
              parts: const [MessagePart.text('ping')],
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            ),
          ],
          stream: false,
        ),
      );

      await for (final event in events) {
        if (event is ChatStreamFailed) {
          return ConnectionTestResult.failure(event.error);
        }
      }
      return const ConnectionTestResult.success();
    } on Object catch (error) {
      return ConnectionTestResult.failure(
        ChatError(
          type: ChatErrorType.unknown,
          message: 'Claude connection test failed.',
          cause: error,
        ),
      );
    }
  }

  Stream<ChatStreamEvent> _emitNonStreamingResponse(Object? data) async* {
    if (data is! Map<String, Object?>) {
      yield const ChatStreamFailed(
        ChatError(
          type: ChatErrorType.parsing,
          message: 'Expected JSON object response.',
        ),
      );
      return;
    }

    final content = data['content'];
    if (content is! List) {
      yield const ChatStreamFailed(
        ChatError(
          type: ChatErrorType.parsing,
          message: 'Expected content array in response.',
        ),
      );
      return;
    }

    for (final block in content) {
      if (block is! Map) {
        continue;
      }
      if (block['type'] != 'text') {
        continue;
      }
      final text = block['text'];
      if (text is String && text.isNotEmpty) {
        yield ChatStreamDelta(text);
      }
    }
    yield const ChatStreamDone();
  }
}

Map<String, Object?> _buildClaudePayload({
  required ModelConfig model,
  required String systemPrompt,
  required List<ChatMessage> messages,
  required bool stream,
  required Object? Function(List<MessagePart> parts) buildContent,
}) {
  final claudeMessages = <Map<String, Object?>>[];

  for (final message in _claudeHistoryMessages(messages)) {
    final content = buildContent(message.parts);
    if (content == null) {
      continue;
    }
    claudeMessages.add({
      'role': _claudeRole(message.role),
      'content': content,
    });
  }

  return _payload(
    model: model,
    systemPrompt: systemPrompt,
    messages: claudeMessages,
    stream: stream,
  );
}

Map<String, Object?> _payload({
  required ModelConfig model,
  required String systemPrompt,
  required List<Map<String, Object?>> messages,
  required bool stream,
}) {
  final trimmedSystemPrompt = systemPrompt.trim();
  return {
    'model': model.id,
    if (trimmedSystemPrompt.isNotEmpty) 'system': trimmedSystemPrompt,
    'messages': messages,
    'stream': stream,
  };
}

String _claudeRole(ChatRole role) {
  return switch (role) {
    ChatRole.user => 'user',
    ChatRole.assistant => 'assistant',
    ChatRole.system => 'user',
  };
}

Object? _claudeContent(List<MessagePart> parts) {
  final hasImages = parts.any((part) => part.type == MessagePartType.image);
  if (hasImages) {
    throw StateError(
      'Claude image payloads require buildClaudePayloadWithImages so '
      'attachment bytes can be encoded as base64 sources.',
    );
  }

  final content = <Map<String, Object?>>[];
  for (final part in parts) {
    if (part.type != MessagePartType.text) {
      continue;
    }
    content.add({
      'type': 'text',
      'text': part.text ?? '',
    });
  }

  if (content.isEmpty) {
    return null;
  }
  return content;
}

Future<Object?> _claudeContentWithImages(
  List<MessagePart> parts, {
  required AttachmentBytesLoader loadAttachmentBytes,
}) async {
  final content = <Map<String, Object?>>[];

  for (final part in parts) {
    switch (part.type) {
      case MessagePartType.text:
        content.add({
          'type': 'text',
          'text': part.text ?? '',
        });
      case MessagePartType.image:
        final attachment = part.attachment!;
        final bytes = await loadAttachmentBytes(attachment);
        content.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': attachment.mimeType,
            'data': base64Encode(bytes),
          },
        });
      case MessagePartType.reasoning:
      case MessagePartType.info:
      case MessagePartType.error:
        break;
    }
  }

  if (content.isEmpty) {
    return null;
  }
  return content;
}

Future<Object?> _claudeContentWithImagesOrNull(
  List<MessagePart> parts, {
  required AttachmentBytesLoader loadAttachmentBytes,
}) {
  final hasSupportedParts = parts.any(
    (part) =>
        part.type == MessagePartType.text || part.type == MessagePartType.image,
  );
  if (!hasSupportedParts) {
    return Future.value();
  }

  return _claudeContentWithImages(
    parts,
    loadAttachmentBytes: loadAttachmentBytes,
  );
}

void _throwIfImagePartsRequireAsyncBuilder(List<ChatMessage> messages) {
  final hasImages = _claudeHistoryMessages(messages).any(
    (message) => message.parts.any(
      (part) => part.type == MessagePartType.image,
    ),
  );
  if (!hasImages) {
    return;
  }

  throw StateError(
    'Claude image payloads require buildClaudePayloadWithImages so '
    'attachment bytes can be encoded as base64 sources.',
  );
}

Iterable<ChatMessage> _claudeHistoryMessages(List<ChatMessage> messages) =>
    messages.where(
      (message) =>
          message.state == MessageState.completed &&
          (message.role == ChatRole.user || message.role == ChatRole.assistant),
    );

List<String> _parseClaudeSseEvents(List<SseEvent> events) {
  final deltas = <String>[];

  for (final event in events) {
    if (event.event != 'content_block_delta') {
      continue;
    }

    final decoded = jsonDecode(event.data.trim());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected Claude SSE JSON object.');
    }

    final delta = decoded['delta'];
    if (delta is! Map) {
      continue;
    }
    if (delta['type'] != 'text_delta') {
      continue;
    }

    final text = delta['text'];
    if (text is String && text.isNotEmpty) {
      deltas.add(text);
    }
  }

  return deltas;
}

bool _isClaudeStopEvent(SseEvent event) {
  if (event.event == 'message_stop') {
    return true;
  }

  try {
    final decoded = jsonDecode(event.data.trim());
    return decoded is Map && decoded['type'] == 'message_stop';
  } on FormatException {
    return false;
  }
}

Uri _messagesUri(ProviderConfig provider) {
  final baseUrl = provider.baseUrl.endsWith('/')
      ? provider.baseUrl.substring(0, provider.baseUrl.length - 1)
      : provider.baseUrl;
  return Uri.parse('$baseUrl/v1/messages');
}

ChatError _chatErrorFromDio(DioException error) {
  final statusCode = error.response?.statusCode;
  return ChatError(
    type: _chatErrorTypeFromDio(error),
    message: error.message ?? 'Claude request failed.',
    statusCode: statusCode,
    cause: error,
  );
}

ChatErrorType _chatErrorTypeFromDio(DioException error) {
  final statusCode = error.response?.statusCode;
  if (statusCode == 401) {
    return ChatErrorType.authentication;
  }
  if (statusCode == 403) {
    return ChatErrorType.permission;
  }
  if (statusCode == 404) {
    return ChatErrorType.notFound;
  }
  if (statusCode != null && statusCode >= 400 && statusCode < 500) {
    return ChatErrorType.badRequest;
  }
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      ChatErrorType.timeout,
    DioExceptionType.cancel => ChatErrorType.cancelled,
    DioExceptionType.connectionError => ChatErrorType.network,
    DioExceptionType.badResponse ||
    DioExceptionType.badCertificate ||
    DioExceptionType.unknown =>
      ChatErrorType.unknown,
  };
}
