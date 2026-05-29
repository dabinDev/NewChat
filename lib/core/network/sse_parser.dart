class SseEvent {
  const SseEvent({
    required this.data,
    this.event,
  });

  final String? event;
  final String data;
}

List<SseEvent> parseSseChunk(String chunk) {
  final normalized = chunk.replaceAll('\r\n', '\n');
  final blocks = normalized.split('\n\n');
  final events = <SseEvent>[];

  for (final block in blocks) {
    String? event;
    final dataLines = <String>[];

    for (final rawLine in block.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty || line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('event:')) {
        event = line.substring('event:'.length).trimLeft();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trimLeft());
      }
    }

    if (dataLines.isNotEmpty) {
      events.add(SseEvent(event: event, data: dataLines.join('\n')));
    }
  }

  return events;
}
