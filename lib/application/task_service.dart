import 'package:uuid/uuid.dart';

import '../domain/drafts/task_draft.dart';
import '../domain/entities/reminder.dart';
import '../domain/entities/tag.dart';
import '../domain/entities/task.dart';
import '../domain/enums.dart';
import '../domain/repositories/task_repository.dart';
import '../services/notifications/reminder_scheduler.dart';

/// Result of committing a draft, including anything the user must be told
/// about a reminder that did not get scheduled.
class SaveOutcome {
  const SaveOutcome({required this.task, this.reminderWarning});

  final Task task;

  /// Non-null when the task saved but its reminder did not (US-07).
  final String? reminderWarning;

  bool get hasWarning => reminderWarning != null;
}

/// Coordinates persistence with notification scheduling.
///
/// These two cannot be one transaction — the OS scheduler is outside the
/// database — so the order is fixed: write the task and its reminder *intent*
/// first, then attempt the platform schedule, then record the outcome. A
/// failed reminder can never make a saved task disappear.
class TaskService {
  TaskService({
    required TaskRepository repository,
    required ReminderScheduler scheduler,
    Uuid? uuid,
  }) : _repository = repository,
       _scheduler = scheduler,
       _uuid = uuid ?? const Uuid();

  final TaskRepository _repository;
  final ReminderScheduler _scheduler;
  final Uuid _uuid;

  /// Turns a confirmed draft into a stored task.
  Future<SaveOutcome> commitDraft(
    TaskDraft draft, {
    required DateTime now,
  }) async {
    final tags = <Tag>[];
    for (final name in draft.tags) {
      tags.add(await _repository.ensureTag(name));
    }

    final taskId = _uuid.v4();
    final reminderAt = draft.reminderAt;

    final task = Task(
      id: taskId,
      title: draft.title,
      notes: draft.notes,
      status: TaskStatus.active,
      priority: draft.priority,
      startAt: draft.startAt,
      dueAt: draft.dueAt,
      durationMinutes: draft.durationMinutes,
      createdAt: now,
      updatedAt: now,
      recurrence: draft.recurrence,
      tags: tags,
      reminder: reminderAt == null || !reminderAt.isAfter(now)
          ? null
          : Reminder(
              id: _uuid.v4(),
              taskId: taskId,
              scheduledAt: reminderAt,
              timezone: _scheduler.localTimezone,
              state: ReminderState.pending,
            ),
    );

    final saved = await _repository.createTask(task);
    return _syncReminder(saved);
  }

  Future<SaveOutcome> saveTask(Task task) async {
    final saved = await _repository.updateTask(
      task.copyWith(updatedAt: DateTime.now()),
    );
    return _syncReminder(saved);
  }

  Future<void> deleteTask(String id) async {
    final task = await _repository.findTask(id);
    await _scheduler.cancel(task?.reminder?.platformId);
    await _repository.deleteTask(id);
  }

  Future<SaveOutcome> completeTask(String id, {DateTime? now}) async {
    final before = await _repository.findTask(id);
    await _scheduler.cancel(before?.reminder?.platformId);
    final after = await _repository.completeTask(
      id,
      now: now ?? DateTime.now(),
    );
    // A recurring task comes back active with a re-armed reminder; a one-off
    // comes back completed with nothing to schedule.
    return _syncReminder(after);
  }

  Future<SaveOutcome> reopenTask(String id) async {
    final task = await _repository.reopenTask(id);
    return _syncReminder(task);
  }

  /// Pushes a reminder 15 minutes out from now, from a notification action.
  Future<SaveOutcome> snooze(String id, {DateTime? now}) async {
    final task = await _repository.findTask(id);
    if (task == null) {
      throw StateError('Cannot snooze missing task $id');
    }
    final base = now ?? DateTime.now();
    final existing = task.reminder;
    final reminder = existing == null
        ? Reminder(
            id: _uuid.v4(),
            taskId: task.id,
            scheduledAt: base.add(ReminderScheduler.snoozeDuration),
            timezone: _scheduler.localTimezone,
            state: ReminderState.pending,
          )
        : existing.copyWith(
            scheduledAt: base.add(ReminderScheduler.snoozeDuration),
            state: ReminderState.pending,
            clearPlatformId: true,
            clearFailureCode: true,
          );
    await _scheduler.cancel(existing?.platformId);
    return saveTask(task.copyWith(reminder: reminder));
  }

  /// Re-checks every active reminder against the OS on resume.
  ///
  /// Platform notification ids are references, not authority: permission may
  /// have been revoked, the OS may have dropped schedules after a reboot, or
  /// a reminder may have come due while the app was closed.
  Future<int> reconcileReminders({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final tasks = await _repository.tasksWithPendingReminders();
    if (tasks.isEmpty) return 0;

    final pendingIds = await _scheduler.pendingPlatformIds();
    var repaired = 0;

    for (final task in tasks) {
      final reminder = task.reminder;
      if (reminder == null) continue;

      if (!reminder.scheduledAt.isAfter(at)) {
        // Its moment has passed; stop treating it as pending.
        await _repository.updateTask(
          task.copyWith(
            reminder: reminder.copyWith(state: ReminderState.delivered),
          ),
        );
        repaired++;
        continue;
      }

      final known =
          reminder.platformId != null &&
          pendingIds.contains(reminder.platformId);
      if (known && reminder.state == ReminderState.scheduled) continue;

      final outcome = await _scheduler.schedule(task, reminder);
      await _repository.updateTask(
        task.copyWith(
          reminder: reminder.copyWith(
            state: outcome.state,
            platformId: outcome.platformId,
            failureCode: outcome.failureCode,
            clearFailureCode: outcome.failureCode == null,
          ),
        ),
      );
      repaired++;
    }

    return repaired;
  }

  /// Attempts to schedule [task]'s reminder and records the real outcome.
  Future<SaveOutcome> _syncReminder(Task task) async {
    final reminder = task.reminder;
    if (reminder == null || !reminder.isActive) {
      return SaveOutcome(task: task);
    }

    final outcome = await _scheduler.schedule(task, reminder);
    final updated = await _repository.updateTask(
      task.copyWith(
        reminder: reminder.copyWith(
          state: outcome.state,
          platformId: outcome.platformId,
          failureCode: outcome.failureCode,
          clearFailureCode: outcome.failureCode == null,
          clearPlatformId: outcome.platformId == null,
        ),
      ),
    );

    return SaveOutcome(
      task: updated,
      reminderWarning: switch (outcome.state) {
        ReminderState.blocked =>
          'Saved, but no reminder will arrive — notifications are turned off.',
        ReminderState.failed =>
          'Saved, but the reminder could not be scheduled.',
        _ => null,
      },
    );
  }
}
