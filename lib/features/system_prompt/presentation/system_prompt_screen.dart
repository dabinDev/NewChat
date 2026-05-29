import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SystemPromptScreen extends StatelessWidget {
  const SystemPromptScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System prompt'),
      ),
      body: Center(
        child: Text(l10n.stop),
      ),
    );
  }
}
