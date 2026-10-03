import 'package:flutter/material.dart';
import '../../application/editing/autosave_controller.dart';
import '../../l10n/l10n.dart';

class AutosaveStatus extends StatelessWidget {
  const AutosaveStatus({super.key, required this.controller});
  final AutosaveController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Expanded(
            child: Text(
              controller.error != null
                  ? context.l10n.autosaveFailed
                  : controller.saving || controller.dirty
                  ? context.l10n.autosaveSaving
                  : context.l10n.autosaveSaved,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (controller.error != null)
            TextButton(
              onPressed: controller.flush,
              child: Text(context.l10n.autosaveRetry),
            ),
        ],
      ),
    ),
  );
}
