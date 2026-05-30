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
import 'package:newchat/features/providers/data/claude_provider.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

void main() {
  test('builds Claude request with system prompt and text message', () {
    final provider = ProviderConfig(
      id: 'p1',
      name: 'Claude Gateway',
      protocol: ProviderProtocol.claude,
      baseUrl: 'https://token.cylonai.cn',
      defaultModelId: 'claude-3-5-sonnet-latest',
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );
    const model = ModelConfig(
      id: 'claude-3-5-sonnet-latest',
      displayName: 'Claude 3.5 Sonnet',
      protocol: ProviderProtocol.claude,
      supportsStreaming: true,
      supportsImages: true,
    );

    final payload = buildClaudePayload(
      provider: provider,
      model: model,
      systemPrompt: 'Be concise.',
      messages: [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          state: MessageState.completed,
          parts: const [MessagePart.text('hello')],
          createdAt: DateTime.utc(2026, 5, 30),
          updatedAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      stream: true,
    );

    expect(payload['model'], 'claude-3-5-sonnet-latest');
    expect(payload['system'], 'Be concise.');
    expect(payload['stream'], isTrue);
    expect(payload['messages'], [
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'hello'},
        ],
      },
    ]);
  });

  test('trims text content and skips messages with empty content', () {
    final payload = buildClaudePayload(
      provider: _provider(),
      model: _model,
      systemPrompt: '',
      messages: [
        _message(role: ChatRole.user, parts: const [MessagePart.text('  ')]),
        _message(
          role: ChatRole.assistant,
          parts: const [MessagePart.text('  answer  ')],
        ),
      ],
      stream: false,
    );

    expect(payload['messages'], [
      {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'answer'},
        ],
      },
    ]);
  });

  test('blank system prompt is omitted', () {
    final payload = buildClaudePayload(
      provider: _provider(),
      model: _model,
      systemPrompt: '  ',
      messages: [
        _message(role: ChatRole.user, parts: const [MessagePart.text('hello')]),
      ],
      stream: false,
    );

    expect(payload.containsKey('system'), isFalse);
  });

  test('includes only completed user and assistant messages', () {
    final payload = buildClaudePayload(
      provider: _provider(),
      model: _model,
      systemPrompt: '',
      messages: [
        _message(role: ChatRole.system, parts: const [MessagePart.text('no')]),
        _message(
          role: ChatRole.user,
          state: MessageState.streaming,
          parts: const [MessagePart.text('streaming')],
        ),
        _message(
          role: ChatRole.assistant,
          state: MessageState.failed,
          parts: const [MessagePart.text('failed')],
        ),
        _message(
          role: ChatRole.user,
          parts: [MessagePart(type: MessagePartType.info, text: 'info')],
        ),
        _message(role: ChatRole.user, parts: const [MessagePart.text('user')]),
        _message(
          role: ChatRole.assistant,
          parts: const [MessagePart.text('assistant')],
        ),
      ],
      stream: true,
    );

    expect(payload['messages'], [
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'user'},
        ],
      },
      {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'assistant'},
        ],
      },
    ]);
  });

  test('image content uses base64 source and does not include localPath',
      () async {
    final payload = await buildClaudePayloadWithImages(
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
      loadAttachmentBytes: (_) async => utf8.encode('png bytes'),
    );

    final messages = payload['messages']! as List<Object?>;
    final message = messages.single! as Map<String, Object?>;
    final content = message['content']! as List<Object?>;
    final image = content.last! as Map<String, Object?>;
    final source = image['source']! as Map<String, Object?>;

    expect(content.first, {'type': 'text', 'text': 'look'});
    expect(image['type'], 'image');
    expect(source, {
      'type': 'base64',
      'media_type': 'image/png',
      'data': 'cG5nIGJ5dGVz',
    });
    expect(jsonEncode(payload), isNot(contains('C:\\images\\cat.png')));
  });

  test('quoted image context uses base64 image source', () async {
    const quotePreface = '''
The user is replying to this earlier image message:
"[Image] product screenshot"

User message:
make the background darker''';

    final payload = await buildClaudePayloadWithImages(
      provider: _provider(),
      model: _model,
      systemPrompt: '',
      messages: [
        _message(
          role: ChatRole.user,
          parts: [
            const MessagePart.text(quotePreface),
            MessagePart.image(
              const AttachmentRef(
                id: 'quoted-image',
                localPath: 'C:\\images\\quoted.png',
                mimeType: 'image/png',
              ),
            ),
          ],
        ),
      ],
      stream: true,
      loadAttachmentBytes: (_) async => utf8.encode('quoted png bytes'),
    );

    final messages = payload['messages']! as List<Object?>;
    final message = messages.single! as Map<String, Object?>;
    final content = message['content']! as List<Object?>;
    final image = content.last! as Map<String, Object?>;
    final source = image['source']! as Map<String, Object?>;

    expect(content.first, {'type': 'text', 'text': quotePreface});
    expect(image['type'], 'image');
    expect(source, {
      'type': 'base64',
      'media_type': 'image/png',
      'data': 'cXVvdGVkIHBuZyBieXRlcw==',
    });
    expect(jsonEncode(payload), isNot(contains('C:\\images\\quoted.png')));
  });

  test('buildClaudePayloadWithImages preserves compact context summary',
      () async {
    const summaryText = 'Earlier conversation summary:\n- user: old image';
    final payload = await buildClaudePayloadWithImages(
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
    final summaryContent = summary['content']! as List<Object?>;
    final summaryTextBlock = summaryContent.single! as Map<String, Object?>;
    final current = messages.last;
    final content = current['content']! as List<Object?>;
    final image = content.last! as Map<String, Object?>;
    final source = image['source']! as Map<String, Object?>;

    expect(summary['role'], 'user');
    expect(summaryTextBlock, {'type': 'text', 'text': summaryText});
    expect(source['data'], 'Y3VycmVudCBwbmcgYnl0ZXM=');
    expect(jsonEncode(payload), isNot(contains('C:\\images\\old.png')));
  });

  test('sync builder rejects image parts without bytes loader', () {
    expect(
      () => buildClaudePayload(
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

  test('parses Claude content block delta', () {
    final events = parseClaudeSse(
      'event: content_block_delta\n'
      'data: {"delta":{"type":"text_delta","text":"hi"}}\n\n',
    );

    expect(events.single, 'hi');
  });

  test('parser ignores non-text deltas and stop events', () {
    final events = parseClaudeSse(
      'event: content_block_delta\n'
      'data: {"delta":{"type":"input_json_delta","partial_json":"{}"}}\n\n'
      'event: message_stop\n'
      'data: {"type":"message_stop"}\n\n',
    );

    expect(events, isEmpty);
  });

  test('ClaudeProvider posts streaming request and emits deltas then done',
      () async {
    final adapter = _FakeHttpClientAdapter(
      streamChunks: [
        Uint8List.fromList(
          utf8.encode(
            'event: content_block_delta\n'
            'data: {"delta":{"type":"text_delta","text":"he"}}\n\n',
          ),
        ),
        Uint8List.fromList(
          utf8.encode(
            'event: content_block_delta\n'
            'data: {"delta":{"type":"text_delta","text":"llo"}}\n\n',
          ),
        ),
        Uint8List.fromList(
          utf8.encode('event: message_stop\ndata: {"type":"message_stop"}\n\n'),
        ),
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = ClaudeProvider(
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

    final labels = <String>[];
    for (final event in events) {
      switch (event) {
        case ChatStreamDelta(:final text):
          labels.add(text);
        case ChatStreamDone():
          labels.add('[DONE]');
        case ChatStreamFailed(:final error):
          labels.add(error.message);
      }
    }

    expect(labels, ['he', 'llo', '[DONE]']);
    expect(adapter.lastOptions?.method, 'POST');
    expect(adapter.lastOptions?.path, 'https://token.cylonai.cn/v1/messages');
    expect(adapter.lastOptions?.headers['x-api-key'], 'secret-key');
    expect(adapter.lastOptions?.headers['anthropic-version'], '2023-06-01');
    expect(adapter.lastOptions?.headers['Accept'], 'text/event-stream');
  });

  test('ClaudeProvider normalizes base URLs that already include v1', () async {
    final adapter = _FakeHttpClientAdapter(
      streamChunks: [
        Uint8List.fromList(
          utf8.encode('event: message_stop\ndata: {"type":"message_stop"}\n\n'),
        ),
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = ClaudeProvider(
      dio: dio,
      readApiKey: (_) async => 'secret-key',
    );

    await provider
        .sendStream(
          ChatRequest(
            provider:
                _provider().copyWithBaseUrl('https://api.anthropic.com/v1'),
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

    expect(adapter.lastOptions?.path, 'https://api.anthropic.com/v1/messages');
  });

  test('provider-level split SSE chunks are buffered correctly', () async {
    final adapter = _FakeHttpClientAdapter(
      streamChunks: [
        Uint8List.fromList(
          utf8.encode('event: content_block_delta\n'
              'data: {"delta":{"type":"text_delta"'),
        ),
        Uint8List.fromList(utf8.encode(',"text":"split"}}\n')),
        Uint8List.fromList(utf8.encode('\n')),
        Uint8List.fromList(
          utf8.encode('event: message_stop\ndata: {"type":"message_stop"}\n\n'),
        ),
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = ClaudeProvider(
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

  test('provider-level Claude SSE error event fails and stops stream',
      () async {
    final adapter = _FakeHttpClientAdapter(
      streamChunks: [
        Uint8List.fromList(
          utf8.encode(
            'event: content_block_delta\n'
            'data: {"delta":{"type":"text_delta","text":"before"}}\n\n',
          ),
        ),
        Uint8List.fromList(
          utf8.encode(
            'event: error\n'
            'data: {"type":"error","error":{"type":"overloaded_error",'
            '"message":"server is overloaded"}}\n\n',
          ),
        ),
        Uint8List.fromList(
          utf8.encode(
            'event: content_block_delta\n'
            'data: {"delta":{"type":"text_delta","text":"after"}}\n\n'
            'event: message_stop\n'
            'data: {"type":"message_stop"}\n\n',
          ),
        ),
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = ClaudeProvider(
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
    expect((events.first as ChatStreamDelta).text, 'before');
    final failure = events.last as ChatStreamFailed;
    expect(failure.error.type, ChatErrorType.unknown);
    expect(failure.error.message, 'Claude stream failed.');
    expect(failure.error.cause, isA<Map<String, Object?>>());
  });

  test('Dio errors are converted to ChatStreamFailed', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeHttpClientAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/v1/messages'),
          response: Response<void>(
            requestOptions: RequestOptions(path: '/v1/messages'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
          message: 'Unauthorized',
        ),
      );
    final provider = ClaudeProvider(
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

    expect(events.single, isA<ChatStreamFailed>());
    expect(
      (events.single as ChatStreamFailed).error.type,
      ChatErrorType.authentication,
    );
  });

  test('Dio error message is sanitized and raw error stays in cause', () async {
    const leakedKey = 'sk-ant-api03-secret';
    const leakedPath = 'C:\\Users\\dabin\\secret\\request.json';
    final dio = Dio()
      ..httpClientAdapter = _FakeHttpClientAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/v1/messages'),
          type: DioExceptionType.connectionError,
          message: 'Failed with $leakedKey while reading $leakedPath',
        ),
      );
    final provider = ClaudeProvider(
      dio: dio,
      readApiKey: (_) async => leakedKey,
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

    final failure = events.single as ChatStreamFailed;

    expect(failure.error.type, ChatErrorType.network);
    expect(failure.error.message, 'Claude network connection failed.');
    expect(failure.error.message, isNot(contains(leakedKey)));
    expect(failure.error.message, isNot(contains(leakedPath)));
    expect(failure.error.cause, isA<DioException>());
  });

  test('non-Dio image loader failure message is sanitized', () async {
    const localPath = 'C:\\Users\\dabin\\Pictures\\secret.png';
    final dio = Dio()..httpClientAdapter = _FakeHttpClientAdapter();
    final provider = ClaudeProvider(
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
    expect(failure.error.message, 'Claude request failed.');
    expect(failure.error.message, isNot(contains(localPath)));
    expect(failure.error.message, isNot(contains('secret-key')));
    expect(failure.error.cause, isA<FileSystemException>());
  });
}

ProviderConfig _provider() => ProviderConfig(
      id: 'p1',
      name: 'Claude Gateway',
      protocol: ProviderProtocol.claude,
      baseUrl: 'https://token.cylonai.cn',
      defaultModelId: 'claude-3-5-sonnet-latest',
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
  id: 'claude-3-5-sonnet-latest',
  displayName: 'Claude 3.5 Sonnet',
  protocol: ProviderProtocol.claude,
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
