enum ChatErrorType {
  authentication,
  permission,
  notFound,
  badRequest,
  timeout,
  network,
  parsing,
  cancelled,
  unknown,
}

class ChatError implements Exception {
  const ChatError({
    required this.type,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final ChatErrorType type;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'ChatError($type, $statusCode, $message)';
}
