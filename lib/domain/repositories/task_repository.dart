import '../entities/tag.dart';
import '../entities/task.dart';
import '../enums.dart';

/// How lists narrow the stored task set. All filtering happens in SQL so the
/// UI never holds the full table in memory.
class TaskQuery {
  const TaskQuery({
    this.text,
    this.statuses = const <TaskStatus>{TaskStatus.active},
    this.priorities = const <TaskPriority>{},
    this.tagIds = const <String>{},
    this.dueBefore,
    this.dueAfter,
    this.onlyUnscheduled = false,
  });

  /// Matched case-insensitively against title and notes.
  final String? text;

  final Set<TaskStatus> statuses;
  final Set<TaskPriority> priorities;
  final Set<String> tagIds;

  /// Exclusive upper bound on the task's effective date.
  final DateTime? dueBefore;

  /// Inclusive lower bound on the task's effective date.
  final DateTime? dueAfter;

  /// Restrict to tasks with no date at all (Inbox).
  final bool onlyUnscheduled;

  bool get hasActiveFilters =>
      priorities.isNotEmpty ||
      tagIds.isNotEmpty ||
      dueBefore != null ||
      dueAfter != null ||
      onlyUnscheduled ||
      statuses.length != 1 ||
      !statuses.contains(TaskStatus.active);

  TaskQuery copyWith({
    String? text,
    Set<TaskStatus>? statuses,
    Set<TaskPriority>? priorities,
    Set<String>? tagIds,
    DateTime? dueBefore,
    DateTime? dueAfter,
    bool? onlyUnscheduled,
    bool clearText = false,
    bool clearDueBefore = false,
    bool clearDueAfter = false,
  }) {
    return TaskQuery(
      text: clearText ? null : (text ?? this.text),
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      tagIds: tagIds ?? this.tagIds,
      dueBefore: clearDueBefore ? null : (dueBefore ?? this.dueBefore),
      dueAfter: clearDueAfter ? null : (dueAfter ?? this.dueAfter),
      onlyUnscheduled: onlyUnscheduled ?? this.onlyUnscheduled,
    );
  }
}

/// The app's only route to persisted task data.
///
/// Deliberately free of Drift and platform types (NFR-15) so the store can be
/// replaced — including by a future syncing implementation — without touching
/// the UI or application layer.
abstract interface class TaskRepository {
  /// Reactive stream that re-emits whenever matching rows change.
  Stream<List<Task>> watchTasks(TaskQuery query);

  Stream<Task?> watchTask(String id);

  Future<List<Task>> fetchTasks(TaskQuery query);

  Future<Task?> findTask(String id);

  /// Inserts [task] exactly as given, including its reminder and tags, in one
  /// transaction. Throws if any part fails, leaving nothing written.
  Future<Task> createTask(Task task);

  Future<Task> updateTask(Task task);

  Future<void> deleteTask(String id);

  /// Marks complete. For a recurring task this also rolls the schedule forward
  /// and returns the next occurrence instead of closing the task.
  Future<Task> completeTask(String id, {required DateTime now});

  Future<Task> reopenTask(String id);

  Stream<List<Tag>> watchTags();

  Future<List<Tag>> fetchTags();

  /// Returns the existing tag with this normalized name, or creates one.
  Future<Tag> ensureTag(String name);

  Future<void> deleteTag(String id);

  /// All tasks with an active reminder in the future — used to reconcile
  /// scheduled notifications on app resume.
  Future<List<Task>> tasksWithPendingReminders();

  /// Removes every task, tag, reminder, and local parse audit record (FR-25).
  Future<void> eraseAllData();

  Future<int> countTasks();
}
