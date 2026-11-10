import 'package:flutter/material.dart';
import '../../application/undo/task_undo_service.dart';
import '../../l10n/l10n.dart';

void showUndo(BuildContext context, UndoAction action, String message) {
  showUndoWithMessenger(
    ScaffoldMessenger.of(context),
    context.l10n,
    action,
    message,
  );
}

void showUndoWithMessenger(
  ScaffoldMessengerState messenger,
  AppLocalizations l,
  UndoAction action,
  String message,
) {
  if (!messenger.mounted) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () async {
          try {
            await action.undo();
            messenger.showSnackBar(SnackBar(content: Text(l.undoRestored)));
          } on Object {
            messenger.showSnackBar(SnackBar(content: Text(l.undoFailed)));
          }
        },
      ),
    ),
  );
}
