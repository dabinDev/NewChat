import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('ChatInputBar shows localized error when model rejects images',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInputBar(
            supportsImages: false,
            onSend: (_, __) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.image_outlined));
    await tester.pump();

    expect(
      find.text('The selected model does not support images.'),
      findsOneWidget,
    );
  });
}
