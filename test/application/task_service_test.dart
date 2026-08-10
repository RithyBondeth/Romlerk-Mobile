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

/// Stands in for the OS notification scheduler so the outcome of every
/// scheduling attempt can be dictated by the test.
class _FakeScheduler extends ReminderScheduler {
  /// The result [schedule] should return. Defaults to success.
  ScheduleOutcome? outcome;

  final List<int> cancelled = <int>[];
  Set<int> pending = <int>{};
  int scheduleCalls = 0;

  @override
  String get localTimezone => 'Europe/Copenhagen';

  @override
  Future<void> initialize() async {}

  @override
  Future<ScheduleOutcome> schedule(Task task, Reminder reminder) async {
    scheduleCalls++;
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
  Future<Set<int>> pendingPlatformIds() async => pending;
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
      expect(tags.map((tag) => tag.name), containsAll(<String>['work', 'calls']));
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
      expect(outcome.reminderWarning, contains('notifications are turned off'));
    });

    test('the task still saves when the platform rejects the schedule',
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
      expect(outcome.reminderWarning, isNotNull);
    });
  });

  group('completion', () {
    test('cancels the platform notification before closing the task',
        () async {
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
