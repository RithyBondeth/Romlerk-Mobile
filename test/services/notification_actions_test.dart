import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/application/task_service.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/domain/entities/reminder.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/domain/repositories/task_repository.dart';
import 'package:romlerk_mobile/services/notifications/notification_actions.dart';
import 'package:romlerk_mobile/services/notifications/reminder_scheduler.dart';

class _FakeScheduler extends ReminderScheduler {
  final List<int> cancelled = <int>[];
  final List<DateTime> scheduledAt = <DateTime>[];

  @override
  String get localTimezone => 'Asia/Phnom_Penh';

  @override
  Future<void> initialize() async {}

  @override
  Future<ScheduleOutcome> schedule(Task task, Reminder reminder) async {
    scheduledAt.add(reminder.scheduledAt);
    return ScheduleOutcome(state: ReminderState.scheduled, platformId: 7);
  }

  @override
  Future<void> cancel(int? platformId) async {
    if (platformId != null) cancelled.add(platformId);
  }
}

void main() {
  final created = DateTime(2026, 8, 10, 9);

  Task task({String id = 't1'}) => Task(
    id: id,
    title: 'Call the clinic',
    status: TaskStatus.active,
    priority: TaskPriority.none,
    dueAt: DateTime.now().add(const Duration(minutes: 5)),
    createdAt: created,
    updatedAt: created,
    reminder: Reminder(
      id: 'r-$id',
      taskId: id,
      scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
      timezone: 'Asia/Phnom_Penh',
      state: ReminderState.scheduled,
      platformId: 42,
    ),
  );

  group('applyNotificationAction', () {
    late AppDatabase database;
    late DriftTaskRepository repository;
    late _FakeScheduler scheduler;
    late TaskService service;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftTaskRepository(database);
      scheduler = _FakeScheduler();
      service = TaskService(repository: repository, scheduler: scheduler);
      await repository.createTask(task());
    });

    tearDown(() => database.close());

    test('Complete completes the task and clears its notification', () async {
      final changed = await applyNotificationAction(
        service,
        taskId: 't1',
        actionId: ReminderScheduler.completeActionId,
      );
      expect(changed, isTrue);
      expect((await repository.findTask('t1'))!.isCompleted, isTrue);
      expect(scheduler.cancelled, contains(42));
    });

    test('Snooze moves the reminder about 15 minutes out', () async {
      final before = DateTime.now();
      final changed = await applyNotificationAction(
        service,
        taskId: 't1',
        actionId: ReminderScheduler.snoozeActionId,
      );
      expect(changed, isTrue);
      final reminder = (await repository.findTask('t1'))!.reminder!;
      // Stored to the second, so allow for the truncated fraction.
      expect(
        reminder.scheduledAt.difference(before),
        greaterThanOrEqualTo(
          ReminderScheduler.snoozeDuration - const Duration(seconds: 1),
        ),
      );
      expect(reminder.state, ReminderState.scheduled);
      expect(scheduler.cancelled, contains(42));
    });

    test('a task deleted since the reminder was set is not an error', () async {
      final changed = await applyNotificationAction(
        service,
        taskId: 'gone',
        actionId: ReminderScheduler.snoozeActionId,
      );
      expect(changed, isFalse);
    });

    test('an unknown action changes nothing', () async {
      final changed = await applyNotificationAction(
        service,
        taskId: 't1',
        actionId: 'something-else',
      );
      expect(changed, isFalse);
      expect((await repository.findTask('t1'))!.isCompleted, isFalse);
    });
  });

  test(
    'a write from a second connection reaches the app after a refresh',
    () async {
      // The app and the notification-action isolate each hold their own
      // connection to the same file.
      final dir = await Directory.systemTemp.createTemp('romlerk_actions');
      final file = File(p.join(dir.path, 'romlerk.sqlite'));
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final app = AppDatabase.forTesting(NativeDatabase(file));
      final action = AppDatabase.forTesting(NativeDatabase(file));

      await DriftTaskRepository(app).createTask(task());

      final seen = <bool>[];
      final subscription = DriftTaskRepository(app)
          .watchTasks(
            const TaskQuery(
              statuses: <TaskStatus>{TaskStatus.active, TaskStatus.completed},
            ),
          )
          .listen((tasks) => seen.add(tasks.single.isCompleted));
      await _until(() => seen.isNotEmpty);
      expect(seen.last, isFalse);

      await DriftTaskRepository(action).completeTask('t1', now: created);
      refreshAfterExternalWrite(app);

      await _until(() => seen.last);
      expect(seen.last, isTrue);

      // Not awaited: the repository's stream has a pending inner step whose
      // cancellation never completes, and nothing in the app awaits it either.
      unawaited(subscription.cancel());
      await action.close();
      await app.close();
      await dir.delete(recursive: true);
    },
  );
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
