import '../planning/daily_plan_store.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../../application/task_service.dart';
import '../../domain/entities/tag.dart';
import '../../domain/enums.dart';
import '../../services/notifications/reminder_scheduler.dart';
import '../../services/widgets/widget_sync_service.dart';
import '../local/app_database.dart';
import '../local/database_storage.dart';
import '../local/settings_store.dart';

const _serializer = _BackupSerializer();

class _BackupSerializer extends ValueSerializer {
  const _BackupSerializer();
  static const _defaults = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );
  @override
  dynamic toJson<T>(T value) => value is DateTime
      ? value.toUtc().toIso8601String()
      : _defaults.toJson<T>(value);
  @override
  T fromJson<T>(dynamic json) => _defaults.fromJson<T>(json);
}

/// A versioned logical snapshot. Platform notification IDs are never portable.
class BackupArchive {
  BackupArchive._(this.data, this.backupEnabled, this.createdAt);
  final Map<String, dynamic> data;
  final bool backupEnabled;
  final DateTime createdAt;
  int get taskCount => (data['tasks'] as List).length;
  int get noteCount => (data['notes'] as List).length;

  static const maxBytes = 20 * 1024 * 1024;
  static BackupArchive decode(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Backup too large');
    }
    try {
      final root = jsonDecode(text) as Map<String, dynamic>;
      if (root['application'] != 'Romlerk' ||
          root['format'] != 'full-backup' ||
          (root['version'] != 1 && root['version'] != 2) ||
          root['databaseVersion'] != 2 ||
          root['backupEnabled'] is! bool) {
        throw const FormatException('Unsupported backup');
      }
      final data = root['data'] as Map<String, dynamic>;
      const tables = {
        'tasks',
        'notes',
        'tags',
        'task_tags',
        'reminders',
        'recurrence_rules',
        'settings',
        'ai_parse_audit',
      };
      if (data.keys.toSet().difference(tables).isNotEmpty ||
          tables.difference(data.keys.toSet()).isNotEmpty) {
        throw const FormatException('Incomplete backup');
      }
      for (final key in tables) {
        final rows = data[key] as List;
        if (rows.length > 100000 ||
            rows.any((r) => r is! Map<String, dynamic>)) {
          throw const FormatException('Invalid rows');
        }
      }
      return BackupArchive._(
        data,
        root['backupEnabled'] as bool,
        DateTime.parse(root['createdAt'] as String),
      );
    } on Object {
      throw const FormatException('Invalid or unsupported Romlerk backup');
    }
  }

  List<T> _rows<T>(String name, T Function(Map<String, dynamic>) decode) =>
      (data[name] as List)
          .map((r) => decode(r as Map<String, dynamic>))
          .toList();

  /// Validates every record and relation in a disposable database before any
  /// notification or existing data is changed.
  Future<void> validate() async {
    final scratch = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await writeTo(scratch, now: DateTime.now());
    } on Object {
      throw const FormatException('Invalid backup records or relationships');
    } finally {
      await scratch.close();
    }
  }

  Future<void> writeTo(AppDatabase db, {required DateTime now}) async {
    final tasks = _rows(
      'tasks',
      (j) => TaskRow.fromJson(j, serializer: _serializer),
    );
    final notes = _rows(
      'notes',
      (j) => NoteRow.fromJson(j, serializer: _serializer),
    );
    final tags = _rows(
      'tags',
      (j) => TagRow.fromJson(j, serializer: _serializer),
    );
    final reminders = _rows(
      'reminders',
      (j) => ReminderRow.fromJson(j, serializer: _serializer),
    );
    final recurrence = _rows(
      'recurrence_rules',
      (j) => RecurrenceRow.fromJson(j, serializer: _serializer),
    );
    final links = _rows(
      'task_tags',
      (j) => TaskTagRow.fromJson(j, serializer: _serializer),
    );
    final settings = _rows(
      'settings',
      (j) => SettingRow.fromJson(j, serializer: _serializer),
    );
    final audits = _rows(
      'ai_parse_audit',
      (j) => ParseAuditRow.fromJson(j, serializer: _serializer),
    );
    final byId = {for (final task in tasks) task.id: task};
    for (final task in tasks) {
      if (task.id.isEmpty ||
          task.title.trim().isEmpty ||
          task.title.length > 500 ||
          !TaskStatus.values.any((s) => s.wire == task.status) ||
          !TaskPriority.values.any((p) => p.wire == task.priority) ||
          task.occurrenceIndex < 0 ||
          (task.durationMinutes != null &&
              (task.durationMinutes! < 1 || task.durationMinutes! > 10080)) ||
          (task.startAt != null &&
              task.dueAt != null &&
              task.startAt!.isAfter(task.dueAt!))) {
        throw const FormatException('Invalid task');
      }
    }
    for (final note in notes) {
      if (note.id.isEmpty ||
          note.title.trim().isEmpty ||
          note.title.length > 500) {
        throw const FormatException('Invalid note');
      }
    }
    for (final tag in tags) {
      if (tag.id.isEmpty ||
          tag.name.trim().isEmpty ||
          tag.name.length > 60 ||
          tag.normalizedName != Tag.normalize(tag.name)) {
        throw const FormatException('Invalid tag');
      }
    }
    if (reminders.map((r) => r.taskId).toSet().length != reminders.length ||
        recurrence.map((r) => r.taskId).toSet().length != recurrence.length) {
      throw const FormatException('Duplicate task relations');
    }
    for (final r in reminders) {
      if (r.id.isEmpty ||
          !byId.containsKey(r.taskId) ||
          !ReminderState.values.any((s) => s.wire == r.state) ||
          r.timezone.isEmpty ||
          r.timezone.length > 64) {
        throw const FormatException('Invalid reminder');
      }
    }
    for (final r in recurrence) {
      final days = r.byWeekday.isEmpty
          ? <int>[]
          : r.byWeekday.split(',').map(int.parse).toList();
      final task = byId[r.taskId];
      if (task == null ||
          (task.dueAt == null && task.startAt == null) ||
          !RecurrenceFrequency.values.any((f) => f.wire == r.frequency) ||
          r.interval < 1 ||
          r.interval > 365 ||
          (r.count != null && (r.count! < 1 || r.count! > 100000)) ||
          days.any((d) => d < 1 || d > 7) ||
          (r.frequency != 'weekly' && days.isNotEmpty)) {
        throw const FormatException('Invalid recurrence');
      }
    }
    for (final setting in settings) {
      switch (setting.key) {
        case 'default_reminder_hour':
          final v = int.tryParse(setting.value);
          if (v == null || v < 0 || v > 23) {
            throw const FormatException('Invalid hour');
          }
        case 'default_reminder_minute':
          final v = int.tryParse(setting.value);
          if (v == null || v < 0 || v > 59) {
            throw const FormatException('Invalid minute');
          }
        case 'theme_preference':
          if (!ThemePreference.values.any((t) => t.name == setting.value)) {
            throw const FormatException('Invalid theme');
          }
        case 'diagnostics_consent' ||
            'redact_notification_previews' ||
            'confirm_before_saving' ||
            'onboarding_complete' ||
            'voice_privacy_acknowledged' ||
            'app_lock_enabled':
          if (setting.value != 'true' && setting.value != 'false') {
            throw const FormatException('Invalid preference');
          }
        default:
          if (!DailyPlanStore.valid(setting.key, setting.value)) {
            throw const FormatException('Unknown or invalid preference/plan');
          }
      }
    }
    await db.transaction(() async {
      // Children first, then parents. Replacement is atomic in SQLite.
      for (final table in <TableInfo<Table, dynamic>>[
        db.taskTagRows,
        db.reminderRows,
        db.recurrenceRows,
        db.tagRows,
        db.taskRows,
        db.noteRows,
        db.settingRows,
        db.parseAuditRows,
      ]) {
        await db.delete(table).go();
      }
      for (final row in tasks) {
        await db.into(db.taskRows).insert(row);
      }
      for (final row in notes) {
        await db.into(db.noteRows).insert(row);
      }
      for (final row in tags) {
        await db.into(db.tagRows).insert(row);
      }
      for (final row in links) {
        await db.into(db.taskTagRows).insert(row);
      }
      for (final row in recurrence) {
        await db.into(db.recurrenceRows).insert(row);
      }
      for (final row in reminders) {
        final task = byId[row.taskId]!;
        final original = ReminderState.fromWire(row.state);
        final state = task.status == 'completed'
            ? ReminderState.cancelled
            : (original.isActive || original.needsAttention) &&
                  row.scheduledAt.isAfter(now)
            ? ReminderState.pending
            : original == ReminderState.scheduled ||
                  original == ReminderState.pending
            ? ReminderState.delivered
            : original;
        await db
            .into(db.reminderRows)
            .insert(
              row.copyWith(
                state: state.wire,
                platformId: const Value(null),
                failureCode: const Value(null),
              ),
            );
      }
      for (final row in settings) {
        await db.into(db.settingRows).insert(row);
      }
      for (final row in audits) {
        await db.into(db.parseAuditRows).insert(row);
      }
    });
  }
}

