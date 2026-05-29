enum ChatRole { user, assistant, system }

enum MessageState { completed, streaming, failed, cancelled, interrupted }

enum MessagePartType { text, image, reasoning, info, error }

class ChatSessionMeta {
  const ChatSessionMeta({
    required this.id,
    required this.title,
    required this.providerId,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  final String id;
  final String title;
  final String providerId;
  final String modelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'providerId': providerId,
        'modelId': modelId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  factory ChatSessionMeta.fromJson(Map<String, Object?> json) =>
      ChatSessionMeta(
        id: json['id']! as String,
        title: json['title']! as String,
        providerId: json['providerId']! as String,
        modelId: json['modelId']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
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

  ChatSessionMeta get meta => ChatSessionMeta(
        id: id,
        title: title,
        providerId: providerId,
        modelId: modelId,
        createdAt: createdAt,
        updatedAt: updatedAt,
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
  }) : parts = List.unmodifiable(parts);

  final String id;
  final ChatRole role;
  final MessageState state;
  final List<MessagePart> parts;
  final DateTime createdAt;
  final DateTime updatedAt;

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

  const MessagePart.text(String text)
      : type = MessagePartType.text,
        text = text,
        attachment = null;

  const MessagePart.error(String text)
      : type = MessagePartType.error,
        text = text,
        attachment = null;

  MessagePart.image(AttachmentRef attachment)
      : type = MessagePartType.image,
        text = null,
        attachment = attachment;

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
