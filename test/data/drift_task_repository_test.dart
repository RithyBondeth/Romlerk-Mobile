import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/domain/entities/recurrence_rule.dart';
import 'package:romlerk_mobile/domain/entities/reminder.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/domain/repositories/task_repository.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;

  final now = DateTime(2026, 8, 10, 14, 30);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
  });

  tearDown(() => database.close());

  Task buildTask({
    required String id,
    String title = 'Task',
    DateTime? dueAt,
    TaskPriority priority = TaskPriority.none,
    TaskStatus status = TaskStatus.active,
    RecurrenceRule? recurrence,
    Reminder? reminder,
    DateTime? createdAt,
  }) {
    return Task(
      id: id,
      title: title,
      status: status,
      priority: priority,
      dueAt: dueAt,
      createdAt: createdAt ?? now,
      updatedAt: createdAt ?? now,
      recurrence: recurrence,
      reminder: reminder,
    );
  }

  group('persistence', () {
    test('a created task can be read back whole', () async {
      final task = buildTask(
        id: 'a',
        title: 'Call David',
        dueAt: DateTime(2026, 8, 11, 9),
        priority: TaskPriority.high,
        reminder: Reminder(
          id: 'r1',
          taskId: 'a',
          scheduledAt: DateTime(2026, 8, 11, 9),
          timezone: 'Europe/Copenhagen',
          state: ReminderState.pending,
        ),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          byWeekday: <int>[DateTime.tuesday],
        ),
      );

      await repository.createTask(task);
      final stored = await repository.findTask('a');

      expect(stored!.title, 'Call David');
      expect(stored.priority, TaskPriority.high);
      expect(stored.reminder!.scheduledAt, DateTime(2026, 8, 11, 9));
      expect(stored.recurrence!.byWeekday, <int>[DateTime.tuesday]);
    });

    test('updating replaces relations rather than duplicating them', () async {
      final task = await repository.createTask(
        buildTask(
          id: 'a',
          reminder: Reminder(
            id: 'r1',
            taskId: 'a',
            scheduledAt: DateTime(2026, 8, 11, 9),
            timezone: 'UTC',
            state: ReminderState.pending,
          ),
        ),
      );

      await repository.updateTask(
        task.copyWith(
          reminder: task.reminder!.copyWith(state: ReminderState.scheduled),
        ),
      );

      final reminders = await database.select(database.reminderRows).get();
      expect(reminders, hasLength(1));
      expect(reminders.single.state, ReminderState.scheduled.wire);
    });

    test('deleting a task takes its reminder with it', () async {
      await repository.createTask(
        buildTask(
          id: 'a',
          reminder: Reminder(
            id: 'r1',
            taskId: 'a',
            scheduledAt: DateTime(2026, 8, 11, 9),
            timezone: 'UTC',
            state: ReminderState.pending,
          ),
        ),
      );

      await repository.deleteTask('a');

      expect(await database.select(database.reminderRows).get(), isEmpty);
      expect(await repository.findTask('a'), isNull);
    });
  });

  group('completion', () {
    test('a one-off task closes and cancels its reminder', () async {
      await repository.createTask(
        buildTask(
          id: 'a',
          dueAt: DateTime(2026, 8, 11, 9),
          reminder: Reminder(
            id: 'r1',
            taskId: 'a',
            scheduledAt: DateTime(2026, 8, 11, 9),
            timezone: 'UTC',
            state: ReminderState.scheduled,
          ),
        ),
      );

      final completed = await repository.completeTask('a', now: now);

      expect(completed.status, TaskStatus.completed);
      expect(completed.completedAt, now);
      expect(completed.reminder!.state, ReminderState.cancelled);
    });

    test('a recurring task rolls forward instead of closing', () async {
      await repository.createTask(
        buildTask(
          id: 'a',
          dueAt: DateTime(2026, 8, 11, 9),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
          ),
          reminder: Reminder(
            id: 'r1',
            taskId: 'a',
            scheduledAt: DateTime(2026, 8, 11, 9),
            timezone: 'UTC',
            state: ReminderState.scheduled,
          ),
        ),
      );

      final rolled = await repository.completeTask('a', now: now);

      expect(rolled.status, TaskStatus.active);
      expect(rolled.dueAt, DateTime(2026, 8, 12, 9));
      expect(rolled.occurrenceIndex, 1);
      // Re-armed so the scheduler books the new time.
      expect(rolled.reminder!.state, ReminderState.pending);
      expect(rolled.reminder!.scheduledAt, DateTime(2026, 8, 12, 9));
    });

    test('a bounded recurring task closes once exhausted', () async {
      await repository.createTask(
        buildTask(
          id: 'a',
          dueAt: DateTime(2026, 8, 11, 9),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            count: 1,
          ),
        ),
      );

      final completed = await repository.completeTask('a', now: now);
      expect(completed.status, TaskStatus.completed);
    });

    test('reopening clears the completion timestamp', () async {
      await repository.createTask(
        buildTask(id: 'a', dueAt: DateTime(2026, 8, 11, 9)),
      );
      await repository.completeTask('a', now: now);

      final reopened = await repository.reopenTask('a');
      expect(reopened.status, TaskStatus.active);
      expect(reopened.completedAt, isNull);
    });
  });

  group('querying', () {
    setUp(() async {
      await repository.createTask(
        buildTask(
          id: 'overdue',
          title: 'Pay the invoice',
          dueAt: DateTime(2026, 8, 9, 9),
        ),
      );
      await repository.createTask(
        buildTask(
          id: 'today-high',
          title: 'Send the deck',
          dueAt: DateTime(2026, 8, 10, 16),
          priority: TaskPriority.high,
        ),
      );
      await repository.createTask(
        buildTask(id: 'undated', title: 'Read the spec notes'),
      );
      await repository.createTask(
        buildTask(
          id: 'done',
          title: 'Old thing',
          status: TaskStatus.completed,
          dueAt: DateTime(2026, 8, 8, 9),
        ),
      );
    });

    test('active is the default status filter', () async {
      final tasks = await repository.fetchTasks(const TaskQuery());
      expect(tasks.map((task) => task.id), isNot(contains('done')));
      expect(tasks, hasLength(3));
    });

    test('unscheduled returns only undated tasks', () async {
      final tasks = await repository.fetchTasks(
        const TaskQuery(onlyUnscheduled: true),
      );
      expect(tasks.map((task) => task.id), <String>['undated']);
    });

    test('a date window excludes tasks outside it', () async {
      final tasks = await repository.fetchTasks(
        TaskQuery(dueBefore: DateTime(2026, 8, 10)),
      );
      expect(tasks.map((task) => task.id), <String>['overdue']);
    });

    test('search matches title text case-insensitively', () async {
      final tasks = await repository.fetchTasks(
        const TaskQuery(text: 'INVOICE'),
      );
      expect(tasks.map((task) => task.id), <String>['overdue']);
    });

    test('priority filters narrow the set', () async {
      final tasks = await repository.fetchTasks(
        const TaskQuery(priorities: <TaskPriority>{TaskPriority.high}),
      );
      expect(tasks.map((task) => task.id), <String>['today-high']);
    });

    test('dated tasks sort before undated, earliest first', () async {
      final tasks = await repository.fetchTasks(const TaskQuery());
      expect(tasks.map((task) => task.id), <String>[
        'overdue',
        'today-high',
        'undated',
      ]);
    });
  });

  group('tags', () {
    test('ensureTag reuses an existing tag regardless of case', () async {
      final first = await repository.ensureTag('Work');
      final second = await repository.ensureTag('work');
      expect(second.id, first.id);
      expect(await repository.fetchTags(), hasLength(1));
    });

    test('tags attached to a task come back with it', () async {
      final tag = await repository.ensureTag('errands');
      await repository.createTask(
        buildTask(id: 'a').copyWith(tags: <dynamic>[tag].cast()),
      );
      final stored = await repository.findTask('a');
      expect(stored!.tags.single.name, 'errands');
    });
  });

  group('erase', () {
    test('removes every table the user owns', () async {
      final tag = await repository.ensureTag('work');
      await repository.createTask(
        buildTask(
          id: 'a',
          reminder: Reminder(
            id: 'r1',
            taskId: 'a',
            scheduledAt: DateTime(2026, 8, 11, 9),
            timezone: 'UTC',
            state: ReminderState.pending,
          ),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
          ),
        ).copyWith(tags: <dynamic>[tag].cast()),
      );

      await repository.eraseAllData();

      expect(await repository.countTasks(), 0);
      expect(await repository.fetchTags(), isEmpty);
      expect(await database.select(database.reminderRows).get(), isEmpty);
      expect(await database.select(database.recurrenceRows).get(), isEmpty);
      expect(await database.select(database.taskTagRows).get(), isEmpty);
    });
  });

  group('reminder reconciliation input', () {
    test('only pending and scheduled reminders are returned', () async {
      await repository.createTask(
        buildTask(
          id: 'pending',
          reminder: Reminder(
            id: 'r1',
            taskId: 'pending',
            scheduledAt: DateTime(2026, 8, 11, 9),
            timezone: 'UTC',
            state: ReminderState.pending,
          ),
        ),
      );
      await repository.createTask(
        buildTask(
          id: 'cancelled',
          reminder: Reminder(
            id: 'r2',
            taskId: 'cancelled',
            scheduledAt: DateTime(2026, 8, 11, 9),
            timezone: 'UTC',
            state: ReminderState.cancelled,
          ),
        ),
      );

      final tasks = await repository.tasksWithPendingReminders();
      expect(tasks.map((task) => task.id), <String>['pending']);
    });
  });
}