class RestoreResult {
  const RestoreResult({
    required this.reminderWarnings,
    required this.privacyWarning,
  });
  final int reminderWarnings;
  final bool privacyWarning;
}

class BackupService {
  BackupService({
    required this.database,
    required this.scheduler,
    required this.tasks,
    required this.storage,
    required this.widgets,
  });
  final AppDatabase database;
  final ReminderScheduler scheduler;
  final TaskService tasks;
  final DatabaseStorage storage;
  final WidgetSyncService widgets;
  bool _restoring = false;

  Future<String> export() async {
    final backupEnabled = await storage.backupEnabled();
    final data = await database.transaction(() async {
      final result = <String, dynamic>{};
      for (final table in database.allTables) {
        final rows = await database.select(table).get();
        result[table.actualTableName] = rows.map((r) {
          final json = (r as DataClass).toJson(serializer: _serializer);
          if (table.actualTableName == 'reminders') {
            json['platformId'] = null;
            json['failureCode'] = null;
          }
          return json;
        }).toList();
      }
      return result;
    });
    final text = const JsonEncoder.withIndent('  ').convert({
      'application': 'Romlerk',
      'format': 'full-backup',
      'version': 2,
      'databaseVersion': database.schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'backupEnabled': backupEnabled,
      'data': data,
    });
    if (utf8.encode(text).length > BackupArchive.maxBytes) {
      throw const FormatException('Backup too large');
    }
    return text;
  }

