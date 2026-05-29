import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/core/network/sse_parser.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

typedef AttachmentBytesLoader = Future<List<int>> Function(
  AttachmentRef attachment,
);

Map<String, Object?> buildOpenAiPayload({
  required ProviderConfig provider,
  required ModelConfig model,
  required String systemPrompt,
  required List<ChatMessage> messages,
  required bool stream,
}) {
  _throwIfImagePartsRequireAsyncBuilder(messages);
  return _buildOpenAiPayload(
    model: model,
    systemPrompt: systemPrompt,
    messages: messages,
    stream: stream,
    buildContent: _openAiContent,
  );
}

Future<Map<String, Object?>> buildOpenAiPayloadWithImages({
  required ProviderConfig provider,
  required ModelConfig model,
  required String systemPrompt,
  required List<ChatMessage> messages,
  required bool stream,
  required AttachmentBytesLoader loadAttachmentBytes,
}) async {
  final openAiMessages = <Map<String, Object?>>[];
  final trimmedSystemPrompt = systemPrompt.trim();

  if (trimmedSystemPrompt.isNotEmpty) {
    openAiMessages.add({
      'role': 'system',
      'content': trimmedSystemPrompt,
    });
  }

  for (final message in _openAiHistoryMessages(messages)) {
    final content = await _openAiContentWithImagesOrNull(
      message.parts,
      loadAttachmentBytes: loadAttachmentBytes,
    );
    if (content == null) {
      continue;
    }
    openAiMessages.add({
      'role': _openAiRole(message.role),
      'content': content,
    });
  }

  return {
    'model': model.id,
    'messages': openAiMessages,
    'stream': stream,
  };
}

Map<String, Object?> _buildOpenAiPayload({
  required ModelConfig model,
  required String systemPrompt,
  required List<ChatMessage> messages,
  required bool stream,
  required Object? Function(List<MessagePart> parts) buildContent,
}) {
  final openAiMessages = <Map<String, Object?>>[];
  final trimmedSystemPrompt = systemPrompt.trim();

  if (trimmedSystemPrompt.isNotEmpty) {
    openAiMessages.add({
      'role': 'system',
      'content': trimmedSystemPrompt,
    });
  }

  for (final message in _openAiHistoryMessages(messages)) {
    final content = buildContent(message.parts);
    if (content == null) {
      continue;
    }
    openAiMessages.add({
      'role': _openAiRole(message.role),
      'content': content,
    });
  }

  return {
    'model': model.id,
    'messages': openAiMessages,
    'stream': stream,
  };
}

List<String> parseOpenAiSse(String chunk) {
  final events = parseSseChunk(chunk);
  return _parseOpenAiSseEvents(events);
}

