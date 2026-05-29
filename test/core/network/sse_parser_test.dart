import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/network/sse_parser.dart';

void main() {
  test('parses SSE event with data', () {
    final events = parseSseChunk('event: content_block_delta\ndata: {"x":1}\n\n');

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
}