  Future<RestoreResult> restore(BackupArchive archive) async {
    if (_restoring) throw StateError('Restore already running');
    _restoring = true;
    try {
      await archive.validate();
      tasks.invalidateUndo();
      await scheduler.cancelAll();
      await tasks.clearCaptureInbox();
      try {
        await archive.writeTo(database, now: DateTime.now());
      } on Object {
        await tasks.reconcileReminders(force: true);
        rethrow;
      }
      var privacyWarning = false;
      try {
        await storage.setBackupEnabled(archive.backupEnabled);
      } on Object {
        privacyWarning = true;
      }
      final settings = await SettingsStore(database).read();
      scheduler.redactPreviews = settings.redactNotificationPreviews;
      widgets.hideTitles =
          settings.redactNotificationPreviews || settings.appLockEnabled;
      var warnings = 0;
      try {
        await tasks.reconcileReminders(force: true);
      } on Object {
        warnings++;
      }
      final rows = await database.select(database.reminderRows).get();
      warnings += rows
          .where(
            (r) =>
                r.state == 'blocked' ||
                r.state == 'failed' ||
                r.state == 'pending',
          )
          .length;
      await tasks.refreshWidgets();
      return RestoreResult(
        reminderWarnings: warnings,
        privacyWarning: privacyWarning,
      );
    } finally {
      _restoring = false;
    }
  }
}
