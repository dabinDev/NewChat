import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/app.dart';

void main() {
  testWidgets('app starts and shows title', (tester) async {
    await tester.pumpWidget(const NewChatApp());
    await tester.pumpAndSettle();

    expect(find.text('NewChat'), findsWidgets);
  });
}
