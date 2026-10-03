import 'package:romlerk_mobile/data/planning/daily_plan_store.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/task_service.dart';
import 'package:romlerk_mobile/data/backup/backup_service.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/local/database_storage.dart';
import 'package:romlerk_mobile/data/local/settings_store.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/data/repositories/drift_note_repository.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/entities/reminder.dart';
import 'package:romlerk_mobile/domain/entities/recurrence_rule.dart';
import 'package:romlerk_mobile/domain/entities/note.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/services/notifications/reminder_scheduler.dart';
import 'package:romlerk_mobile/services/widgets/widget_sync_service.dart';

class Scheduler extends ReminderScheduler {
  bool cancelled = false;
  bool failCancel = false;
  bool denied = false;
  int schedules = 0;
  @override
  Future<void> cancelAll() async {
    if (failCancel) throw StateError('OS unavailable');
    cancelled = true;
  }

  @override
  Future<Set<int>> pendingPlatformIds() async => {};
  @override
  Future<ScheduleOutcome> schedule(
    Task t,
    Reminder r, {
    bool requestPermission = true,
  }) async {
    schedules++;
    return ScheduleOutcome(
      state: denied ? ReminderState.blocked : ReminderState.scheduled,
      platformId: denied ? null : 77,
    );
  }
}

