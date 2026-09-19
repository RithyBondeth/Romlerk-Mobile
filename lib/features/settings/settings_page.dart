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
import '../../services/security/device_authenticator.dart';
import '../../l10n/l10n.dart';

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

  /// Both directions ask the owner to prove who they are, so someone handed
  /// an unlocked phone cannot switch the lock off either.
  static Future<void> _setAppLock(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final authenticator = ref.read(deviceAuthenticatorProvider);
    if (enabled && !await authenticator.isAvailable()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.lockNeedsPasscode)));
      return;
    }
    final result = await authenticator.authenticate(
      enabled ? l10n.lockConfirmOn : l10n.lockConfirmOff,
    );
    if (result != UnlockResult.unlocked) return;
    final store = ref.read(settingsStoreProvider);
    final current = await store.read();
    await store.write(current.copyWith(appLockEnabled: enabled));
    // A locked app should not show task titles on the home screen either.
    ref.read(widgetSyncServiceProvider).hideTitles =
        enabled || current.redactNotificationPreviews;
    await ref.read(taskServiceProvider).refreshWidgets();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull ??
        const AppSettings();
    final capabilities = ref.watch(capabilitiesProvider);
    final store = ref.watch(settingsStoreProvider);
    final backup = ref.watch(backupStateProvider).valueOrNull;
    final semantics = context.semantics;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Insets.xxl),
        children: <Widget>[
          _SectionLabel(l10n.sectionAppearance),

          _Panel(
            child: _ThemeChoice(
              value: settings.themePreference,
              onChanged: (value) =>
                  store.write(settings.copyWith(themePreference: value)),
            ),
          ),

          _SectionLabel(l10n.sectionPrivacy),

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
                          l10n.privacyHeadline,
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
                    l10n.privacyBody,
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
                  title: Text(l10n.diagnosticsTitle),
                  subtitle: Text(l10n.diagnosticsBody),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                ),
                Divider(color: semantics.hairline, height: 1),
                SwitchListTile(
                  value: backup?.enabled ?? true,
                  onChanged: backup == null
                      ? null
                      : (value) async {
                          await ref
                              .read(databaseStorageProvider)
                              .setBackupEnabled(value);
                          ref.invalidate(backupStateProvider);
                        },
                  title: Text(l10n.backupTitle),
                  subtitle: Text(
                    backup?.pending == true
                        ? l10n.backupPending
                        : Platform.isIOS
                        ? l10n.backupBodyIos
                        : l10n.backupBodyAndroid,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                ),
                Divider(color: semantics.hairline, height: 1),
                SwitchListTile(
                  value: settings.redactNotificationPreviews,
                  onChanged: (value) async {
                    await store.write(
                      settings.copyWith(redactNotificationPreviews: value),
                    );
                    // Set directly rather than waiting for the settings
                    // stream, so the reschedule below uses the new value.
                    ref.read(reminderSchedulerProvider).redactPreviews = value;
                    ref.read(widgetSyncServiceProvider).hideTitles =
                        value || settings.appLockEnabled;
                    final tasks = ref.read(taskServiceProvider);
                    await tasks.reconcileReminders(force: true);
                    await tasks.refreshWidgets();
                  },
                  title: Text(l10n.redactTitle),
                  subtitle: Text(l10n.redactBody),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                ),
                Divider(color: semantics.hairline, height: 1),
                SwitchListTile(
                  value: settings.appLockEnabled,
                  onChanged: (value) => _setAppLock(context, ref, value),
                  title: Text(l10n.appLockTitle),
                  subtitle: Text(l10n.appLockBody),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                ),
              ],
            ),
          ),

          _SectionLabel(l10n.sectionDevice),

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
                      l10n.capabilityTier(value.tier.code, value.provider.label) +
                          (value.baseModel == null
                              ? ''
                              : ' · ${value.baseModel}'),
                      style: context.texts.bodySmall?.copyWith(
                        color: semantics.muted,
                      ),
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(
                  l10n.capabilityCheckFailed,
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
              title: Text(l10n.introAgain),
              subtitle: Text(l10n.introAgainBody),
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

          _SectionLabel(l10n.sectionCapture),

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
                  title: Text(l10n.defaultTime),
                  subtitle: Text(l10n.defaultTimeBody),
                  trailing: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay(
                        hour: settings.defaultReminderHour,
                        minute: settings.defaultReminderMinute,
                      ),
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
                  title: Text(l10n.alwaysReview),
                  subtitle: Text(l10n.alwaysReviewBody),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.xs,
                  ),
                ),
              ],
            ),
          ),

          _SectionLabel(l10n.sectionData),

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
                  title: Text(l10n.exportJson),
                  subtitle: Text(l10n.exportJsonBody),
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
                  title: Text(l10n.exportCsv),
                  subtitle: Text(l10n.exportCsvBody),
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
                l10n.eraseAllData,
                style: context.texts.bodyLarge?.copyWith(
                  color: semantics.overdue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(l10n.eraseAllBody),
              onTap: () => _confirmErase(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  /// Writes the export to a temporary file and hands it to the system share
  /// sheet, so the user picks the destination rather than the app.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ExportFormat format,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final exporter = ref.read(taskExporterProvider);
    final now = ref.read(clockProvider)();

    final tasks = await ref.read(taskRepositoryProvider).fetchTasks(
      const TaskQuery(
        statuses: <TaskStatus>{TaskStatus.active, TaskStatus.completed},
      ),
    );

    if (tasks.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportNothing)),
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
          subject: l10n.exportSubject,
        ),
      );
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportFailed)),
      );
    }
  }

  Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final count = await ref.read(taskRepositoryProvider).countTasks();
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.eraseQuestion),
        content: Text(
          context.l10n.eraseBody(context.l10n.taskCount(count)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.semantics.overdue,
            ),
            child: Text(context.l10n.erase),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    // Notifications go first: a reminder must never survive its task.
    await ref.read(reminderSchedulerProvider).cancelAll();
    await ref.read(taskRepositoryProvider).eraseAllData();

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.eraseDone)),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <ThemePreference, (IconData, String)>{
      ThemePreference.system: (LucideIcons.smartphone, l10n.themeSystem),
      ThemePreference.light: (LucideIcons.sun, l10n.themeLight),
      ThemePreference.dark: (LucideIcons.moon, l10n.themeDark),
    };
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          for (final entry in options.entries) ...<Widget>[
            if (entry.key != options.keys.first)
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
