import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/task_service.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/domain/entities/reminder.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/services/notifications/reminder_scheduler.dart';
import 'package:romlerk_mobile/services/widgets/widget_sync_service.dart';

/// Stands in for the OS notification scheduler so the outcome of every
/// scheduling attempt can be dictated by the test.
class _FakeScheduler extends ReminderScheduler {
  /// The result [schedule] should return. Defaults to success.
  ScheduleOutcome? outcome;

  final List<int> cancelled = <int>[];
  Set<int> pending = <int>{};
  int scheduleCalls = 0;
  bool? lastRequestPermission;
  bool cancelAllCalled = false;
  bool cancellationFails = false;

  @override
  String get localTimezone => 'Europe/Copenhagen';

  @override
  Future<void> initialize() async {}

  @override
  Future<ScheduleOutcome> schedule(
    Task task,
    Reminder reminder, {
    bool requestPermission = true,
  }) async {
    scheduleCalls++;
    lastRequestPermission = requestPermission;
    return outcome ??
        ScheduleOutcome(
          state: ReminderState.scheduled,
          platformId: reminder.id.hashCode & 0x7fffffff,
        );
  }

  @override
  Future<void> cancel(int? platformId) async {
    if (platformId != null) cancelled.add(platformId);
  }

  @override
  Future<void> cancelAll() async {
    if (cancellationFails) throw StateError("OS cancellation failed");
    cancelAllCalled = true;
  }

  @override
  Future<Set<int>> pendingPlatformIds() async => pending;
}

