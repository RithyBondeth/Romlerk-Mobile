import '../enums.dart';
import '../entities/recurrence_rule.dart';

/// Which draft field a note refers to. Keeps ambiguity and warning messages
/// attachable to a specific control in the review UI.
enum DraftField {
  title('title'),
  notes('notes'),
  dueAt('dueAt'),
  startAt('startAt'),
  reminderAt('reminderAt'),
  recurrence('recurrence'),
  priority('priority'),
  duration('duration'),
  tags('tags');

  const DraftField(this.wire);

  final String wire;
}

/// Something the parser could not resolve safely.
///
/// The BRD is explicit that the app must never silently invent a high-impact
/// schedule; an ambiguity is how the parser says "you decide".
class DraftAmbiguity {
  const DraftAmbiguity({
    required this.field,
    required this.reason,
    this.sourceSpan,
    this.alternatives = const <DraftAlternative>[],
  });

  final DraftField field;

  /// Plain-language explanation, e.g. "No time was specified".
  final String reason;

  /// The words in the original input that triggered this, when known.
  final String? sourceSpan;

  final List<DraftAlternative> alternatives;
}

/// A concrete, one-tap resolution offered for an ambiguity.
class DraftAlternative {
  const DraftAlternative({required this.label, this.dateTime});

  final String label;
  final DateTime? dateTime;
}

/// A non-blocking caution: past time, unsupported recurrence, DST gap, and so
/// on. Unlike an ambiguity, the draft is still saveable.
class DraftWarning {
  const DraftWarning({required this.code, required this.message, this.field});

  final String code;
  final String message;
  final DraftField? field;
}

/// One independently actionable commitment extracted from user input.
///
/// A draft is not persisted. It exists only between parsing and the user's
/// confirmation, which is what "preview before consequence" requires.
class TaskDraft {
  const TaskDraft({
    required this.id,
    required this.title,
    this.notes,
    this.startAt,
    this.dueAt,
    this.reminderAt,
    this.recurrence,
    this.priority = TaskPriority.none,
    this.durationMinutes,
    this.tags = const <String>[],
    this.ambiguities = const <DraftAmbiguity>[],
    this.warnings = const <DraftWarning>[],
    this.confidenceByField = const <DraftField, double>{},
    this.sourceText,
    this.durationIsEstimate = false,
  });

  final String id;
  final String title;
  final String? notes;
  final DateTime? startAt;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final RecurrenceRule? recurrence;
  final TaskPriority priority;
  final int? durationMinutes;
  final List<String> tags;

  final List<DraftAmbiguity> ambiguities;
  final List<DraftWarning> warnings;
  final Map<DraftField, double> confidenceByField;

  /// The slice of the original input this draft came from. Shown in review so
  /// the user can see what the app understood it from.
  final String? sourceText;

  /// True when [durationMinutes] was suggested rather than stated. Must be
  /// labelled as an estimate in the UI (FR-17).
  final bool durationIsEstimate;

  bool get hasAmbiguities => ambiguities.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  bool isAmbiguous(DraftField field) =>
      ambiguities.any((ambiguity) => ambiguity.field == field);

  TaskDraft copyWith({
    String? title,
    String? notes,
    DateTime? startAt,
    DateTime? dueAt,
    DateTime? reminderAt,
    RecurrenceRule? recurrence,
    TaskPriority? priority,
    int? durationMinutes,
    List<String>? tags,
    List<DraftAmbiguity>? ambiguities,
    List<DraftWarning>? warnings,
    bool? durationIsEstimate,
    bool clearNotes = false,
    bool clearStartAt = false,
    bool clearDueAt = false,
    bool clearReminderAt = false,
    bool clearRecurrence = false,
    bool clearDuration = false,
  }) {
    return TaskDraft(
      id: id,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      reminderAt: clearReminderAt ? null : (reminderAt ?? this.reminderAt),
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      priority: priority ?? this.priority,
      durationMinutes: clearDuration
          ? null
          : (durationMinutes ?? this.durationMinutes),
      tags: tags ?? this.tags,
      ambiguities: ambiguities ?? this.ambiguities,
      warnings: warnings ?? this.warnings,
      confidenceByField: confidenceByField,
      sourceText: sourceText,
      durationIsEstimate: durationIsEstimate ?? this.durationIsEstimate,
    );
  }

  /// Drops any ambiguity on [field]. Called when the user edits that field —
  /// their explicit choice resolves it.
  TaskDraft resolving(DraftField field) {
    if (!isAmbiguous(field)) return this;
    return copyWith(
      ambiguities: ambiguities
          .where((ambiguity) => ambiguity.field != field)
          .toList(),
    );
  }
}
