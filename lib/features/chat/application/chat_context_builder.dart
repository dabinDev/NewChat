import 'package:newchat/features/chat/domain/chat_models.dart';

class ChatContextBuildResult {
  const ChatContextBuildResult({
    required this.messages,
    required this.summary,
    required this.summaryUpdatedAt,
  });

  final List<ChatMessage> messages;
  final String? summary;
  final DateTime? summaryUpdatedAt;
}

class ChatContextBuilder {
  const ChatContextBuilder({this.recentMessageLimit = 12});

  final int recentMessageLimit;

  ChatContextBuildResult build(ChatSessionDocument document) {
    final completed = document.messages
        .where(
          (message) =>
              message.state == MessageState.completed &&
              (message.role == ChatRole.user ||
                  message.role == ChatRole.assistant),
        )
        .toList();
    final recentCount = recentMessageLimit < 0 ? 0 : recentMessageLimit;
    final splitIndex =
        completed.length > recentCount ? completed.length - recentCount : 0;
    final older = completed.take(splitIndex);
    final recent = completed.skip(splitIndex).toList();
    final summaryParts = [
      if (_hasText(document.contextSummary)) document.contextSummary!.trim(),
      for (final message in older)
        if (_compactText(message.fullText).isNotEmpty)
          '- ${message.role.name}: ${_truncate(_compactText(message.fullText))}',
    ];
    final summary = summaryParts.isEmpty ? null : summaryParts.join('\n');
    final latestUserId = completed.reversed
        .where((message) => message.role == ChatRole.user)
        .map((message) => message.id)
        .firstOrNull;
    final summaryChanged = summary != null &&
        summary != _normalizedSummary(document.contextSummary);
    final providerMessages = [
      if (summary != null) _summaryMessage(summary),
      for (final message in recent)
        _providerMessage(
          message,
          preserveImages: message.id == latestUserId,
          addQuotePreface:
              message.role == ChatRole.user && _hasText(message.replyPreview),
        ),
    ];

    final summaryUpdatedAt = summary == null
        ? null
        : summaryChanged
            ? DateTime.now().toUtc()
            : document.contextSummaryUpdatedAt ?? DateTime.now().toUtc();

    return ChatContextBuildResult(
      messages: List.unmodifiable(providerMessages),
      summary: summary,
      summaryUpdatedAt: summaryUpdatedAt,
    );
  }

  static String? _normalizedSummary(String? summary) =>
      _hasText(summary) ? summary!.trim() : null;

  static bool _hasText(String? text) => text != null && text.trim().isNotEmpty;

  static ChatMessage _summaryMessage(String summary) {
    final now = DateTime.now().toUtc();
    return ChatMessage(
      id: 'context-summary',
      role: ChatRole.system,
      state: MessageState.completed,
      parts: [MessagePart.text('Earlier conversation summary:\n$summary')],
      createdAt: now,
      updatedAt: now,
    );
  }

  static ChatMessage _providerMessage(
    ChatMessage message, {
    required bool preserveImages,
    required bool addQuotePreface,
  }) {
    final parts = <MessagePart>[
      if (addQuotePreface)
        MessagePart.text(
          'The user is replying to this earlier message:\n'
          '"${_compactText(message.replyPreview!)}"\n\n'
          'User message:\n'
          '${message.fullText}',
        )
      else
        ...message.parts.where((part) => part.type != MessagePartType.image),
      if (preserveImages)
        ...message.parts.where((part) => part.type == MessagePartType.image),
    ];

    return ChatMessage(
      id: message.id,
      role: message.role,
      state: message.state,
      parts: parts,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      replyToMessageId: message.replyToMessageId,
      replyPreview: message.replyPreview,
      editedAt: message.editedAt,
      editHistory: message.editHistory,
    );
  }

  static String _compactText(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _truncate(String text) {
    const maxLength = 500;
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength - 1)}...';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
