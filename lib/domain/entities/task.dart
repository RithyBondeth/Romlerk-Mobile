import '../enums.dart';
import 'recurrence_rule.dart';
import 'reminder.dart';
import 'tag.dart';

/// A task together with everything the UI needs to render it in one pass.
///
/// The repository always hydrates reminder, recurrence, and tags so lists do
/// not fan out into per-row queries.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.startAt,
    this.dueAt,
    this.durationMinutes,
    this.completedAt,
    this.reminder,
    this.recurrence,
    this.tags = const <Tag>[],
    this.occurrenceIndex = 0,
  });

  final String id;
  final String title;
  final String? notes;
  final TaskStatus status;
  final TaskPriority priority;

  /// Absolute timestamps. Relative phrasing ("tomorrow") is resolved at capture
  /// time and never stored as the source of truth.
  final DateTime? startAt;
  final DateTime? dueAt;

  final int? durationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  final Reminder? reminder;
  final RecurrenceRule? recurrence;
  final List<Tag> tags;

  /// How many occurrences of a recurring task have already been completed.
  /// Lets a `count`-bounded rule terminate.
  final int occurrenceIndex;

  bool get isCompleted => status == TaskStatus.completed;
  bool get isScheduled => dueAt != null || startAt != null;
  bool get isRecurring => recurrence != null;

  /// The timestamp lists sort and group by.
  DateTime? get effectiveDate => dueAt ?? startAt;

  bool isOverdueAt(DateTime now) {
    if (isCompleted) return false;
    final date = effectiveDate;
    return date != null && date.isBefore(now);
  }

  bool isDueOn(DateTime day) {
    final date = effectiveDate;
    if (date == null) return false;
    return date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }

  /// True when the task has no date at all — the Inbox definition.
  bool get isUnscheduled => effectiveDate == null;

  /// A reminder exists but will not fire, so the UI must warn.
  bool get hasReminderProblem => reminder?.state.needsAttention ?? false;

  Task copyWith({
    String? title,
    String? notes,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? startAt,
    DateTime? dueAt,
    int? durationMinutes,
    DateTime? updatedAt,
    DateTime? completedAt,
    Reminder? reminder,
    RecurrenceRule? recurrence,
    List<Tag>? tags,
    int? occurrenceIndex,
    bool clearNotes = false,
    bool clearStartAt = false,
    bool clearDueAt = false,
    bool clearDuration = false,
    bool clearCompletedAt = false,
    bool clearReminder = false,
    bool clearRecurrence = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      durationMinutes: clearDuration
          ? null
          : (durationMinutes ?? this.durationMinutes),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      reminder: clearReminder ? null : (reminder ?? this.reminder),
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      tags: tags ?? this.tags,
      occurrenceIndex: occurrenceIndex ?? this.occurrenceIndex,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'notes': notes,
    'status': status.wire,
    'priority': priority.wire,
    'startAt': startAt?.toIso8601String(),
    'dueAt': dueAt?.toIso8601String(),
    'durationMinutes': durationMinutes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'reminder': reminder?.toJson(),
    'recurrence': recurrence?.toJson(),
    'tags': tags.map((tag) => tag.name).toList(),
  };
}
