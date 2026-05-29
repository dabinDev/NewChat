import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/routing/app_routes.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final providers = ref.watch(providerListProvider).valueOrNull ?? const [];
    final selectedLanguage = ref.watch(selectedLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Providers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final provider in providers)
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(provider.name),
              subtitle: Text(
                '${provider.protocol.name.toUpperCase()} / ${provider.defaultModelId}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.editProviderPath(provider.id)),
            ),
          ListTile(
            leading: const Icon(Icons.add_link_outlined),
            title: const Text('Add provider'),
            onTap: () => context.go(AppRoutes.newProvider),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('Models'),
            onTap: () => context.go(AppRoutes.models),
          ),
          const Divider(),
          RadioListTile<String>(
            value: 'system',
            groupValue: selectedLanguage,
            onChanged: _selectLanguage,
            title: const Text('System language'),
          ),
          RadioListTile<String>(
            value: 'zh',
            groupValue: selectedLanguage,
            onChanged: _selectLanguage,
            title: const Text('Chinese'),
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: selectedLanguage,
            onChanged: _selectLanguage,
            title: const Text('English'),
          ),
        ],
      ),
    );
  }

  void _selectLanguage(String? value) {
    if (value == null) {
      return;
    }
    ref.read(selectedLanguageProvider.notifier).state = value;
  }
}