class _FakeWidgets extends WidgetSyncService {
  List<Task>? tasks;
  @override
  Future<bool> syncTodayView({
    required List<Task> overdueTasks,
    required List<Task> todayTasks,
    required DateTime now,
  }) async {
    tasks = [...overdueTasks, ...todayTasks];
    return true;
  }
}

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;
  late _FakeScheduler scheduler;
  late TaskService service;

  final now = DateTime(2026, 8, 10, 14, 30);
  final tomorrow9 = DateTime(2026, 8, 11, 9);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
    scheduler = _FakeScheduler();
    service = TaskService(repository: repository, scheduler: scheduler);
  });

  tearDown(() => database.close());

  TaskDraft draft({
    String title = 'Call David',
    DateTime? dueAt,
    DateTime? reminderAt,
    List<String> tags = const <String>[],
  }) {
    return TaskDraft(
      id: 'draft-1',
      title: title,
      dueAt: dueAt,
      reminderAt: reminderAt,
      tags: tags,
    );
  }

  group('committing a draft', () {
    test('persists the task and schedules its reminder', () async {
      final outcome = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );

      expect(outcome.hasWarning, isFalse);
      expect(outcome.task.title, 'Call David');
      expect(outcome.task.reminder!.state, ReminderState.scheduled);
      expect(scheduler.scheduleCalls, 1);
      expect(await repository.countTasks(), 1);
    });

    test('creates tags named in the draft', () async {
      await service.commitDraft(
        draft(tags: const <String>['work', 'calls']),
        now: now,
      );
      final tags = await repository.fetchTags();
      expect(
        tags.map((tag) => tag.name),
        containsAll(<String>['work', 'calls']),
      );
    });

    test('does not arm a reminder that is already in the past', () async {
      final outcome = await service.commitDraft(
        draft(
          dueAt: DateTime(2026, 8, 10, 9),
          reminderAt: DateTime(2026, 8, 10, 9),
        ),
        now: now,
      );

      expect(outcome.task.reminder, isNull);
      expect(scheduler.scheduleCalls, 0);
    });
  });

  group('failure atomicity', () {
    test('the task still saves when scheduling is blocked', () async {
      scheduler.outcome = const ScheduleOutcome(
        state: ReminderState.blocked,
        failureCode: 'NOTIFICATION_PERMISSION_DENIED',
      );

      final outcome = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );

      // The saved task is what matters; the reminder problem is reported, not
      // thrown (US-07).
      expect(await repository.countTasks(), 1);
      expect(outcome.task.status, TaskStatus.active);
      expect(outcome.task.reminder!.state, ReminderState.blocked);
      expect(outcome.reminderIssue, ReminderIssue.notificationsOff);
    });

    test(
      'the task still saves when the platform rejects the schedule',
      () async {
        scheduler.outcome = const ScheduleOutcome(
          state: ReminderState.failed,
          failureCode: 'NOTIFICATION_SCHEDULE_FAILED',
        );

        final outcome = await service.commitDraft(
          draft(dueAt: tomorrow9, reminderAt: tomorrow9),
          now: now,
        );

        expect(await repository.countTasks(), 1);
        expect(outcome.task.reminder!.state, ReminderState.failed);
        expect(outcome.task.hasReminderProblem, isTrue);
        expect(outcome.reminderIssue, isNotNull);
      },
    );
  });

  group('completion', () {
    test('cancels the platform notification before closing the task', () async {
      final saved = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );
      final platformId = saved.task.reminder!.platformId!;

      await service.completeTask(saved.task.id, now: now);

      expect(scheduler.cancelled, contains(platformId));
    });
  });

  group('snooze', () {
    test('moves the reminder 15 minutes out and re-schedules it', () async {
      final saved = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );

      final snoozed = await service.snooze(saved.task.id, now: now);

      expect(
        snoozed.task.reminder!.scheduledAt,
        now.add(ReminderScheduler.snoozeDuration),
      );
      expect(snoozed.task.reminder!.state, ReminderState.scheduled);
    });
  });

  group('reconciliation on resume', () {
    test('re-schedules a reminder the OS no longer knows about', () async {
      final saved = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );
      // The OS forgot it — a reboot, or a permission change.
      scheduler
        ..pending = <int>{}
        ..scheduleCalls = 0;

      final repaired = await service.reconcileReminders(now: now);

      expect(repaired, 1);
      expect(scheduler.scheduleCalls, 1);
      final reloaded = await repository.findTask(saved.task.id);
      expect(reloaded!.reminder!.state, ReminderState.scheduled);
    });

    test('leaves a reminder the OS is already holding alone', () async {
      final saved = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );
      scheduler
        ..pending = <int>{saved.task.reminder!.platformId!}
        ..scheduleCalls = 0;

      expect(await service.reconcileReminders(now: now), 0);
      expect(scheduler.scheduleCalls, 0);
    });

    test('force reschedules even reminders the OS is holding', () async {
      // Used when notification content changes, e.g. hiding previews.
      final saved = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );
      scheduler
        ..pending = <int>{saved.task.reminder!.platformId!}
        ..scheduleCalls = 0;

      expect(await service.reconcileReminders(now: now, force: true), 1);
      expect(scheduler.scheduleCalls, 1);
    });

    test('marks a reminder whose moment has passed as delivered', () async {
      final saved = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );

      await service.reconcileReminders(now: DateTime(2026, 8, 11, 10));

      final reloaded = await repository.findTask(saved.task.id);
      expect(reloaded!.reminder!.state, ReminderState.delivered);
    });
  });

  group('recovery regressions', () {
    for (final state in [ReminderState.blocked, ReminderState.failed]) {
      test('retries $state after scheduling becomes available', () async {
        scheduler.outcome = ScheduleOutcome(
          state: state,
          failureCode: 'UNAVAILABLE',
        );
        final saved = await service.commitDraft(
          draft(dueAt: tomorrow9, reminderAt: tomorrow9),
          now: now,
        );
        scheduler.outcome = null;
        expect(await service.reconcileReminders(now: now), 1);
        expect(scheduler.lastRequestPermission, isFalse);
        final restored = (await repository.findTask(saved.task.id))!.reminder!;
        expect(restored.state, ReminderState.scheduled);
        expect(restored.failureCode, isNull);
        expect(restored.platformId, isNotNull);
      });
      test('does not report expired $state as delivered', () async {
        scheduler.outcome = ScheduleOutcome(state: state);
        final saved = await service.commitDraft(
          draft(dueAt: tomorrow9, reminderAt: tomorrow9),
          now: now,
        );
        scheduler.scheduleCalls = 0;
        expect(
          await service.reconcileReminders(
            now: tomorrow9.add(const Duration(hours: 1)),
          ),
          0,
        );
        expect(scheduler.scheduleCalls, 0);
        expect(
          (await repository.findTask(saved.task.id))!.reminder!.state,
          state,
        );
      });
    }
    test('clears a stale OS id when scheduling becomes blocked', () async {
      final saved = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );
      scheduler.outcome = const ScheduleOutcome(state: ReminderState.blocked);
      await service.reconcileReminders(now: now);
      expect(
        (await repository.findTask(saved.task.id))!.reminder!.platformId,
        isNull,
      );
    });
  });

  group('erasing all data', () {
    test('cancels notifications and replaces cached widget content', () async {
      final widgets = _FakeWidgets();
      final withWidgets = TaskService(
        repository: repository,
        scheduler: scheduler,
        widgetSyncService: widgets,
      );
      await withWidgets.commitDraft(draft(dueAt: now), now: now);
      expect(widgets.tasks, isNotEmpty);
      await withWidgets.eraseAllData();
      expect(scheduler.cancelAllCalled, isTrue);
      expect(await repository.countTasks(), 0);
      expect(widgets.tasks, isEmpty);
    });
    test('keeps stored data if OS cancellation fails', () async {
      await service.commitDraft(draft(), now: now);
      scheduler.cancellationFails = true;
      await expectLater(service.eraseAllData(), throwsStateError);
      expect(await repository.countTasks(), 1);
    });
  });

  group('deletion', () {
    test('cancels the notification and removes the task', () async {
      final saved = await service.commitDraft(
        draft(dueAt: tomorrow9, reminderAt: tomorrow9),
        now: now,
      );
      final platformId = saved.task.reminder!.platformId!;

      await service.deleteTask(saved.task.id);

      expect(scheduler.cancelled, contains(platformId));
      expect(await repository.countTasks(), 0);
    });
  });
}
