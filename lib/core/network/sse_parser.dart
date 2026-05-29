class SseEvent {
  const SseEvent({
    required this.data,
    this.event,
  });

  final String? event;
  final String data;
}

List<SseEvent> parseSseChunk(String chunk) {
  final normalized = _normalizeLineEndings(chunk);
  final lastDelimiter = normalized.lastIndexOf('\n\n');
  if (lastDelimiter == -1) {
    return const [];
  }

  return _parseCompleteFrames(normalized.substring(0, lastDelimiter + 2));
}

class SseParser {
  final _buffer = StringBuffer();
  bool _pendingCarriageReturn = false;

  List<SseEvent> addChunk(String chunk) {
    _buffer.write(_normalizeStreamingLineEndings(chunk));

    final buffered = _buffer.toString();
    final lastDelimiter = buffered.lastIndexOf('\n\n');
    if (lastDelimiter == -1) {
      return const [];
    }

    final completeFrames = buffered.substring(0, lastDelimiter + 2);
    final partialFrame = buffered.substring(lastDelimiter + 2);

    _buffer
      ..clear()
      ..write(partialFrame);

    return _parseCompleteFrames(completeFrames);
  }

  List<SseEvent> close() {
    final buffered = _buffer.toString();
    _buffer.clear();
    _pendingCarriageReturn = false;

    if (buffered.isEmpty) {
      return const [];
    }

    return _parseCompleteFrames(buffered);
  }

  String _normalizeStreamingLineEndings(String chunk) {
    final normalized = StringBuffer();

    for (var index = 0; index < chunk.length; index++) {
      final character = chunk[index];
      if (_pendingCarriageReturn) {
        _pendingCarriageReturn = false;
        if (character == '\n') {
          continue;
        }
      }

      if (character == '\r') {
        normalized.write('\n');
        _pendingCarriageReturn = true;
      } else {
        normalized.write(character);
      }
    }

    return normalized.toString();
  }
}

String _normalizeLineEndings(String chunk) {
  return chunk.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

List<SseEvent> _parseCompleteFrames(String normalized) {
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
        event = _fieldValue(line, 'event:');
      } else if (line.startsWith('data:')) {
        dataLines.add(_fieldValue(line, 'data:'));
      }
    }

    if (dataLines.isNotEmpty) {
      events.add(SseEvent(event: event, data: dataLines.join('\n')));
    }
  }

  return events;
}

String _fieldValue(String line, String fieldPrefix) {
  final value = line.substring(fieldPrefix.length);
  if (value.startsWith(' ')) {
    return value.substring(1);
  }
  return value;
}
