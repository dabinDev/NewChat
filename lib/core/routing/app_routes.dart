abstract final class AppRoutes {
  static const home = '/';
  static const settings = '/settings';
  static const newProvider = '/settings/provider/new';
  static const models = '/settings/models';
  static const chat = '/chat/:sessionId';
  static const systemPrompt = '/chat/:sessionId/system-prompt';

  static String chatPath(String sessionId) {
    return '/chat/${Uri.encodeComponent(sessionId)}';
  }

  static String systemPromptPath(String sessionId) {
    return '${chatPath(sessionId)}/system-prompt';
  }
}
