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
  const ChatSessionDocument({
    required this.id,
    required this.title,
    required this.providerId,
    required this.modelId,
    required this.systemPrompt,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

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
  const ChatMessage({
    required this.id,
    required this.role,
    required this.state,
    required this.parts,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ChatRole role;
  final MessageState state;
  final List<MessagePart> parts;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullText => parts
      .where((part) => part.text != null)
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
  const MessagePart({
    required this.type,
    this.text,
    this.attachment,
  });

  const MessagePart.text(String text)
      : this(
          type: MessagePartType.text,
          text: text,
        );

  const MessagePart.error(String text)
      : this(
          type: MessagePartType.error,
          text: text,
        );

  MessagePart.image(AttachmentRef attachment)
      : this(
          type: MessagePartType.image,
          attachment: attachment,
        );

  final MessagePartType type;
  final String? text;
  final AttachmentRef? attachment;

  Map<String, Object?> toJson() => {
        'type': type.name,
        'text': text,
        'attachment': attachment?.toJson(),
      };

  factory MessagePart.fromJson(Map<String, Object?> json) => MessagePart(
        type: MessagePartType.values.byName(json['type']! as String),
        text: json['text'] as String?,
        attachment: json['attachment'] == null
            ? null
            : AttachmentRef.fromJson(
                json['attachment']! as Map<String, Object?>,
              ),
      );
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
