import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/routing/app_routes.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({
    super.key,
    this.initialHasProvider = false,
  });

  final bool initialHasProvider;

  static final List<ChatSessionMeta> _sessions = [
    ChatSessionMeta(
      id: 'demo-session',
      title: 'Planning notes',
      lastMessagePreview: 'Summarize the rollout checklist.',
      providerId: 'demo-openai',
      modelId: 'gpt-4o-mini',
      createdAt: DateTime(2026, 1, 1, 9),
      updatedAt: DateTime(2026, 1, 1, 9, 30),
      isDeleted: false,
      schemaVersion: 1,
    ),
  ];

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  late bool _hasProvider;

  @override
  void initState() {
    super.initState();
    _hasProvider = widget.initialHasProvider;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.hub_outlined),
                  label: Text('Setup'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.forum_outlined),
                  label: Text('Demo sessions'),
                ),
              ],
              selected: {_hasProvider},
              onSelectionChanged: (selection) {
                setState(() => _hasProvider = selection.single);
              },
            ),
          ),
          Expanded(
            child: _hasProvider
                ? ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: SessionListScreen._sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final session = SessionListScreen._sessions[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(session.title),
                          subtitle: Text(session.lastMessagePreview),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.go(AppRoutes.chatPath(session.id)),
                        ),
                      );
                    },
                  )
                : _EmptyProviderState(
                    message: l10n.providerRequired,
                    onOpenSettings: () => context.go(AppRoutes.settings),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.chatPath('new')),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.newChat),
      ),
    );
  }
}

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
