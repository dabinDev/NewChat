enum ChatRole { user, assistant, system }

enum MessageState { completed, streaming, failed, cancelled, interrupted }

enum MessagePartType { text, image, reasoning, info, error }

class ChatSessionMeta {
  const ChatSessionMeta({
    required this.id,
    required this.title,
    required this.lastMessagePreview,
    required this.providerId,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.schemaVersion,
  });

  final String id;
  final String title;
  final String lastMessagePreview;
  final String providerId;
  final String modelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int schemaVersion;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'lastMessagePreview': lastMessagePreview,
        'providerId': providerId,
        'modelId': modelId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
        'schemaVersion': schemaVersion,
      };

  factory ChatSessionMeta.fromJson(Map<String, Object?> json) =>
      ChatSessionMeta(
        id: json['id']! as String,
        title: json['title']! as String,
        lastMessagePreview: json['lastMessagePreview']! as String,
        providerId: json['providerId']! as String,
        modelId: json['modelId']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        isDeleted: json['isDeleted']! as bool,
        schemaVersion: json['schemaVersion']! as int,
      );
}

class ChatSessionDocument {
  ChatSessionDocument({
    required this.id,
    required this.title,
    required this.providerId,
    required this.modelId,
    required this.systemPrompt,
    required List<ChatMessage> messages,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.contextSummary,
    this.contextSummaryUpdatedAt,
  }) : messages = List.unmodifiable(messages);

  final String id;
  final String title;
  final String providerId;
  final String modelId;
  final String systemPrompt;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final String? contextSummary;
  final DateTime? contextSummaryUpdatedAt;

