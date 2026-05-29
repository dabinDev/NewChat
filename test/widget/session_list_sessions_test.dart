import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/chat_screen.dart';
import 'package:newchat/features/chat/presentation/session_list_screen.dart';
import 'package:newchat/features/demo/demo_data.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('session list renders repository session cards', (tester) async {
    final repository = InMemorySessionRepository();
    final now = DateTime.utc(2026, 5, 30);
    await repository.saveDocument(
      ChatSessionDocument(
        id: 'real-session',
        title: 'Real persisted chat',
        providerId: 'provider-1',
        modelId: 'gpt-4o-mini',
        systemPrompt: '',
        messages: [
          ChatMessage(
            id: 'message-1',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('Loaded from repository')],
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SessionListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Real persisted chat'), findsOneWidget);
    expect(find.text('Loaded from repository'), findsOneWidget);
    expect(find.text('Planning notes'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
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
