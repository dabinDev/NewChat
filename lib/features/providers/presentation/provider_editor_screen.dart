import 'package:flutter/material.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/security/secret_masker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ProviderEditorScreen extends StatefulWidget {
  const ProviderEditorScreen({super.key});

  @override
  State<ProviderEditorScreen> createState() => _ProviderEditorScreenState();
}

class _ProviderEditorScreenState extends State<ProviderEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  ProviderProtocol _protocol = ProviderProtocol.openai;
  String _defaultModel = 'gpt-4o-mini';
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Work gateway');
    _baseUrlController = TextEditingController(
      text: 'https://api.openai.com/v1',
    );
    _apiKeyController = TextEditingController(
      text: maskSecret('sk-demo12345678'),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final modelOptions = _protocol == ProviderProtocol.openai
        ? const ['gpt-4o-mini', 'gpt-4o']
        : const ['claude-3-5-sonnet-latest', 'claude-3-5-haiku-latest'];
    if (!modelOptions.contains(_defaultModel)) {
      _defaultModel = modelOptions.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Provider name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ProviderProtocol>(
            segments: const [
              ButtonSegment(
                value: ProviderProtocol.openai,
                label: Text('OpenAI'),
              ),
              ButtonSegment(
                value: ProviderProtocol.claude,
                label: Text('Claude'),
              ),
            ],
            selected: {_protocol},
            onSelectionChanged: (selection) {
              setState(() => _protocol = selection.single);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureKey ? 'Show API key' : 'Hide API key',
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _defaultModel,
            decoration: const InputDecoration(
              labelText: 'Default model',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final model in modelOptions)
                DropdownMenuItem(value: model, child: Text(model)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _defaultModel = value);
              }
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.connectionSucceeded)),
              );
            },
            icon: const Icon(Icons.network_check_outlined),
            label: Text(l10n.testConnection),
          ),
        ],
      ),
    );
  }
}
