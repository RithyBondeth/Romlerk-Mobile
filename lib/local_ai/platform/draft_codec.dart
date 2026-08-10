import 'package:uuid/uuid.dart';

import '../../domain/drafts/task_draft.dart';
import '../../domain/entities/recurrence_rule.dart';
import '../../domain/enums.dart';
import '../local_ai.dart';

/// Decodes and validates the structured payload a native model adapter
/// returns.
///
/// The BRD treats model output as untrusted input: unknown enum values,
/// out-of-range numbers, unparseable timestamps, and over-long text are all
/// rejected here rather than reaching the database. A [FormatException] means
/// the whole result is discarded and the user edits their original text.
class DraftCodec {
  const DraftCodec();

  static const int maxTitleLength = 200;
  static const int maxNotesLength = 2000;
  static const int maxTags = 10;
  static const int maxDrafts = 8;

  List<TaskDraft> decodeDrafts(
    Map<Object?, Object?> payload, {
    required TaskParseRequest request,
    Uuid uuid = const Uuid(),
  }) {
    final version = (payload['schemaVersion'] as num?)?.toInt();
    if (version == null || version > TaskParseResult.currentSchemaVersion) {
      throw FormatException('Unsupported schemaVersion: $version');
    }

    final rawTasks = payload['tasks'];
    if (rawTasks is! List) {
      throw const FormatException('tasks must be a list');
    }
    if (rawTasks.length > maxDrafts) {
      throw FormatException('Too many drafts: ${rawTasks.length}');
    }

    final drafts = <TaskDraft>[];
    for (final raw in rawTasks) {
      if (raw is! Map) throw const FormatException('task must be a map');
      final draft = _decodeDraft(raw, request: request, uuid: uuid);
      if (draft != null) drafts.add(draft);
    }
    return drafts;
  }

  TaskDraft? _decodeDraft(
    Map<Object?, Object?> raw, {
    required TaskParseRequest request,
    required Uuid uuid,
  }) {
    final title = _requireText(raw['title'], maxTitleLength)?.trim();
    if (title == null || title.isEmpty) return null;

    final notes = _requireText(raw['notes'], maxNotesLength)?.trim();
    final startAt = _decodeTimestamp(raw['startAt']);
    final dueAt = _decodeTimestamp(raw['dueAt']);
    final reminderAt = _decodeTimestamp(raw['reminderAt']);

    final duration = (raw['durationMinutes'] as num?)?.toInt();
    if (duration != null && (duration <= 0 || duration > 60 * 24)) {
      throw FormatException('durationMinutes out of range: $duration');
    }

    final priorityWire = raw['priority'] as String?;
    if (priorityWire != null &&
        !TaskPriority.values.any((value) => value.wire == priorityWire)) {
      throw FormatException('Unknown priority: $priorityWire');
    }

    final rawTags = raw['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      if (rawTags.length > maxTags) {
        throw FormatException('Too many tags: ${rawTags.length}');
      }
      for (final tag in rawTags) {
        final name = _requireText(tag, 60)?.trim();
        if (name != null && name.isNotEmpty && !tags.contains(name)) {
          tags.add(name);
        }
      }
    }

