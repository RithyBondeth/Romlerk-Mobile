import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../application/providers.dart';
import '../../data/backup/backup_service.dart';
import '../../l10n/l10n.dart';

class BackupControls extends ConsumerStatefulWidget {
  const BackupControls({super.key});
  @override
  ConsumerState<BackupControls> createState() => _BackupControlsState();
}

class _BackupControlsState extends ConsumerState<BackupControls> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final text = await service.export();
      final directory = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final file = File(p.join(directory.path, 'romlerk-backup-$stamp.json'));
      await file.writeAsString(text, flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: l.backupFullTitle,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.backupFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            mimeTypes: ['application/json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > BackupArchive.maxBytes) {
        throw const FormatException('Backup too large');
      }
      final archive = BackupArchive.decode(await file.readAsString());
      await archive.validate();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.backupRestoreTitle),
          content: Text(
            l.backupPreview(
              archive.taskCount,
              archive.noteCount,
              MaterialLocalizations.of(
                context,
              ).formatMediumDate(archive.createdAt.toLocal()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.backupRestoreTitle),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = await service.restore(archive);
      if (mounted) {
        ref.invalidate(backupStateProvider);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.privacyWarning
                ? l.backupPrivacyWarning
                : result.reminderWarnings > 0
                ? l.backupReminderWarning
                : l.backupRestored,
          ),
        ),
      );
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l.backupInvalid)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.backupRestoreFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.backup_outlined),
        title: Text(context.l10n.backupFullTitle),
        subtitle: Text(context.l10n.backupFullBody),
        enabled: !_busy,
        onTap: _export,
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.restore),
        title: Text(context.l10n.backupRestoreTitle),
        subtitle: Text(context.l10n.backupRestoreBody),
        enabled: !_busy,
        onTap: _restore,
      ),
      if (_busy) const LinearProgressIndicator(),
      const Divider(height: 1),
    ],
  );
}
