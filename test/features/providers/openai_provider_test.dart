import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/errors/chat_error.dart';
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

  test('buildOpenAiPayload includes only completed user and assistant history',
      () {
    final payload = buildOpenAiPayload(
      provider: _provider(),
      model: _model,
      systemPrompt: 'Be concise.',
      messages: [
        _message(
          role: ChatRole.system,
          parts: const [MessagePart.text('do not replay')],
        ),
        _message(
          role: ChatRole.user,
          state: MessageState.streaming,
          parts: const [MessagePart.text('streaming user')],
        ),
        _message(
          role: ChatRole.assistant,
          state: MessageState.failed,
          parts: const [MessagePart.text('failed assistant')],
        ),
        _message(
          role: ChatRole.user,
          state: MessageState.cancelled,
          parts: const [MessagePart.text('cancelled user')],
        ),
        _message(
          role: ChatRole.assistant,
          state: MessageState.interrupted,
          parts: const [MessagePart.text('interrupted assistant')],
        ),
        _message(
          role: ChatRole.user,
          parts: [
            MessagePart(type: MessagePartType.info, text: 'unsupported'),
          ],
        ),
        _message(
          role: ChatRole.user,
          parts: const [MessagePart.text('completed user')],
        ),
        _message(
          role: ChatRole.assistant,
          parts: const [MessagePart.text('completed assistant')],
        ),
      ],
      stream: true,
    );

    final messages =
        (payload['messages']! as List<Object?>).cast<Map<String, Object?>>();

    expect(
      messages,
      [
        {'role': 'system', 'content': 'Be concise.'},
        {'role': 'user', 'content': 'completed user'},
        {'role': 'assistant', 'content': 'completed assistant'},
      ],
    );
  });

  test('buildOpenAiPayload rejects image parts without byte resolver', () {
    expect(
      () => buildOpenAiPayload(
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
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('buildOpenAiPayloadWithImages encodes image parts as data URLs',
      () async {
    final payload = await buildOpenAiPayloadWithImages(
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
      loadAttachmentBytes: (_) async => utf8.encode('png bytes'),
    );

    final messages = payload['messages']! as List<Object?>;
    final message = messages.single! as Map<String, Object?>;
    final content = message['content']! as List<Object?>;
    final image = content.last! as Map<String, Object?>;
    final imageUrl = image['image_url']! as Map<String, Object?>;
    final url = imageUrl['url']! as String;

    expect(content.first, {'type': 'text', 'text': 'what is this?'});
    expect(image['type'], 'image_url');
    expect(url, 'data:image/png;base64,cG5nIGJ5dGVz');
    expect(url, isNot(contains('C:\\images\\cat.png')));
  });

  test(
      'buildOpenAiPayloadWithImages includes only completed user and '
      'assistant history', () async {
    final payload = await buildOpenAiPayloadWithImages(
      provider: _provider(),
      model: _model,
      systemPrompt: '',
      messages: [
        _message(
          role: ChatRole.user,
          state: MessageState.streaming,
          parts: const [MessagePart.text('streaming user')],
        ),
        _message(
          role: ChatRole.assistant,
          state: MessageState.cancelled,
          parts: const [MessagePart.text('cancelled assistant')],
        ),
        _message(
          role: ChatRole.system,
          parts: const [MessagePart.text('system history')],
        ),
        _message(
          role: ChatRole.assistant,
          parts: [
            MessagePart(type: MessagePartType.reasoning, text: 'unsupported'),
          ],
        ),
        _message(
          role: ChatRole.user,
          parts: [
            const MessagePart.text('look'),
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
      loadAttachmentBytes: (_) async => utf8.encode('png bytes'),
    );

    final messages =
        (payload['messages']! as List<Object?>).cast<Map<String, Object?>>();

    expect(messages, hasLength(1));
    expect(messages.single['role'], 'user');
    expect(messages.single['content'], isA<List<Object?>>());
    expect(jsonEncode(payload), isNot(contains('streaming user')));
    expect(jsonEncode(payload), isNot(contains('cancelled assistant')));
    expect(jsonEncode(payload), isNot(contains('system history')));
    expect(jsonEncode(payload), isNot(contains('unsupported')));
  });

  test('buildOpenAiPayloadWithImages preserves compact context summary',
      () async {
    const summaryText = 'Earlier conversation summary:\n- user: old image';
    final payload = await buildOpenAiPayloadWithImages(
      provider: _provider(),
      model: _model,
      systemPrompt: '',
      messages: [
        _message(
          role: ChatRole.system,
          parts: const [MessagePart.text(summaryText)],
        ),
        _message(
          role: ChatRole.user,
          parts: [
            const MessagePart.text('what about this one?'),
            MessagePart.image(
              const AttachmentRef(
                id: 'current-image',
                localPath: 'C:\\images\\current.png',
                mimeType: 'image/png',
              ),
            ),
          ],
        ),
      ],
      stream: true,
      loadAttachmentBytes: (_) async => utf8.encode('current png bytes'),
    );

    final messages =
        (payload['messages']! as List<Object?>).cast<Map<String, Object?>>();
    final summary = messages.first;
    final current = messages.last;
    final content = current['content']! as List<Object?>;
    final image = content.last! as Map<String, Object?>;
    final imageUrl = image['image_url']! as Map<String, Object?>;

    expect(summary['role'], 'system');
    expect(summary['content'], summaryText);
    expect(imageUrl['url'], 'data:image/png;base64,Y3VycmVudCBwbmcgYnl0ZXM=');
    expect(jsonEncode(payload), isNot(contains('C:\\images\\old.png')));
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
        case ChatStreamImage():
          eventLabels.add('[IMAGE]');
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

  test('OpenAIProvider routes gpt-image models to image generations', () async {
    final adapter = _FakeHttpClientAdapter(
      responseBody: utf8.encode(
        jsonEncode({
          'data': [
            {'b64_json': base64Encode(utf8.encode('png bytes'))},
          ],
        }),
      ),
      responseHeaders: {
        Headers.contentTypeHeader: ['application/json'],
      },
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
            model: const ModelConfig(
              id: 'gpt-image-2',
              displayName: 'GPT Image 2',
              protocol: ProviderProtocol.openai,
              supportsStreaming: false,
              supportsImages: true,
            ),
            systemPrompt: 'ignore for image prompt',
            messages: [
              _message(
                role: ChatRole.user,
                parts: const [MessagePart.text('first prompt')],
              ),
              _message(
                role: ChatRole.assistant,
                parts: const [MessagePart.text('old answer')],
              ),
              _message(
                role: ChatRole.user,
                parts: const [MessagePart.text('draw a red kite')],
              ),
            ],
            stream: true,
          ),
        )
        .toList();

    final data = adapter.lastOptions!.data! as Map<String, Object?>;
    expect(adapter.lastOptions?.method, 'POST');
    expect(
      adapter.lastOptions?.path,
      'https://token.cylonai.cn/v1/images/generations',
    );
    expect(data['model'], 'gpt-image-2');
    expect(data['prompt'], 'draw a red kite');
    expect(data, isNot(containsPair('stream', anything)));
    expect(data, isNot(containsPair('messages', anything)));
    expect(adapter.lastOptions?.headers['Accept'], isNull);
    expect(events.last, isA<ChatStreamDone>());
  });

  test('OpenAIProvider parses b64 image generation response into image event',
      () async {
    final imageBytes = Uint8List.fromList(utf8.encode('png bytes'));
    final adapter = _FakeHttpClientAdapter(
      responseBody: utf8.encode(
        jsonEncode({
          'data': [
            {'b64_json': base64Encode(imageBytes)},
          ],
        }),
      ),
      responseHeaders: {
        Headers.contentTypeHeader: ['application/json'],
      },
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
            model: const ModelConfig(
              id: 'GPT-IMAGE-2',
              displayName: 'GPT Image 2',
              protocol: ProviderProtocol.openai,
              supportsStreaming: false,
              supportsImages: true,
            ),
            systemPrompt: '',
            messages: [
              _message(
                role: ChatRole.user,
                parts: const [MessagePart.text('draw a red kite')],
              ),
            ],
            stream: true,
          ),
        )
        .toList();

    expect(events, hasLength(2));
    final image = events.first as ChatStreamImage;
    expect(image.bytes, imageBytes);
    expect(image.mimeType, 'image/png');
    expect(events.last, isA<ChatStreamDone>());
  });

  test('OpenAIProvider normalizes base URLs that already include v1', () async {
    final adapter = _FakeHttpClientAdapter(
      streamChunks: [Uint8List.fromList(utf8.encode('data: [DONE]\n\n'))],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = OpenAIProvider(
      dio: dio,
      readApiKey: (_) async => 'secret-key',
    );

    await provider
        .sendStream(
          ChatRequest(
            provider: _provider().copyWithBaseUrl('https://api.openai.com/v1'),
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

    expect(
      adapter.lastOptions?.path,
      'https://api.openai.com/v1/chat/completions',
    );
  });

  test('OpenAIProvider buffers SSE frames split across chunks', () async {
    final adapter = _FakeHttpClientAdapter(
      streamChunks: [
        Uint8List.fromList(utf8.encode('data: {"choices":[{"delta"')),
        Uint8List.fromList(utf8.encode(':{"content":"split"}}]}\n')),
        Uint8List.fromList(utf8.encode('\n')),
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

    expect(events, hasLength(2));
    expect((events.first as ChatStreamDelta).text, 'split');
    expect(events.last, isA<ChatStreamDone>());
  });

  test('OpenAIProvider includes safe status and response details in Dio errors',
      () async {
    const rawDioMessage =
        'This exception was thrown because the response has a status code of 503';
    final dio = Dio()
      ..httpClientAdapter = _FakeHttpClientAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          response: Response<Map<String, Object?>>(
            requestOptions: RequestOptions(path: '/v1/chat/completions'),
            statusCode: 503,
            data: const {
              'error': {'message': 'upstream model is unavailable'},
            },
          ),
          type: DioExceptionType.badResponse,
          message: rawDioMessage,
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
    final failed = events.single as ChatStreamFailed;
    expect(failed.error.message, isNot(contains(rawDioMessage)));
    expect(
      failed.error.message,
      'OpenAI request failed. (503) upstream model is unavailable',
    );
    expect(failed.error.statusCode, 503);
  });

  test('OpenAIProvider posts image attachments as data URLs', () async {
    final adapter = _FakeHttpClientAdapter(
      streamChunks: [Uint8List.fromList(utf8.encode('data: [DONE]\n\n'))],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = OpenAIProvider(
      dio: dio,
      readApiKey: (_) async => 'secret-key',
      loadAttachmentBytes: (_) async => utf8.encode('png bytes'),
    );

    await provider
        .sendStream(
          ChatRequest(
            provider: _provider(),
            model: _model,
            systemPrompt: '',
            messages: [
              _message(
                role: ChatRole.user,
                parts: [
                  const MessagePart.text('look'),
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
          ),
        )
        .toList();

    final data = adapter.lastOptions!.data! as Map<String, Object?>;
    final messages = data['messages']! as List<Object?>;
    final message = messages.single! as Map<String, Object?>;
    final content = message['content']! as List<Object?>;
    final image = content.last! as Map<String, Object?>;
    final imageUrl = image['image_url']! as Map<String, Object?>;
    final url = imageUrl['url']! as String;

    expect(url, 'data:image/png;base64,cG5nIGJ5dGVz');
    expect(jsonEncode(data), isNot(contains('C:\\images\\cat.png')));
  });

  test('OpenAIProvider sanitizes generic image loader failures', () async {
    const localPath = 'C:\\Users\\dabin\\Pictures\\secret.png';
    final dio = Dio()..httpClientAdapter = _FakeHttpClientAdapter();
    final provider = OpenAIProvider(
      dio: dio,
      readApiKey: (_) async => 'secret-key',
      loadAttachmentBytes: (_) async => throw const FileSystemException(
        'Cannot open file',
        localPath,
      ),
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
                parts: [
                  MessagePart.image(
                    const AttachmentRef(
                      id: 'a1',
                      localPath: localPath,
                      mimeType: 'image/png',
                    ),
                  ),
                ],
              ),
            ],
            stream: true,
          ),
        )
        .toList();

    final failure = events.single as ChatStreamFailed;

    expect(failure.error.type, ChatErrorType.unknown);
    expect(failure.error.message, isNot(contains(localPath)));
    expect(failure.error.cause, isA<FileSystemException>());
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

extension on ProviderConfig {
  ProviderConfig copyWithBaseUrl(String baseUrl) => ProviderConfig(
        id: id,
        name: name,
        protocol: protocol,
        baseUrl: baseUrl,
        defaultModelId: defaultModelId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

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
  MessageState state = MessageState.completed,
}) =>
    ChatMessage(
      id: 'm1',
      role: role,
      state: state,
      parts: parts,
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({
    this.streamChunks = const [],
    this.responseBody,
    this.responseHeaders = const {
      Headers.contentTypeHeader: ['text/event-stream'],
    },
    this.error,
  });

  final List<Uint8List> streamChunks;
  final List<int>? responseBody;
  final Map<String, List<String>> responseHeaders;
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
      Stream.fromIterable(
        responseBody == null
            ? streamChunks
            : [Uint8List.fromList(responseBody!)],
      ),
      200,
      headers: responseHeaders,
    );
  }
}
