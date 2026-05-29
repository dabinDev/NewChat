import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ProviderEditorScreen extends ConsumerStatefulWidget {
  const ProviderEditorScreen({super.key});

  @override
  ConsumerState<ProviderEditorScreen> createState() =>
      _ProviderEditorScreenState();
}

class _ProviderEditorScreenState extends ConsumerState<ProviderEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  final Uuid _uuid = const Uuid();
  ProviderProtocol _protocol = ProviderProtocol.openai;
  late String _defaultModel;
  bool _obscureKey = true;
  bool _clearApiKey = false;
  String? _providerId;
  bool _isSaving = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Work gateway');
    _baseUrlController = TextEditingController(
      text: 'https://api.openai.com/v1',
    );
    _apiKeyController = TextEditingController();
    _defaultModel = _modelOptionsFor(_protocol).first;
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
    final modelOptions = _modelOptionsFor(_protocol);

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
              setState(() => _setProtocol(selection.single));
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
          CheckboxListTile(
            value: _clearApiKey,
            onChanged: (value) {
              setState(() => _clearApiKey = value ?? false);
            },
            title: const Text('Clear saved API key'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveProvider,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isTesting ? null : _testConnection,
            icon: const Icon(Icons.network_check_outlined),
            label: Text(l10n.testConnection),
          ),
        ],
      ),
    );
  }

  void _setProtocol(ProviderProtocol protocol) {
    _protocol = protocol;
    final modelOptions = _modelOptionsFor(protocol);
    if (!modelOptions.contains(_defaultModel)) {
      _defaultModel = modelOptions.first;
    }
  }

  Future<void> _saveProvider() async {
    final provider = _providerFromFields();
    setState(() => _isSaving = true);
    try {
      await ref.read(providerControllerProvider).saveProvider(
            provider,
            apiKeyInput: _apiKeyController.text,
            clearApiKey: _clearApiKey,
          );
      ref.invalidate(providerListProvider);
      if (mounted) {
        setState(() {
          _providerId = provider.id;
          _clearApiKey = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Provider saved.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    final provider = _providerFromFields();
    setState(() => _isTesting = true);
    try {
      await ref.read(providerControllerProvider).saveProvider(
            provider,
            apiKeyInput: _apiKeyController.text,
            clearApiKey: _clearApiKey,
          );
      ref.invalidate(modelListProvider);
      final result = await ref.read(providerControllerProvider).testConnection(
            providerId: provider.id,
            modelId: provider.defaultModelId,
            apiKeyInput: _apiKeyController.text,
          );
      ref.invalidate(providerListProvider);
      if (mounted) {
        setState(() => _providerId = provider.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  ProviderConfig _providerFromFields() {
    final now = DateTime.now().toUtc();
    return ProviderConfig(
      id: _providerId ?? _uuid.v4(),
      name: _nameController.text.trim().isEmpty
          ? 'Provider'
          : _nameController.text.trim(),
      protocol: _protocol,
      baseUrl: _baseUrlController.text.trim(),
      defaultModelId: _defaultModel,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<String> _modelOptionsFor(ProviderProtocol protocol) {
    return protocol == ProviderProtocol.openai
        ? const ['gpt-4o-mini', 'gpt-4o']
        : const ['claude-3-5-sonnet-latest', 'claude-3-5-haiku-latest'];
  }
}