    return TaskDraft(
      id: uuid.v4(),
      title: title,
      notes: notes?.isEmpty ?? true ? null : notes,
      startAt: startAt,
      dueAt: dueAt,
      // A reminder must never be silently scheduled in the past.
      reminderAt: reminderAt != null && reminderAt.isBefore(request.referenceNow)
          ? null
          : reminderAt,
      recurrence: _decodeRecurrence(raw['recurrence']),
      priority: priorityWire == null
          ? TaskPriority.none
          : TaskPriority.fromWire(priorityWire),
      durationMinutes: duration,
      tags: tags,
      ambiguities: _decodeAmbiguities(raw['ambiguities']),
      warnings: _decodeWarnings(raw['warnings']),
      confidenceByField: _decodeConfidence(raw['confidenceByField']),
      sourceText: request.text,
      durationIsEstimate: raw['durationIsEstimate'] == true,
    );
  }

  static String? _requireText(Object? value, int maxLength) {
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Expected text, got ${value.runtimeType}');
    }
    if (value.length > maxLength) {
      throw FormatException('Text exceeds $maxLength characters');
    }
    return value;
  }

  static DateTime? _decodeTimestamp(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Expected ISO-8601 string, got $value');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Unparseable timestamp');
    }
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static RecurrenceRule? _decodeRecurrence(Object? value) {
    if (value == null) return null;
    if (value is! Map) throw const FormatException('recurrence must be a map');

    final frequencyWire = value['frequency'] as String?;
    if (frequencyWire == null ||
        !RecurrenceFrequency.values.any(
          (frequency) => frequency.wire == frequencyWire,
        )) {
      // Outside the deterministic engine's supported subset: rejected rather
      // than approximated.
      throw FormatException('Unsupported recurrence: $frequencyWire');
    }

    final interval = (value['interval'] as num?)?.toInt() ?? 1;
    if (interval < 1 || interval > 365) {
      throw FormatException('Recurrence interval out of range: $interval');
    }

    final weekdays = <int>[];
    final rawWeekdays = value['byWeekday'];
    if (rawWeekdays is List) {
      for (final day in rawWeekdays) {
        final parsed = (day as num?)?.toInt();
        if (parsed == null || parsed < 1 || parsed > 7) {
          throw FormatException('Invalid weekday: $day');
        }
        weekdays.add(parsed);
      }
    }

    return RecurrenceRule(
      frequency: RecurrenceFrequency.fromWire(frequencyWire),
      interval: interval,
      byWeekday: weekdays,
      until: _decodeTimestamp(value['until']),
      count: (value['count'] as num?)?.toInt(),
    );
  }

  static List<DraftAmbiguity> _decodeAmbiguities(Object? value) {
    if (value is! List) return const <DraftAmbiguity>[];
    final result = <DraftAmbiguity>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final field = _fieldFromWire(raw['field'] as String?);
      final reason = _requireText(raw['reason'], 200);
      if (field == null || reason == null) continue;
      result.add(
        DraftAmbiguity(
          field: field,
          reason: reason,
          sourceSpan: _requireText(raw['sourceSpan'], 120),
          alternatives: _decodeAlternatives(raw['alternatives']),
        ),
      );
    }
    return result;
  }

  static List<DraftAlternative> _decodeAlternatives(Object? value) {
    if (value is! List) return const <DraftAlternative>[];
    final result = <DraftAlternative>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final label = _requireText(raw['label'], 60);
      if (label == null) continue;
      result.add(
        DraftAlternative(
          label: label,
          dateTime: _decodeTimestamp(raw['dateTime']),
        ),
      );
    }
    return result;
  }

  static List<DraftWarning> _decodeWarnings(Object? value) {
    if (value is! List) return const <DraftWarning>[];
    final result = <DraftWarning>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final code = _requireText(raw['code'], 60);
      final message = _requireText(raw['message'], 200);
      if (code == null || message == null) continue;
      result.add(
        DraftWarning(
          code: code,
          message: message,
          field: _fieldFromWire(raw['field'] as String?),
        ),
      );
    }
    return result;
  }

  static Map<DraftField, double> _decodeConfidence(Object? value) {
    if (value is! Map) return const <DraftField, double>{};
    final result = <DraftField, double>{};
    value.forEach((key, score) {
      final field = _fieldFromWire(key?.toString());
      final parsed = (score as num?)?.toDouble();
      if (field == null || parsed == null) return;
      result[field] = parsed.clamp(0, 1).toDouble();
    });
    return result;
  }

  static DraftField? _fieldFromWire(String? wire) {
    if (wire == null) return null;
    for (final field in DraftField.values) {
      if (field.wire == wire) return field;
    }
    return null;
  }
}
