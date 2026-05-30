import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/app.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('Chinese localization loads appTitle', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NewChatApp(),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(AppLocalizations.supportedLocales, contains(const Locale('zh')));
    expect(l10n.appTitle, 'newchatbox');
  });

  testWidgets('app starts and shows title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NewChatApp()));
    await tester.pumpAndSettle();

    expect(find.text('newchatbox'), findsWidgets);
  });
}