class OpenAIProvider implements ChatProvider {
  OpenAIProvider({
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
        _chatCompletionsUri(request.provider),
        data: await buildOpenAiPayloadWithImages(
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
            'Authorization': 'Bearer ${apiKey.trim()}',
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
      await for (final chunk in utf8.decoder.bind(body.stream)) {
        for (final event in parser.addChunk(chunk)) {
          if (event.data.trim() == '[DONE]') {
            yield const ChatStreamDone();
            continue;
          }
          for (final text in _parseOpenAiSseEvents([event])) {
            yield ChatStreamDelta(text);
          }
        }
      }

      for (final event in parser.close()) {
        if (event.data.trim() == '[DONE]') {
          yield const ChatStreamDone();
          continue;
        }
        for (final text in _parseOpenAiSseEvents([event])) {
          yield ChatStreamDelta(text);
        }
      }
    } on DioException catch (error) {
      yield ChatStreamFailed(_chatErrorFromDio(error));
    } on FormatException catch (error) {
      yield ChatStreamFailed(
        ChatError(
          type: ChatErrorType.parsing,
          message: 'Failed to parse OpenAI response.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      yield ChatStreamFailed(
        ChatError(
          type: ChatErrorType.unknown,
          message: 'OpenAI request failed.',
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
          message: 'OpenAI connection test failed.',
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

    final choices = data['choices'];
    if (choices is! List) {
      yield const ChatStreamFailed(
        ChatError(
          type: ChatErrorType.parsing,
          message: 'Expected choices array in response.',
        ),
      );
      return;
    }

    for (final choice in choices) {
      if (choice is! Map) {
        continue;
      }
      final message = choice['message'];
      if (message is! Map) {
        continue;
      }
      final content = message['content'];
      if (content is String && content.isNotEmpty) {
        yield ChatStreamDelta(content);
      }
    }
    yield const ChatStreamDone();
  }
}

String _openAiRole(ChatRole role) {
  return switch (role) {
    ChatRole.user => 'user',
    ChatRole.assistant => 'assistant',
    ChatRole.system => 'system',
  };
}

Object? _openAiContent(List<MessagePart> parts) {
  final hasImages = parts.any((part) => part.type == MessagePartType.image);
  if (!hasImages) {
    if (!parts.any((part) => part.type == MessagePartType.text)) {
      return null;
    }
    return parts
        .where((part) => part.type == MessagePartType.text)
        .map((part) => part.text ?? '')
        .join();
  }

  throw StateError(
    'OpenAI image payloads require buildOpenAiPayloadWithImages so '
    'attachment bytes can be encoded as data URLs.',
  );
}

Future<Object?> _openAiContentWithImages(
  List<MessagePart> parts, {
  required AttachmentBytesLoader loadAttachmentBytes,
}) async {
  final hasImages = parts.any((part) => part.type == MessagePartType.image);
  if (!hasImages) {
    return _openAiContent(parts);
  }

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
          'type': 'image_url',
          'image_url': {
            'url': _dataUrlForAttachment(attachment, bytes),
          },
        });
      case MessagePartType.reasoning:
      case MessagePartType.info:
      case MessagePartType.error:
        break;
    }
  }

  return content;
}

Future<Object?> _openAiContentWithImagesOrNull(
  List<MessagePart> parts, {
  required AttachmentBytesLoader loadAttachmentBytes,
}) async {
  final hasSupportedParts = parts.any(
    (part) =>
        part.type == MessagePartType.text || part.type == MessagePartType.image,
  );
  if (!hasSupportedParts) {
    return null;
  }

  return _openAiContentWithImages(
    parts,
    loadAttachmentBytes: loadAttachmentBytes,
  );
}

String _dataUrlForAttachment(AttachmentRef attachment, List<int> bytes) {
  return 'data:${attachment.mimeType};base64,${base64Encode(bytes)}';
}

void _throwIfImagePartsRequireAsyncBuilder(List<ChatMessage> messages) {
  final hasImages = _openAiHistoryMessages(messages).any(
    (message) => message.parts.any(
      (part) => part.type == MessagePartType.image,
    ),
  );
  if (!hasImages) {
    return;
  }

  throw StateError(
    'OpenAI image payloads require buildOpenAiPayloadWithImages so '
    'attachment bytes can be encoded as data URLs.',
  );
}

Iterable<ChatMessage> _openAiHistoryMessages(List<ChatMessage> messages) =>
    messages.where(
      (message) =>
          message.state == MessageState.completed &&
          (message.role == ChatRole.user || message.role == ChatRole.assistant),
    );

List<String> _parseOpenAiSseEvents(List<SseEvent> events) {
  final deltas = <String>[];

  for (final event in events) {
    final data = event.data.trim();
    if (data == '[DONE]') {
      continue;
    }

    final decoded = jsonDecode(data);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected OpenAI SSE JSON object.');
    }

    final choices = decoded['choices'];
    if (choices is! List) {
      continue;
    }

    for (final choice in choices) {
      if (choice is! Map) {
        continue;
      }
      final delta = choice['delta'];
      if (delta is! Map) {
        continue;
      }
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        deltas.add(content);
      }
    }
  }

  return deltas;
}

Uri _chatCompletionsUri(ProviderConfig provider) {
  return _endpointUri(provider.baseUrl, '/v1/chat/completions');
}

Uri _endpointUri(String rawBaseUrl, String endpointPath) {
  final baseUri = Uri.parse(rawBaseUrl.trim());
  final baseSegments =
      baseUri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  final endpointSegments =
      endpointPath.split('/').where((segment) => segment.isNotEmpty).toList();
  if (baseSegments.isNotEmpty &&
      endpointSegments.isNotEmpty &&
      baseSegments.last == endpointSegments.first) {
    baseSegments.removeLast();
  }
  return baseUri.replace(
    pathSegments: [...baseSegments, ...endpointSegments],
    query: null,
    fragment: null,
  );
}

ChatError _chatErrorFromDio(DioException error) {
  final statusCode = error.response?.statusCode;
  return ChatError(
    type: _chatErrorTypeFromDio(error),
    message: error.message ?? 'OpenAI request failed.',
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
