
import 'app_database.dart';

/// User-controlled preferences, all local.
class AppSettings {
  const AppSettings({
    this.defaultReminderHour = 9,
    this.defaultReminderMinute = 0,
    this.diagnosticsConsent = false,
    this.redactNotificationPreviews = false,
    this.confirmBeforeSaving = true,
    this.onboardingComplete = false,
  });

  /// Time of day used when a captured task has a date but no time.
  final int defaultReminderHour;
  final int defaultReminderMinute;

  /// Opt-in, content-free diagnostics (FR-27). Off until explicitly enabled.
  final bool diagnosticsConsent;

  /// Show a generic notification body so task text does not appear on a lock
  /// screen.
  final bool redactNotificationPreviews;

  /// When false, unambiguous drafts save straight from capture — the "explicit
  /// quick-add mode" exception in FR-04.
  final bool confirmBeforeSaving;

  final bool onboardingComplete;

  AppSettings copyWith({
    int? defaultReminderHour,
    int? defaultReminderMinute,
    bool? diagnosticsConsent,
    bool? redactNotificationPreviews,
    bool? confirmBeforeSaving,
    bool? onboardingComplete,
  }) {
    return AppSettings(
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute:
          defaultReminderMinute ?? this.defaultReminderMinute,
      diagnosticsConsent: diagnosticsConsent ?? this.diagnosticsConsent,
      redactNotificationPreviews:
          redactNotificationPreviews ?? this.redactNotificationPreviews,
      confirmBeforeSaving: confirmBeforeSaving ?? this.confirmBeforeSaving,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}

/// Reads and writes [AppSettings] through the app database.
class SettingsStore {
  SettingsStore(this._db);

  final AppDatabase _db;

  static const String _reminderHour = 'default_reminder_hour';
  static const String _reminderMinute = 'default_reminder_minute';
  static const String _diagnostics = 'diagnostics_consent';
  static const String _redact = 'redact_notification_previews';
  static const String _confirm = 'confirm_before_saving';
  static const String _onboarding = 'onboarding_complete';

  Stream<AppSettings> watch() =>
      _db.select(_db.settingRows).watch().map(_fromRows);

  Future<AppSettings> read() async {
    final rows = await _db.select(_db.settingRows).get();
    return _fromRows(rows);
  }

  Future<void> write(AppSettings settings) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.settingRows, <SettingRowsCompanion>[
        _entry(_reminderHour, settings.defaultReminderHour.toString()),
        _entry(_reminderMinute, settings.defaultReminderMinute.toString()),
        _entry(_diagnostics, settings.diagnosticsConsent.toString()),
        _entry(_redact, settings.redactNotificationPreviews.toString()),
        _entry(_confirm, settings.confirmBeforeSaving.toString()),
        _entry(_onboarding, settings.onboardingComplete.toString()),
      ]);
    });
  }

  static SettingRowsCompanion _entry(String key, String value) =>
      SettingRowsCompanion.insert(key: key, value: value);

  static AppSettings _fromRows(List<SettingRow> rows) {
    final map = <String, String>{for (final row in rows) row.key: row.value};
    const defaults = AppSettings();
    return AppSettings(
      defaultReminderHour:
          int.tryParse(map[_reminderHour] ?? '') ??
          defaults.defaultReminderHour,
      defaultReminderMinute:
          int.tryParse(map[_reminderMinute] ?? '') ??
          defaults.defaultReminderMinute,
      diagnosticsConsent: map[_diagnostics] == 'true',
      redactNotificationPreviews: map[_redact] == 'true',
      confirmBeforeSaving: map[_confirm] != 'false',
      onboardingComplete: map[_onboarding] == 'true',
    );
  }
}
