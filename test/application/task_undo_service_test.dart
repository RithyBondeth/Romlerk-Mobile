import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/task_service.dart';
import 'package:romlerk_mobile/application/undo/task_undo_service.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/entities/reminder.dart';
import 'package:romlerk_mobile/domain/entities/recurrence_rule.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/services/notifications/reminder_scheduler.dart';

class Scheduler extends ReminderScheduler {
  final cancelled = <int>[];
  int schedules = 0;
  @override
  Future<void> cancel(int? id) async {
    if (id != null) cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {}
  @override
  Future<ScheduleOutcome> schedule(
    Task t,
    Reminder r, {
    bool requestPermission = true,
  }) async {
    schedules++;
    return const ScheduleOutcome(state: ReminderState.scheduled, platformId: 4);
  }
}

void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;
  late TaskService service;
  late TaskUndoService undo;
  late Scheduler scheduler;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTaskRepository(db);
    scheduler = Scheduler();
    service = TaskService(repository: repo, scheduler: scheduler);
    undo = TaskUndoService(repo, service);
  });
  tearDown(() => db.close());
  Future<Task> seed({bool recurring = false}) async {
    final now = DateTime(2035);
    final tag = await repo.ensureTag('work');
    return repo.createTask(
      Task(
        id: 'task',
        title: 'Original',
        notes: 'Notes',
        status: TaskStatus.active,
        priority: TaskPriority.high,
        dueAt: now,
        durationMinutes: 20,
        createdAt: now,
        updatedAt: now,
        tags: [tag],
        occurrenceIndex: 2,
        recurrence: recurring
            ? const RecurrenceRule(frequency: RecurrenceFrequency.daily)
            : null,
        reminder: Reminder(
          id: 'alarm',
          taskId: 'task',
          scheduledAt: now,
          timezone: 'UTC',
          state: ReminderState.scheduled,
          platformId: 4,
        ),
      ),
    );
  }

  test(
    'undo completion restores recurrence date, progress and reminder',
    () async {
      final before = await seed(recurring: true);
      final action = await undo.toggle(before.id);
      expect((await repo.findTask(before.id))!.occurrenceIndex, 3);
      await action.undo();
      final restored = (await repo.findTask(before.id))!;
      expect(restored.occurrenceIndex, 2);
      expect(restored.dueAt, before.dueAt);
      expect(restored.reminder!.scheduledAt, before.reminder!.scheduledAt);
      expect(restored.tags.single.id, before.tags.single.id);
      expect(scheduler.schedules, 2);
      await expectLater(action.undo(), throwsStateError);
    },
  );
  test(
    'undo deletion restores every task field and schedules its reminder',
    () async {
      final before = await seed();
      final action = await undo.delete(before.id);
      expect(await repo.findTask(before.id), isNull);
      await action.undo();
      final restored = (await repo.findTask(before.id))!;
      expect(restored.title, before.title);
      expect(restored.notes, before.notes);
      expect(restored.durationMinutes, before.durationMinutes);
      expect(restored.tags.single.id, before.tags.single.id);
      expect(restored.reminder!.state, ReminderState.scheduled);
    },
  );
  test('undo refuses to overwrite a later edit', () async {
    await seed();
    final action = await undo.toggle('task');
    await service.editTask('task', (t) => t.copyWith(title: 'Later'));
    await expectLater(action.undo(), throwsStateError);
    expect((await repo.findTask('task'))!.title, 'Later');
  });
  test(
    'erasure invalidates deletion undo instead of resurrecting data',
    () async {
      await seed();
      final action = await undo.delete('task');
      await service.eraseAllData();
      await expectLater(action.undo(), throwsStateError);
      expect(await repo.findTask('task'), isNull);
    },
  );
  test('expired actions cannot restore data', () async {
    var called = false;
    final action = UndoAction(() async {
      called = true;
    }, expiresAt: DateTime(2000));
    await expectLater(action.undo(), throwsStateError);
    expect(called, isFalse);
  });
}
