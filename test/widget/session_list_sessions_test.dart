import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/presentation/chat_screen.dart';
import 'package:newchat/features/chat/presentation/session_list_screen.dart';
import 'package:newchat/features/demo/demo_data.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('session list can render demo session cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SessionListScreen(initialHasProvider: true),
      ),
    );

    expect(find.text('Planning notes'), findsOneWidget);
    expect(find.text('Summarize the rollout checklist.'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });

  testWidgets('chat header handles long title and model on narrow screens',
      (tester) async {
    final session = demoChatSession.copyWith(
      title: 'Very long planning notes title that must stay inside the app bar',
      providerId: 'Very long provider name for a narrow phone',
      modelId: 'very-long-model-name-that-should-ellipsize',
    );

    await tester.binding.setSurfaceSize(const Size(240, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          child: ChatScreen(
            sessionId: session.id,
            demoSession: session,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Very long planning notes'), findsOneWidget);
  });
}
