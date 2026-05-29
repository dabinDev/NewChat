import 'package:flutter/material.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final List<_EditableModel> _models = seedModelConfigs()
      .map(
        (model) => _EditableModel(
          id: model.id,
          name: model.displayName,
          supportsImages: model.supportsImages,
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _models.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final model = _models[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: Text(
                model.name,
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
                        setState(() => model.supportsImages = value ?? false);
                      },
                    ),
                    PopupMenuButton<_ModelAction>(
                      tooltip: 'Model actions',
                      onSelected: (action) {
                        switch (action) {
                          case _ModelAction.edit:
                            _showModelSheet(model);
                          case _ModelAction.delete:
                            setState(() => _models.removeAt(index));
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _ModelAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                          ),
                        ),
                        PopupMenuItem(
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final model = _EditableModel(
            id: 'custom-model',
            name: 'Custom model',
            supportsImages: false,
          );
          setState(() => _models.add(model));
          _showModelSheet(model);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add model'),
      ),
    );
  }

  Future<void> _showModelSheet(_EditableModel model) async {
    final nameController = TextEditingController(text: model.name);
    final idController = TextEditingController(text: model.id);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'Model ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    value: model.supportsImages,
                    onChanged: (value) {
                      setSheetState(
                        () => model.supportsImages = value ?? false,
                      );
                    },
                    title: const Text('Supports images'),
                  ),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        model.name = nameController.text.trim();
                        model.id = idController.text.trim();
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameController.dispose();
    idController.dispose();
  }
}

class _EditableModel {
  _EditableModel({
    required this.id,
    required this.name,
    required this.supportsImages,
  });

  String id;
  String name;
  bool supportsImages;
}

enum _ModelAction { edit, delete }
