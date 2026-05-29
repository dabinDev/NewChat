import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final models = ref.watch(modelListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
      ),
      body: models.when(
        data: _buildModelList,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Unable to load models: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showModelSheet(
            const _EditableModel(
              id: 'custom-model',
              name: 'Custom model',
              protocol: ProviderProtocol.openai,
              supportsStreaming: true,
              supportsImages: false,
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add model'),
      ),
    );
  }

  Widget _buildModelList(List<ModelConfig> models) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: models.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final model = models[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: Text(
              model.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              model.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: model.supportsImages,
                    onChanged: (value) {
                      _saveModel(
                        _EditableModel.fromModel(
                          model,
                        ).copyWith(supportsImages: value ?? false),
                      );
                    },
                  ),
                  PopupMenuButton<_ModelAction>(
                    tooltip: 'Model actions',
                    onSelected: (action) {
                      switch (action) {
                        case _ModelAction.edit:
                          _showModelSheet(_EditableModel.fromModel(model));
                        case _ModelAction.delete:
                          _deleteModel(model.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _ModelAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                      if (!isSeedModel(model.id))
                        const PopupMenuItem(
                          value: _ModelAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showModelSheet(_EditableModel model) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ModelEditorSheet(
        model: model,
        onSave: _saveModel,
      ),
    );
  }

  Future<void> _saveModel(_EditableModel model) async {
    if (model.id.isEmpty || model.name.isEmpty) {
      return;
    }
    await ref.read(providerControllerProvider).saveModel(model.toModelConfig());
    ref.invalidate(modelListProvider);
  }

  Future<void> _deleteModel(String modelId) async {
    await ref.read(providerControllerProvider).deleteModel(modelId);
    ref.invalidate(modelListProvider);
  }
}

class _ModelEditorSheet extends StatefulWidget {
  const _ModelEditorSheet({
    required this.model,
    required this.onSave,
  });

  final _EditableModel model;
  final Future<void> Function(_EditableModel model) onSave;

  @override
  State<_ModelEditorSheet> createState() => _ModelEditorSheetState();
}

class _ModelEditorSheetState extends State<_ModelEditorSheet> {
  late _EditableModel _model;
  late final TextEditingController _nameController;
  late final TextEditingController _idController;

  @override
  void initState() {
    super.initState();
    _model = widget.model;
    _nameController = TextEditingController(text: _model.name);
    _idController = TextEditingController(text: _model.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idController,
            decoration: const InputDecoration(
              labelText: 'Model ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
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
            selected: {_model.protocol},
            onSelectionChanged: (selection) {
              setState(
                () => _model = _model.copyWith(protocol: selection.single),
              );
            },
          ),
          CheckboxListTile(
            value: _model.supportsImages,
            onChanged: (value) {
              setState(
                () => _model = _model.copyWith(
                  supportsImages: value ?? false,
                ),
              );
            },
            title: const Text('Supports images'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.onSave(
                _model.copyWith(
                  id: _idController.text.trim(),
                  name: _nameController.text.trim(),
                ),
              );
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _EditableModel {
  const _EditableModel({
    required this.id,
    required this.name,
    required this.protocol,
    required this.supportsStreaming,
    required this.supportsImages,
    this.contextLength,
  });

  factory _EditableModel.fromModel(ModelConfig model) => _EditableModel(
        id: model.id,
        name: model.displayName,
        protocol: model.protocol,
        supportsStreaming: model.supportsStreaming,
        supportsImages: model.supportsImages,
        contextLength: model.contextLength,
      );

  final String id;
  final String name;
  final ProviderProtocol protocol;
  final bool supportsStreaming;
  final bool supportsImages;
  final int? contextLength;

  _EditableModel copyWith({
    String? id,
    String? name,
    ProviderProtocol? protocol,
    bool? supportsStreaming,
    bool? supportsImages,
    int? contextLength,
  }) {
    return _EditableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      supportsImages: supportsImages ?? this.supportsImages,
      contextLength: contextLength ?? this.contextLength,
    );
  }

  ModelConfig toModelConfig() => ModelConfig(
        id: id,
        displayName: name,
        protocol: protocol,
        supportsStreaming: supportsStreaming,
        supportsImages: supportsImages,
        contextLength: contextLength,
      );
}

enum _ModelAction { edit, delete }
