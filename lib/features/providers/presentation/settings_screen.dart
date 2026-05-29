import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.add_link_outlined),
            title: Text(l10n.testConnection),
            onTap: () => context.go('/settings/provider/new'),
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('Models'),
            onTap: () => context.go('/settings/models'),
          ),
        ],
      ),
    );
  }
}