  ChatSessionMeta get meta => ChatSessionMeta(
        id: id,
        title: title,
        lastMessagePreview: messages.reversed
            .expand((message) => message.parts)
            .where((part) => part.type == MessagePartType.text)
            .map((part) => part.text ?? '')
            .firstWhere((text) => text.isNotEmpty, orElse: () => ''),
        providerId: providerId,
        modelId: modelId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isDeleted: false,
        schemaVersion: schemaVersion,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'providerId': providerId,
        'modelId': modelId,
        'systemPrompt': systemPrompt,
        'messages': messages.map((message) => message.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'schemaVersion': schemaVersion,
        'contextSummary': contextSummary,
        'contextSummaryUpdatedAt': contextSummaryUpdatedAt?.toIso8601String(),
      };

  factory ChatSessionDocument.fromJson(Map<String, Object?> json) =>
      ChatSessionDocument(
        id: json['id']! as String,
        title: json['title']! as String,
        providerId: json['providerId']! as String,
        modelId: json['modelId']! as String,
        systemPrompt: json['systemPrompt']! as String,
        messages: (json['messages']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(ChatMessage.fromJson)
            .toList(),
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        schemaVersion: json['schemaVersion']! as int,
        contextSummary: json['contextSummary'] as String?,
        contextSummaryUpdatedAt: json['contextSummaryUpdatedAt'] == null
            ? null
            : DateTime.parse(json['contextSummaryUpdatedAt']! as String),
      );
}

class MessageEditEntry {
  const MessageEditEntry({
    required this.text,
    required this.editedAt,
  });

  final String text;
  final DateTime editedAt;

  Map<String, Object?> toJson() => {
        'text': text,
        'editedAt': editedAt.toIso8601String(),
      };

  factory MessageEditEntry.fromJson(Map<String, Object?> json) =>
      MessageEditEntry(
        text: json['text']! as String,
        editedAt: DateTime.parse(json['editedAt']! as String),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.state,
    required List<MessagePart> parts,
    required this.createdAt,
    required this.updatedAt,
    this.replyToMessageId,
    this.replyPreview,
    this.editedAt,
    List<MessageEditEntry> editHistory = const [],
  })  : parts = List.unmodifiable(parts),
        editHistory = List.unmodifiable(editHistory);

  final String id;
  final ChatRole role;
  final MessageState state;
  final List<MessagePart> parts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? replyToMessageId;
  final String? replyPreview;
  final DateTime? editedAt;
  final List<MessageEditEntry> editHistory;

  String get fullText => parts
      .where((part) => part.type == MessagePartType.text)
      .map((part) => part.text!)
      .join();

  Map<String, Object?> toJson() => {
        'id': id,
        'role': role.name,
        'state': state.name,
        'parts': parts.map((part) => part.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'replyToMessageId': replyToMessageId,
        'replyPreview': replyPreview,
        'editedAt': editedAt?.toIso8601String(),
        'editHistory': editHistory.map((entry) => entry.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, Object?> json) => ChatMessage(
        id: json['id']! as String,
        role: ChatRole.values.byName(json['role']! as String),
        state: MessageState.values.byName(json['state']! as String),
        parts: (json['parts']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(MessagePart.fromJson)
            .toList(),
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        replyToMessageId: json['replyToMessageId'] as String?,
        replyPreview: json['replyPreview'] as String?,
        editedAt: json['editedAt'] == null
            ? null
            : DateTime.parse(json['editedAt']! as String),
        editHistory: ((json['editHistory'] as List<Object?>?) ?? [])
            .cast<Map<String, Object?>>()
            .map(MessageEditEntry.fromJson)
            .toList(),
      );
}

class MessagePart {
  factory MessagePart({
    required MessagePartType type,
    String? text,
    AttachmentRef? attachment,
  }) {
    _validatePayload(type: type, text: text, attachment: attachment);
    return MessagePart._(
      type: type,
      text: text,
      attachment: attachment,
    );
  }

  const MessagePart._({
    required this.type,
    this.text,
    this.attachment,
  });

  const MessagePart.text(this.text)
      : type = MessagePartType.text,
        attachment = null;

  const MessagePart.error(this.text)
      : type = MessagePartType.error,
        attachment = null;

  MessagePart.image(this.attachment)
      : type = MessagePartType.image,
        text = null;

  final MessagePartType type;
  final String? text;
  final AttachmentRef? attachment;

  Map<String, Object?> toJson() => {
        'type': type.name,
        'text': text,
        'attachment': attachment?.toJson(),
      };

  factory MessagePart.fromJson(Map<String, Object?> json) {
    try {
      final attachmentJson = json['attachment'];
      return MessagePart(
        type: MessagePartType.values.byName(json['type']! as String),
        text: json['text'] as String?,
        attachment: attachmentJson == null
            ? null
            : AttachmentRef.fromJson(
                attachmentJson as Map<String, Object?>,
              ),
      );
    } on Object catch (error) {
      throw FormatException('Invalid message part payload: $error');
    }
  }

  static void _validatePayload({
    required MessagePartType type,
    required String? text,
    required AttachmentRef? attachment,
  }) {
    switch (type) {
      case MessagePartType.text:
      case MessagePartType.reasoning:
      case MessagePartType.info:
      case MessagePartType.error:
        if (text == null || attachment != null) {
          throw ArgumentError.value(
            type,
            'type',
            'Text-based message parts require text and no attachment.',
          );
        }
      case MessagePartType.image:
        if (text != null || attachment == null) {
          throw ArgumentError.value(
            type,
            'type',
            'Image message parts require an attachment and no text.',
          );
        }
    }
  }
}

class AttachmentRef {
  const AttachmentRef({
    required this.id,
    required this.localPath,
    required this.mimeType,
    this.width,
    this.height,
    this.fileSize,
  });

  final String id;
  final String localPath;
  final String mimeType;
  final int? width;
  final int? height;
  final int? fileSize;

  Map<String, Object?> toJson() => {
        'id': id,
        'localPath': localPath,
        'mimeType': mimeType,
        'width': width,
        'height': height,
        'fileSize': fileSize,
      };

  factory AttachmentRef.fromJson(Map<String, Object?> json) => AttachmentRef(
        id: json['id']! as String,
        localPath: json['localPath']! as String,
        mimeType: json['mimeType']! as String,
        width: json['width'] as int?,
        height: json['height'] as int?,
        fileSize: json['fileSize'] as int?,
      );
}
