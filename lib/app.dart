import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/routing/app_routes.dart';
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
        path: AppRoutes.home,
        builder: (context, state) => const SessionListScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          return ChatScreen(sessionId: state.pathParameters['sessionId']!);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.newProvider,
        builder: (context, state) => const ProviderEditorScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProvider,
        builder: (context, state) {
          return ProviderEditorScreen(
            providerId: state.pathParameters['providerId']!,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.models,
        builder: (context, state) => const ModelManagerScreen(),
      ),
      GoRoute(
        path: AppRoutes.systemPrompt,
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
    const primary = Color(0xFF123C44);
    const secondary = Color(0xFFE0B84D);
    const surface = Color(0xFFF7F4EC);
    const radius = Radius.circular(8);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: surface,
      brightness: Brightness.light,
    );

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: primary,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: const CardTheme(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(radius),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: secondary,
          foregroundColor: Color(0xFF1D1B16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(radius),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: secondary,
            foregroundColor: const Color(0xFF1D1B16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(radius),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(radius),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(radius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(radius),
            borderSide: BorderSide(color: Color(0xFFD8D0C0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(radius),
            borderSide: BorderSide(color: primary, width: 1.4),
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(radius),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: radius),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}
