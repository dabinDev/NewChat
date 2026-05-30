import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/app.dart';

void main() {
  testWidgets('session list shows provider setup guidance by default',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NewChatApp()));
    await tester.pumpAndSettle();

    expect(find.text('newchatbox'), findsOneWidget);
    expect(find.textContaining('provider', findRichText: true), findsWidgets);
    expect(find.byIcon(Icons.settings_outlined), findsWidgets);
    expect(find.text('New chat'), findsOneWidget);
  });
}
