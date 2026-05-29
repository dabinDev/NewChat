import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/routing/app_routes.dart';

void main() {
  group('AppRoutes', () {
    test('builds static paths', () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.settings, '/settings');
      expect(AppRoutes.newProvider, '/settings/provider/new');
      expect(AppRoutes.models, '/settings/models');
      expect(AppRoutes.chat, '/chat/:sessionId');
      expect(AppRoutes.systemPrompt, '/chat/:sessionId/system-prompt');
    });

    test('encodes session ids in chat paths', () {
      expect(
        AppRoutes.chatPath('session with/slash'),
        '/chat/session%20with%2Fslash',
      );
      expect(
        AppRoutes.systemPromptPath('session with/slash'),
        '/chat/session%20with%2Fslash/system-prompt',
      );
    });
  });
}
