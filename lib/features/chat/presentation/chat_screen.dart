import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newChat),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'System prompt',
            onPressed: () => context.go('/chat/$sessionId/system-prompt'),
          ),
        ],
      ),
      body: Center(
        child: Text(l10n.imageUnsupported),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.send_outlined),
            label: Text(l10n.send),
          ),
        ),
      ),
    );
  }
}
