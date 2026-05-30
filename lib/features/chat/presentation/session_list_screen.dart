import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/routing/app_routes.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/application/session_list_controller.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SessionListScreen extends ConsumerWidget {
  const SessionListScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: sessions.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return _EmptyProviderState(
              message: l10n.providerRequired,
              onOpenSettings: () => context.go(AppRoutes.settings),
            );
          }
          return _SessionList(sessions: sessions);
        },
        error: (error, _) => _EmptyProviderState(
          message: l10n.providerRequired,
          onOpenSettings: () => context.go(AppRoutes.settings),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.chatPath('new')),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.newChat),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
  });

  final List<ChatSessionMeta> sessions;

  @override
  Widget build(BuildContext context) {
    final controller = SessionListController(
      repository: ProviderScope.containerOf(context).read(
        sessionRepositoryProvider,
      ),
    );
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(
              session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: session.isUnread
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
            subtitle: Text(
              session.lastMessagePreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _SessionTrailing(
              session: session,
              controller: controller,
            ),
            onTap: () async {
              if (session.isUnread) {
                await controller.markRead(session.id);
                if (context.mounted) {
                  ProviderScope.containerOf(context).refresh(
                    sessionListControllerProvider,
                  );
                }
              }
              if (context.mounted) {
                context.go(AppRoutes.chatPath(session.id));
              }
            },
          ),
        );
      },
    );
  }
}

class _SessionTrailing extends StatelessWidget {
  const _SessionTrailing({
    required this.session,
    required this.controller,
  });

  final ChatSessionMeta session;
  final SessionListController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (session.isUnread)
          Container(
            key: const Key('session-unread-indicator'),
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        if (session.isPinned)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.push_pin_outlined, size: 18),
          ),
        PopupMenuButton<_SessionAction>(
          tooltip: 'Session actions',
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (context) => [
            PopupMenuItem(
              value:
                  session.isPinned ? _SessionAction.unpin : _SessionAction.pin,
              child: ListTile(
                leading: Icon(
                  session.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(session.isPinned ? 'Unpin' : 'Pin'),
              ),
            ),
            PopupMenuItem(
              value: session.isUnread
                  ? _SessionAction.markRead
                  : _SessionAction.markUnread,
              child: ListTile(
                leading: Icon(
                  session.isUnread
                      ? Icons.mark_chat_read_outlined
                      : Icons.mark_chat_unread_outlined,
                ),
                title: Text(session.isUnread ? 'Mark read' : 'Mark unread'),
              ),
            ),
            const PopupMenuItem(
              value: _SessionAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    _SessionAction action,
  ) async {
    switch (action) {
      case _SessionAction.pin:
        await controller.pinSession(session.id);
      case _SessionAction.unpin:
        await controller.unpinSession(session.id);
      case _SessionAction.markUnread:
        await controller.markUnread(session.id);
      case _SessionAction.markRead:
        await controller.markRead(session.id);
      case _SessionAction.delete:
        await controller.softDeleteSession(session.id);
    }
    if (context.mounted) {
      ProviderScope.containerOf(context).refresh(sessionListControllerProvider);
    }
  }
}

enum _SessionAction { pin, unpin, markUnread, markRead, delete }

class _EmptyProviderState extends StatelessWidget {
  const _EmptyProviderState({
    required this.message,
    required this.onOpenSettings,
  });

  final String message;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Provider settings are required before a chat can send.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: Text(l10n.settings),
            ),
          ],
        ),
      ),
    );
  }
}
