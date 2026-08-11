import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/capability_notice.dart';
import '../../core/widgets/group_card.dart';
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
          const _SectionLabel('Appearance'),

          _Panel(
            child: _ThemeChoice(
              value: settings.themePreference,
              onChanged: (value) =>
                  store.write(settings.copyWith(themePreference: value)),
            ),
          ),

          const _SectionLabel('Privacy'),

          // The one panel that leads with reassurance rather than a control:
          // this is the claim the whole product rests on, so it is stated in
          // full before anything can be toggled.
          _Panel(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: semantics.completedSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.shieldCheck,
                          size: 17,
                          color: semantics.completed,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          'Your tasks stay on this device',
                          style: context.texts.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
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

          const SizedBox(height: Insets.md),

          _Panel(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: settings.diagnosticsConsent,
                  onChanged: (value) =>
                      store.write(settings.copyWith(diagnosticsConsent: value)),
                  title: const Text('Share anonymous diagnostics'),
                  subtitle: const Text(
                    'Error codes and timings only. Never task text, titles, '
                    'notes, or tags. Can be turned off at any time.',
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                ),
                Divider(color: semantics.hairline, height: 1),
                SwitchListTile(
                  value: settings.redactNotificationPreviews,
                  onChanged: (value) => store.write(
                    settings.copyWith(redactNotificationPreviews: value),
                  ),
                  title: const Text('Hide task text in notifications'),
                  subtitle: const Text(
                    'Shows a generic reminder instead of the task title on the '
                    'lock screen.',
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                ),
              ],
            ),
          ),

          const _SectionLabel('On this device'),

          _Panel(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: capabilities.when(
                data: (value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CapabilityNotice(
                      capabilities: value,
                      onRetry: () => ref.invalidate(capabilitiesProvider),
                      flat: true,
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Capability tier ${value.tier.code} · '
                      '${value.provider.label}'
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
          ),

          const SizedBox(height: Insets.md),

          _Panel(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.xs,
              ),
              leading: _SettingIcon(
                icon: LucideIcons.sparkles,
                color: semantics.muted,
              ),
              title: const Text('Show the intro again'),
              subtitle: const Text('Replays the three welcome screens.'),
              // Popping to the root reveals the intro immediately, because the
              // app's home is chosen from this flag. Asking someone to relaunch
              // to see the thing they just tapped would be a poor trade.
              onTap: () async {
                await store.write(
                  settings.copyWith(onboardingComplete: false),
                );
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ),

          const _SectionLabel('Capture'),

          _Panel(
            child: Column(
              children: <Widget>[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                  leading: _SettingIcon(
                    icon: LucideIcons.clock,
                    color: semantics.muted,
                  ),
                  title: const Text('Default time'),
                  subtitle: const Text(
                    'Used when a task has a date but no time of day.',
                  ),
                  trailing: Text(
                    _formatHour(
                      settings.defaultReminderHour,
                      settings.defaultReminderMinute,
                    ),
                    style: context.texts.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                Divider(color: semantics.hairline, height: 1),
                SwitchListTile(
                  value: settings.confirmBeforeSaving,
                  onChanged: (value) => store.write(
                    settings.copyWith(confirmBeforeSaving: value),
                  ),
                  title: const Text('Always review before saving'),
                  subtitle: const Text(
                    'Off lets unambiguous captures save in one step. Anything '
                    'the app is unsure about is still shown first.',
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                ),
              ],
            ),
          ),

          const _SectionLabel('Your data'),

          _Panel(
            child: Column(
              children: <Widget>[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                  leading: _SettingIcon(
                    icon: LucideIcons.fileJson,
                    color: semantics.muted,
                  ),
                  title: const Text('Export as JSON'),
                  subtitle: const Text(
                    'A complete, portable copy of every task.',
                  ),
                  onTap: () => _export(context, ref, ExportFormat.json),
                ),
                Divider(color: semantics.hairline, height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                  leading: _SettingIcon(
                    icon: LucideIcons.sheet,
                    color: semantics.muted,
                  ),
                  title: const Text('Export as CSV'),
                  subtitle: const Text('Opens in a spreadsheet.'),
                  onTap: () => _export(context, ref, ExportFormat.csv),
                ),
              ],
            ),
          ),

          const SizedBox(height: Insets.md),

          // Destructive action sits in its own panel, away from the exports it
          // would otherwise be one mis-tap from.
          _Panel(
            accent: semantics.overdue,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.xs,
              ),
              leading: _SettingIcon(
                icon: LucideIcons.trash2,
                color: semantics.overdue,
                background: semantics.overdueSoft,
              ),
              title: Text(
                'Erase all data',
                style: context.texts.bodyLarge?.copyWith(
                  color: semantics.overdue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Deletes every task, tag, and scheduled reminder from this '
                'device.',
              ),
              onTap: () => _confirmErase(context, ref),
            ),
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

/// Three-way theme picker.
///
/// A segmented row rather than a switch, because the choice is genuinely three
/// states: a plain "Dark mode" toggle would have no way to express "follow the
/// phone", which is both the default and what most people want.
class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.value, required this.onChanged});

  final ThemePreference value;
  final ValueChanged<ThemePreference> onChanged;

  static const Map<ThemePreference, (IconData, String)> _options =
      <ThemePreference, (IconData, String)>{
        ThemePreference.system: (LucideIcons.smartphone, 'System'),
        ThemePreference.light: (LucideIcons.sun, 'Light'),
        ThemePreference.dark: (LucideIcons.moon, 'Dark'),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          for (final entry in _options.entries) ...<Widget>[
            if (entry.key != _options.keys.first)
              const SizedBox(width: Insets.sm),
            Expanded(
              child: _ThemeOption(
                icon: entry.value.$1,
                label: entry.value.$2,
                selected: entry.key == value,
                onTap: () {
                  if (entry.key == value) return;
                  HapticFeedback.selectionClick();
                  onChanged(entry.key);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final accent = context.colors.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.card,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.easing,
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          decoration: BoxDecoration(
            color: selected ? semantics.accentSoft : semantics.sunken,
            borderRadius: Corners.card,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.45)
                  : semantics.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 19,
                color: selected ? accent : semantics.muted,
              ),
              const SizedBox(height: Insets.sm - 2),
              Text(
                label,
                style: context.texts.labelMedium?.copyWith(
                  color: selected ? accent : semantics.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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
        Insets.gutter + Insets.xs,
        Insets.xl,
        Insets.gutter + Insets.xs,
        Insets.sm + Insets.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: context.semantics.muted,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One group of related controls on its own sheet of paper. Clipped, because
/// the tiles inside ripple to their own edges.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: GroupCard(
        accent: accent,
        padding: EdgeInsets.zero,
        child: ClipRRect(borderRadius: Corners.card, child: child),
      ),
    );
  }
}

/// Settings icons get the same soft tile as the task detail rows, so a row of
/// controls reads as a list rather than a column of loose glyphs.
class _SettingIcon extends StatelessWidget {
  const _SettingIcon({
    required this.icon,
    required this.color,
    this.background,
  });

  final IconData icon;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: background ?? context.semantics.sunken,
        borderRadius: Corners.chip,
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}
