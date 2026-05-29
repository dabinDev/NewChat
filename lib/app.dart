import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/features/chat/presentation/chat_screen.dart';
import 'package:newchat/features/chat/presentation/session_list_screen.dart';
import 'package:newchat/features/providers/presentation/model_manager_screen.dart';
import 'package:newchat/features/providers/presentation/provider_editor_screen.dart';
import 'package:newchat/features/providers/presentation/settings_screen.dart';
import 'package:newchat/features/system_prompt/presentation/system_prompt_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NewChatApp extends StatelessWidget {
  const NewChatApp({super.key});

  static final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SessionListScreen(),
      ),
      GoRoute(
        path: '/chat/:sessionId',
        builder: (context, state) {
          return ChatScreen(sessionId: state.pathParameters['sessionId']!);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/provider/new',
        builder: (context, state) => const ProviderEditorScreen(),
      ),
      GoRoute(
        path: '/settings/models',
        builder: (context, state) => const ModelManagerScreen(),
      ),
      GoRoute(
        path: '/chat/:sessionId/system-prompt',
        builder: (context, state) {
          return SystemPromptScreen(
            sessionId: state.pathParameters['sessionId']!,
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
