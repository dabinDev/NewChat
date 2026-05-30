import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/routing/app_routes.dart';
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

  testWidgets('chat screen exposes a back button', (tester) async {
    final session = demoChatSession.copyWith(id: 'session-with-back');

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

    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('real chat session does not show demo content while loading',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(
              _NeverCompletingSessionRepository(),
            ),
          ],
          child: const ChatScreen(sessionId: 'real-session'),
        ),
      ),
    );

    expect(find.text('Draft a concise rollout checklist.'), findsNothing);
  });

  testWidgets('chat input stays above keyboard inset', (tester) async {
    final session = demoChatSession.copyWith(
      messages: const [],
    );

    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    addTearDown(() => tester.view.resetViewInsets());

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
    await tester.pumpAndSettle();

    final inputBottom = tester.getBottomLeft(find.text('Send')).dy;

    expect(tester.takeException(), isNull);
    expect(inputBottom, lessThan(420));
  });

  testWidgets('retryable assistant state shows continue control',
      (tester) async {
    final session = demoChatSession.copyWith(
      id: 'retry-demo',
      messages: [
        ChatMessage(
          id: 'user-1',
          role: ChatRole.user,
          state: MessageState.completed,
          parts: const [MessagePart.text('hello')],
          createdAt: DateTime.utc(2026, 5, 30),
          updatedAt: DateTime.utc(2026, 5, 30),
        ),
        ChatMessage(
          id: 'assistant-1',
          role: ChatRole.assistant,
          state: MessageState.interrupted,
          parts: const [MessagePart.text('partial')],
          createdAt: DateTime.utc(2026, 5, 30, 1),
          updatedAt: DateTime.utc(2026, 5, 30, 1),
        ),
      ],
    );

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

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('session list shows pinned sessions first with pin icon',
      (tester) async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(
      _sessionDocument(
        id: 'recent',
        title: 'Recent chat',
        updatedAt: DateTime.utc(2026, 5, 30, 3),
      ),
    );
    await repository.saveDocument(
      _sessionDocument(
        id: 'pinned',
        title: 'Pinned chat',
        updatedAt: DateTime.utc(2026, 5, 30, 1),
        isPinned: true,
        pinnedAt: DateTime.utc(2026, 5, 30, 2),
      ),
    );

    await _pumpSessionList(tester, repository);

    final pinnedTop = tester.getTopLeft(find.text('Pinned chat')).dy;
    final recentTop = tester.getTopLeft(find.text('Recent chat')).dy;
    expect(pinnedTop, lessThan(recentTop));
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  testWidgets('session menu toggles pin unread and delete', (tester) async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(_sessionDocument(id: 'session-1'));

    await _pumpSessionList(tester, repository);

    await tester.tap(find.byTooltip('Session actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect((await repository.loadDocument('session-1'))!.isPinned, isTrue);

    await tester.tap(find.byTooltip('Session actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark unread'));
    await tester.pumpAndSettle();
    expect((await repository.loadDocument('session-1'))!.isUnread, isTrue);
    expect(find.byKey(const Key('session-unread-indicator')), findsOneWidget);

    await tester.tap(find.byTooltip('Session actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await repository.loadDocument('session-1'), isNull);
    expect(find.text('Title session-1'), findsNothing);
  });

  testWidgets('opening unread session marks it read', (tester) async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(
      _sessionDocument(id: 'session-1', isUnread: true),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const SessionListScreen(),
        ),
        GoRoute(
          path: AppRoutes.chat,
          builder: (context, state) => const Scaffold(
            body: Text('Chat target'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Title session-1'));
    await tester.pumpAndSettle();

    expect((await repository.loadDocument('session-1'))!.isUnread, isFalse);
    expect(find.text('Chat target'), findsOneWidget);
  });
}

class _NeverCompletingSessionRepository implements SessionRepository {
  @override
  Future<void> deleteSession(String id) => Future<void>.value();

  @override
  Future<ChatSessionDocument?> loadDocument(String id) =>
      Completer<ChatSessionDocument?>().future;

  @override
  Future<List<ChatSessionMeta>> listMetas() => Future.value(const []);

  @override
  Future<void> saveDocument(ChatSessionDocument document) =>
      Future<void>.value();

  @override
  Future<void> softDeleteSession(String id) => Future<void>.value();
}

Future<void> _pumpSessionList(
  WidgetTester tester,
  SessionRepository repository,
) async {
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
}

ChatSessionDocument _sessionDocument({
  required String id,
  String? title,
  DateTime? updatedAt,
  bool isPinned = false,
  DateTime? pinnedAt,
  bool isUnread = false,
}) {
  final now = DateTime.utc(2026, 5, 30);
  return ChatSessionDocument(
    id: id,
    title: title ?? 'Title $id',
    providerId: 'provider-1',
    modelId: 'gpt-4o-mini',
    systemPrompt: '',
    messages: [
      ChatMessage(
        id: 'message-$id',
        role: ChatRole.user,
        state: MessageState.completed,
        parts: [MessagePart.text('Preview $id')],
        createdAt: now,
        updatedAt: updatedAt ?? now,
      ),
    ],
    createdAt: now,
    updatedAt: updatedAt ?? now,
    schemaVersion: 1,
    isPinned: isPinned,
    pinnedAt: pinnedAt,
    isUnread: isUnread,
  );
}
