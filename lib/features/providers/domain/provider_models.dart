import 'package:newchat/core/constants/app_constants.dart';

class ProviderConfig {
  const ProviderConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.defaultModelId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final ProviderProtocol protocol;
  final String baseUrl;
  final String defaultModelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'baseUrl': baseUrl,
        'defaultModelId': defaultModelId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ProviderConfig.fromJson(Map<String, Object?> json) => ProviderConfig(
        id: json['id']! as String,
        name: json['name']! as String,
        protocol: ProviderProtocol.values.byName(json['protocol']! as String),
        baseUrl: json['baseUrl']! as String,
        defaultModelId: json['defaultModelId']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );
}

class ModelConfig {
  const ModelConfig({
    required this.id,
    required this.displayName,
    required this.protocol,
    required this.supportsStreaming,
    required this.supportsImages,
    this.contextLength,
  });

  final String id;
  final String displayName;
  final ProviderProtocol protocol;
  final bool supportsStreaming;
  final bool supportsImages;
  final int? contextLength;

  bool get effectiveSupportsImages {
    if (supportsImages) {
      return true;
    }
    if (protocol != ProviderProtocol.openai) {
      return false;
    }
    final lower = id.toLowerCase();
    return lower.startsWith('gpt-') && !lower.contains('audio');
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'protocol': protocol.name,
        'supportsStreaming': supportsStreaming,
        'supportsImages': supportsImages,
        'contextLength': contextLength,
      };

  factory ModelConfig.fromJson(Map<String, Object?> json) => ModelConfig(
        id: json['id']! as String,
        displayName: json['displayName']! as String,
        protocol: ProviderProtocol.values.byName(json['protocol']! as String),
        supportsStreaming: json['supportsStreaming']! as bool,
        supportsImages: json['supportsImages']! as bool,
        contextLength: json['contextLength'] as int?,
      );
}
