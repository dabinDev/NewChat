import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/providers/presentation/provider_editor_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets(
      'provider editor preserves typed fields across local state changes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderEditorScreen(),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Provider name'),
      'Personal gateway',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Base URL'),
      'https://gateway.example/v1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API key'),
      'sk-live-local',
    );

    await tester.tap(find.byTooltip('Show API key'));
    await tester.pump();

    expect(find.text('Personal gateway'), findsOneWidget);
    expect(find.text('https://gateway.example/v1'), findsOneWidget);
    expect(find.text('sk-live-local'), findsOneWidget);

    await tester.tap(find.text('Claude'));
    await tester.pump();

    expect(find.text('Personal gateway'), findsOneWidget);
    expect(find.text('https://gateway.example/v1'), findsOneWidget);
    expect(find.text('sk-live-local'), findsOneWidget);
  });
}
