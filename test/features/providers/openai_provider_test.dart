import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/providers/data/openai_provider.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

void main() {
  test('builds OpenAI request with system prompt and text message', () {
    final provider = _provider();
    const model = _model;

    final payload = buildOpenAiPayload(
      provider: provider,
      model: model,
      systemPrompt: 'Be concise.',
      messages: [
        _message(
          role: ChatRole.user,
          parts: const [MessagePart.text('hello')],
        ),
      ],
      stream: true,
    );

    expect(payload['model'], 'gpt-4o-mini');
    expect(payload['stream'], isTrue);
    expect((payload['messages']! as List).first['role'], 'system');
  });

  test('does not include system message when system prompt is blank', () {
    final payload = buildOpenAiPayload(
      provider: _provider(),
      model: _model,
      systemPrompt: '  ',
      messages: [
        _message(
          role: ChatRole.user,
          parts: const [MessagePart.text('hello')],
        ),
      ],
      stream: false,
    );

    final messages = payload['messages']! as List<Object?>;

    expect(messages, hasLength(1));
    expect((messages.single! as Map<String, Object?>)['role'], 'user');
  });

  test('builds OpenAI content array for messages with images', () {
    final payload = buildOpenAiPayload(
      provider: _provider(),
      model: _model,
      systemPrompt: '',
      messages: [
        _message(
          role: ChatRole.user,
          parts: [
            const MessagePart.text('what is this?'),
            MessagePart.image(
              const AttachmentRef(
                id: 'a1',
                localPath: 'C:\\images\\cat.png',
                mimeType: 'image/png',
              ),
            ),
          ],
        ),
      ],
      stream: true,
    );

    final messages = payload['messages']! as List<Object?>;
    final message = messages.single! as Map<String, Object?>;
    final content = message['content']! as List<Object?>;

    expect(content.first, {'type': 'text', 'text': 'what is this?'});
    expect(content.last, {
      'type': 'image_url',
      'image_url': {'url': 'C:\\images\\cat.png'},
    });
  });

  test('parses OpenAI text delta', () {
    final events = parseOpenAiSse(
      'data: {"choices":[{"delta":{"content":"hi"}}]}\n\n',
    );

    expect(events.single, 'hi');
  });

  test('parseOpenAiSse ignores done events', () {
    final events = parseOpenAiSse('data: [DONE]\n\n');

    expect(events, isEmpty);
  });

  test('parseOpenAiSse returns multiple deltas in one chunk', () {
    final events = parseOpenAiSse(
      'data: {"choices":[{"delta":{"content":"he"}}]}\n\n'
      'data: {"choices":[{"delta":{"content":"llo"}}]}\n\n',
    );

    expect(events, ['he', 'llo']);
  });

  test('parseOpenAiSse throws FormatException for malformed JSON', () {
    expect(
      () => parseOpenAiSse('data: {"choices":\n\n'),
      throwsFormatException,
    );
  });

  test('OpenAIProvider posts streaming request and emits deltas then done',
      () async {
    final adapter = _FakeHttpClientAdapter(
      streamChunks: [
        Uint8List.fromList(
          utf8.encode('data: {"choices":[{"delta":{"content":"he"}}]}\n\n'),
        ),
        Uint8List.fromList(
          utf8.encode('data: {"choices":[{"delta":{"content":"llo"}}]}\n\n'),
        ),
        Uint8List.fromList(utf8.encode('data: [DONE]\n\n')),
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = OpenAIProvider(
      dio: dio,
      readApiKey: (_) async => 'secret-key',
    );

    final events = await provider
        .sendStream(
          ChatRequest(
            provider: _provider(),
            model: _model,
            systemPrompt: 'Be concise.',
            messages: [
              _message(
                role: ChatRole.user,
                parts: const [MessagePart.text('hello')],
              ),
            ],
            stream: true,
          ),
        )
        .toList();

    final eventLabels = <String>[];
    for (final event in events) {
      switch (event) {
        case ChatStreamDelta(:final text):
          eventLabels.add(text);
        case ChatStreamDone():
          eventLabels.add('[DONE]');
        case ChatStreamFailed(:final error):
          eventLabels.add(error.message);
      }
    }

    expect(eventLabels, ['he', 'llo', '[DONE]']);
    expect(adapter.lastOptions?.method, 'POST');
    expect(
      adapter.lastOptions?.path,
      'https://token.cylonai.cn/v1/chat/completions',
    );
    expect(adapter.lastOptions?.headers['Authorization'], 'Bearer secret-key');
    expect(adapter.lastOptions?.headers['Accept'], 'text/event-stream');
  });

  test('OpenAIProvider converts Dio errors to ChatStreamFailed', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeHttpClientAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          response: Response<void>(
            requestOptions: RequestOptions(path: '/v1/chat/completions'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
          message: 'Unauthorized',
        ),
      );
    final provider = OpenAIProvider(
      dio: dio,
      readApiKey: (_) async => 'bad-key',
    );

    final events = await provider
        .sendStream(
          ChatRequest(
            provider: _provider(),
            model: _model,
            systemPrompt: '',
            messages: [
              _message(
                role: ChatRole.user,
                parts: const [MessagePart.text('hello')],
              ),
            ],
            stream: true,
          ),
        )
        .toList();

    expect(events, hasLength(1));
    expect(events.single, isA<ChatStreamFailed>());
  });
}

ProviderConfig _provider() => ProviderConfig(
      id: 'p1',
      name: 'Gateway',
      protocol: ProviderProtocol.openai,
      baseUrl: 'https://token.cylonai.cn',
      defaultModelId: 'gpt-4o-mini',
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );

const _model = ModelConfig(
  id: 'gpt-4o-mini',
  displayName: 'GPT-4o mini',
  protocol: ProviderProtocol.openai,
  supportsStreaming: true,
  supportsImages: true,
);

ChatMessage _message({
  required ChatRole role,
  required List<MessagePart> parts,
}) =>
    ChatMessage(
      id: 'm1',
      role: role,
      state: MessageState.completed,
      parts: parts,
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({
    this.streamChunks = const [],
    this.error,
  });

  final List<Uint8List> streamChunks;
  final DioException? error;
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (error != null) {
      throw error!;
    }

    return ResponseBody(
      Stream.fromIterable(streamChunks),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }
}
