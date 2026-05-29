import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/presentation/session_list_screen.dart';
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
}
