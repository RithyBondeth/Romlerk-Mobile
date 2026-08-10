import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/capability_notice.dart';
import '../../data/export/task_exporter.dart';
import '../../data/local/settings_store.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/task_repository.dart';

/// Privacy, capability, and data controls.
///
/// Ordered by what the BRD says users actually want to verify: what leaves the
/// device (nothing), what the device can do, and how to get their data out or
/// remove it entirely.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull ??
        const AppSettings();
    final capabilities = ref.watch(capabilitiesProvider);
    final store = ref.watch(settingsStoreProvider);
    final semantics = context.semantics;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Insets.xxl),
        children: <Widget>[
          const _SectionLabel('Privacy'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: semantics.sunken,
                borderRadius: Corners.card,
                border: Border.all(color: semantics.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        LucideIcons.shieldCheck,
                        size: 17,
                        color: semantics.completed,
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        'Your tasks stay on this device',
                        style: context.texts.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  // Wording is deliberately "processed on device" rather than
                  // "never uses the internet": the OS may still download model
                  // or configuration data, and the BRD forbids overclaiming.
                  Text(
                    'Task text, notes, and reminders are stored in a database '
                    'on this phone and processed on device. There is no '
                    'account, no server, and no cloud AI.',
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          SwitchListTile(
            value: settings.diagnosticsConsent,
            onChanged: (value) =>
                store.write(settings.copyWith(diagnosticsConsent: value)),
            title: const Text('Share anonymous diagnostics'),
            subtitle: const Text(
              'Error codes and timings only. Never task text, titles, notes, '
              'or tags. Can be turned off at any time.',
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          ),

          SwitchListTile(
            value: settings.redactNotificationPreviews,
            onChanged: (value) => store.write(
              settings.copyWith(redactNotificationPreviews: value),
            ),
            title: const Text('Hide task text in notifications'),
            subtitle: const Text(
              'Shows a generic reminder instead of the task title on the lock '
              'screen.',
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          ),

          const _SectionLabel('On this device'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: capabilities.when(
              data: (value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CapabilityNotice(
                    capabilities: value,
                    onRetry: () => ref.invalidate(capabilitiesProvider),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Capability tier ${value.tier.code} · ${value.provider.label}'
                    '${value.baseModel == null ? '' : ' · ${value.baseModel}'}',
                    style: context.texts.bodySmall?.copyWith(
                      color: semantics.muted,
                    ),
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Capability could not be checked. Date parsing still works.',
                style: context.texts.bodySmall,
              ),
            ),
          ),

          const _SectionLabel('Capture'),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            leading: const Icon(LucideIcons.clock),
            title: const Text('Default time'),
            subtitle: const Text(
              'Used when a task has a date but no time of day.',
            ),
            trailing: Text(
              _formatHour(
                settings.defaultReminderHour,
                settings.defaultReminderMinute,
              ),
              style: context.texts.bodyMedium,
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: settings.defaultReminderHour,
                  minute: settings.defaultReminderMinute,
                ),
              );
              if (picked == null) return;
              await store.write(
                settings.copyWith(
                  defaultReminderHour: picked.hour,
                  defaultReminderMinute: picked.minute,
                ),
              );
            },
          ),

          SwitchListTile(
            value: settings.confirmBeforeSaving,
            onChanged: (value) =>
                store.write(settings.copyWith(confirmBeforeSaving: value)),
            title: const Text('Always review before saving'),
            subtitle: const Text(
              'Off lets unambiguous captures save in one step. Anything the '
              'app is unsure about is still shown first.',
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          ),

          const _SectionLabel('Your data'),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            leading: const Icon(LucideIcons.fileJson),
            title: const Text('Export as JSON'),
            subtitle: const Text('A complete, portable copy of every task.'),
            onTap: () => _export(context, ref, ExportFormat.json),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            leading: const Icon(LucideIcons.sheet),
            title: const Text('Export as CSV'),
            subtitle: const Text('Opens in a spreadsheet.'),
            onTap: () => _export(context, ref, ExportFormat.csv),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            leading: Icon(LucideIcons.trash2, color: semantics.overdue),
            title: Text(
              'Erase all data',
              style: TextStyle(color: semantics.overdue),
            ),
            subtitle: const Text(
              'Deletes every task, tag, and scheduled reminder from this '
              'device.',
            ),
            onTap: () => _confirmErase(context, ref),
          ),
        ],
      ),
    );
  }

  static String _formatHour(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Writes the export to a temporary file and hands it to the system share
  /// sheet, so the user picks the destination rather than the app.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ExportFormat format,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final exporter = ref.read(taskExporterProvider);
    final now = ref.read(clockProvider)();

    final tasks = await ref.read(taskRepositoryProvider).fetchTasks(
      const TaskQuery(
        statuses: <TaskStatus>{TaskStatus.active, TaskStatus.completed},
      ),
    );

    if (tasks.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('There is nothing to export yet.')),
      );
      return;
    }

    try {
      final body = format == ExportFormat.json
          ? exporter.buildJson(tasks, exportedAt: now)
          : exporter.buildCsv(tasks);
      final directory = await getTemporaryDirectory();
      final file = File(
        p.join(directory.path, exporter.buildFileName(format, now)),
      );
      await file.writeAsString(body);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: format.mimeType)],
          subject: 'Romlerk tasks',
        ),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The export could not be created. Nothing changed.'),
        ),
      );
    }
  }

  Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final count = await ref.read(taskRepositoryProvider).countTasks();
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase everything?'),
        content: Text(
          'This permanently deletes $count '
          '${count == 1 ? 'task' : 'tasks'}, all tags, and every scheduled '
          'reminder from this device. It cannot be undone, and there is no '
          'cloud copy to restore from.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.semantics.overdue,
            ),
            child: const Text('Erase'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // Notifications go first: a reminder must never survive its task.
    await ref.read(reminderSchedulerProvider).cancelAll();
    await ref.read(taskRepositoryProvider).eraseAllData();

    messenger.showSnackBar(
      const SnackBar(content: Text('All data erased from this device.')),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.xl,
        Insets.lg,
        Insets.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: context.semantics.muted,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