class Widgets extends WidgetSyncService {
  int updates = 0;
  @override
  Future<bool> syncTodayView({
    required List<Task> overdueTasks,
    required List<Task> todayTasks,
    required DateTime now,
  }) async {
    updates++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase source, target;
  late Directory directory;
  late DatabaseStorage storage;
  late BackupService exporter, importer;
  late Scheduler scheduler;
  late Widgets widgets;
  final now = DateTime(2030, 1, 2, 9);
  setUp(() async {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('romlerk-backup');
    storage = DatabaseStorage(documents: () async => directory);
    scheduler = Scheduler();
    widgets = Widgets();
    BackupService service(AppDatabase db) => BackupService(
      database: db,
      scheduler: scheduler,
      tasks: TaskService(
        repository: DriftTaskRepository(db),
        scheduler: scheduler,
        widgetSyncService: widgets,
      ),
      storage: storage,
      widgets: widgets,
    );
    exporter = service(source);
    importer = service(target);
    final repo = DriftTaskRepository(source);
    final tag = await repo.ensureTag('work');
    await repo.createTask(
      Task(
        id: 'original',
        title: 'Call David',
        notes: 'Private text',
        status: TaskStatus.active,
        priority: TaskPriority.high,
        createdAt: now,
        updatedAt: now,
        dueAt: now,
        occurrenceIndex: 4,
        durationMinutes: 30,
        tags: [tag],
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          byWeekday: [1, 3],
          count: 12,
        ),
        reminder: Reminder(
          id: 'r',
          taskId: 'original',
          scheduledAt: now,
          timezone: 'Asia/Phnom_Penh',
          state: ReminderState.scheduled,
          platformId: 123,
        ),
      ),
    );
    await DriftNoteRepository(source).saveNote(
      Note(
        id: 'n',
        title: 'My note',
        content: 'ខ្មែរ\nPrivate',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await SettingsStore(source).write(
      const AppSettings(
        themePreference: ThemePreference.dark,
        redactNotificationPreviews: true,
        onboardingComplete: true,
      ),
    );
    await DriftTaskRepository(target).createTask(
      Task(
        id: 'current',
        title: 'Keep until confirmed',
        status: TaskStatus.active,
        priority: TaskPriority.none,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
  tearDown(() async {
    await source.close();
    await target.close();
    await directory.delete(recursive: true);
  });

  test('legacy version 1 backups still restore', () async {
    final root = jsonDecode(await exporter.export()) as Map<String, dynamic>;
    root['version'] = 1;
    await importer.restore(BackupArchive.decode(jsonEncode(root)));
    expect(
      (await DriftTaskRepository(target).findTask('original'))!.id,
      'original',
    );
    expect(
      (await DriftNoteRepository(target).getNoteById('n'))!.content,
      contains('ខ្មែរ'),
    );
  });

  test(
    'full round trip preserves notes, tags, recurrence progress and preferences',
    () async {
      final plannedTask = (await DriftTaskRepository(
        source,
      ).findTask('original'))!;
      await DailyPlanStore(source).save(DateTime(2030, 1, 1), [plannedTask]);
      await storage.setBackupEnabled(false);
      final text = await exporter.export();
      expect(text, contains('2030-'));
      expect(text, contains('Z'));
      final archive = BackupArchive.decode(text);
      expect(archive.taskCount, 1);
      expect(archive.noteCount, 1);
      await storage.setBackupEnabled(true);
      final result = await importer.restore(archive);
      expect(
        (await DailyPlanStore(target).read(DateTime(2030, 1, 1)))!.occurrences,
        {'original': 4},
      );
      final repo = DriftTaskRepository(target);
      expect(await repo.findTask('current'), isNull);
      final task = (await repo.findTask('original'))!;
      expect(task.occurrenceIndex, 4);
      expect(task.recurrence!.count, 12);
      expect(task.recurrence!.byWeekday, [1, 3]);
      expect(task.tags.single.name, 'work');
      expect(task.durationMinutes, 30);
      expect(task.reminder!.platformId, 77);
      expect(scheduler.schedules, 1);
      expect(scheduler.cancelled, isTrue);
      expect(
        (await DriftNoteRepository(target).getNoteById('n'))!.content,
        'ខ្មែរ\nPrivate',
      );
      expect(
        (await SettingsStore(target).read()).themePreference,
        ThemePreference.dark,
      );
      expect(await storage.backupEnabled(), isFalse);
      expect(widgets.hideTitles, isTrue);
      expect(result.reminderWarnings, 0);
      expect(widgets.updates, greaterThan(0));
    },
  );
  test(
    'malformed references leave existing data and notifications untouched',
    () async {
      final json = jsonDecode(await exporter.export()) as Map<String, dynamic>;
      json['data']['task_tags'][0]['tagId'] = 'missing';
      final archive = BackupArchive.decode(jsonEncode(json));
      await expectLater(importer.restore(archive), throwsFormatException);
      expect(await DriftTaskRepository(target).findTask('current'), isNotNull);
      expect(scheduler.cancelled, isFalse);
    },
  );
  test(
    'invalid enums and recurrence intervals are rejected before changes',
    () async {
      for (final invalid in ['status', 'interval']) {
        final json =
            jsonDecode(await exporter.export()) as Map<String, dynamic>;
        if (invalid == 'status') {
          json['data']['tasks'][0]['status'] = 'unknown';
        } else {
          json['data']['recurrence_rules'][0]['interval'] = 0;
        }
        await expectLater(
          importer.restore(BackupArchive.decode(jsonEncode(json))),
          throwsFormatException,
        );
      }
      expect(await DriftTaskRepository(target).findTask('current'), isNotNull);
    },
  );
  test('OS cancellation failure preserves current database', () async {
    scheduler.failCancel = true;
    await expectLater(
      importer.restore(BackupArchive.decode(await exporter.export())),
      throwsStateError,
    );
    expect(await DriftTaskRepository(target).findTask('current'), isNotNull);
  });
  test('denied permission restores data with a reminder warning', () async {
    scheduler.denied = true;
    final result = await importer.restore(
      BackupArchive.decode(await exporter.export()),
    );
    expect(result.reminderWarnings, 1);
    expect(await DriftTaskRepository(target).findTask('original'), isNotNull);
  });
  test('unknown versions and task-only exports are rejected', () async {
    final json = jsonDecode(await exporter.export()) as Map<String, dynamic>;
    json['version'] = 999;
    expect(() => BackupArchive.decode(jsonEncode(json)), throwsFormatException);
    expect(
      () => BackupArchive.decode(
        '{"application":"Romlerk","schemaVersion":1,"tasks":[]}',
      ),
      throwsFormatException,
    );
  });
  test(
    'failed insertion rolls replacement back as a single transaction',
    () async {
      final archive = BackupArchive.decode(await exporter.export());
      archive.data['task_tags'][0]['tagId'] = 'missing';
      await expectLater(
        archive.writeTo(target, now: DateTime.now()),
        throwsA(isA<Exception>()),
      );
      expect(await DriftTaskRepository(target).findTask('current'), isNotNull);
      expect(await DriftTaskRepository(target).findTask('original'), isNull);
    },
  );
}
