import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/network/sse_parser.dart';

void main() {
  test('parses SSE event with data', () {
    final events =
        parseSseChunk('event: content_block_delta\ndata: {"x":1}\n\n');

    expect(events, hasLength(1));
    expect(events.single.event, 'content_block_delta');
    expect(events.single.data, '{"x":1}');
  });

  test('parses OpenAI data-only event', () {
    final events = parseSseChunk('data: {"choices":[]}\n\n');

    expect(events.single.event, isNull);
    expect(events.single.data, '{"choices":[]}');
  });

  test('ignores comments and blank chunks', () {
    final events = parseSseChunk(': keepalive\n\n');

    expect(events, isEmpty);
  });

  test('parseSseChunk ignores trailing partial event', () {
    final events = parseSseChunk('data: partial');

    expect(events, isEmpty);
  });

  test('SseParser buffers event split across chunks', () {
    final parser = SseParser();

    expect(parser.addChunk('data: {"x"'), isEmpty);

    final events = parser.addChunk(':1}\n\n');

    expect(events, hasLength(1));
    expect(events.single.event, isNull);
    expect(events.single.data, '{"x":1}');
  });

  test('SseParser buffers line split across chunks', () {
    final parser = SseParser();

    expect(parser.addChunk('event: content_'), isEmpty);

    final events = parser.addChunk('block_delta\ndata: hi\n\n');

    expect(events, hasLength(1));
    expect(events.single.event, 'content_block_delta');
    expect(events.single.data, 'hi');
  });

  test('parses multiple events in one chunk', () {
    final events = parseSseChunk(
      'event: first\ndata: one\n\n'
      'event: second\ndata: two\n\n',
    );

    expect(events, hasLength(2));
    expect(events[0].event, 'first');
    expect(events[0].data, 'one');
    expect(events[1].event, 'second');
    expect(events[1].data, 'two');
  });

  test('parses CRLF and lone CR line endings', () {
    final crlfEvents = parseSseChunk('event: crlf\r\ndata: one\r\n\r\n');
    final crEvents = parseSseChunk('event: cr\rdata: two\r\r');

    expect(crlfEvents, hasLength(1));
    expect(crlfEvents.single.event, 'crlf');
    expect(crlfEvents.single.data, 'one');
    expect(crEvents, hasLength(1));
    expect(crEvents.single.event, 'cr');
    expect(crEvents.single.data, 'two');
  });

  test('joins multiline data with newline', () {
    final events = parseSseChunk('data: hello\ndata: world\n\n');

    expect(events, hasLength(1));
    expect(events.single.data, 'hello\nworld');
  });

  test('removes at most one leading space after field colon', () {
    final events = parseSseChunk('event:  spaced\ndata:  indented\n\n');

    expect(events, hasLength(1));
    expect(events.single.event, ' spaced');
    expect(events.single.data, ' indented');
  });

  test('close flushes final buffered event with data', () {
    final parser = SseParser();

    expect(parser.addChunk('event: final\ndata: done'), isEmpty);

    final events = parser.close();

    expect(events, hasLength(1));
    expect(events.single.event, 'final');
    expect(events.single.data, 'done');
  });
}
