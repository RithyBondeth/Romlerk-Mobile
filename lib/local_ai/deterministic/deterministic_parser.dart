import 'package:uuid/uuid.dart';

import '../../domain/drafts/task_draft.dart';
import '../../domain/entities/recurrence_rule.dart';
import '../../domain/enums.dart';
import '../capabilities.dart';
import '../local_ai.dart';
import '../local_ai_error.dart';
import 'grammar.dart';

/// Tier C: rules-based capture that works on every device, in airplane mode,
/// with no model of any kind.
///
/// This is the app's floor, not a degraded mode. It is also the reference
/// implementation the generative tiers are validated against, so it is
/// deliberately deterministic: given the same text and the same
/// `referenceNow`, it always produces the same drafts.
class DeterministicTaskParser implements LocalAi {
  DeterministicTaskParser({
    NaturalLanguageGrammar? grammar,
    Uuid? uuid,
  }) : _grammar = grammar ?? const NaturalLanguageGrammar(),
       _uuid = uuid ?? const Uuid();

  final NaturalLanguageGrammar _grammar;
  final Uuid _uuid;

  static const int maxInputCharacters = 1000;
  static const int maxTitleCharacters = 200;
  static const int maxDraftsPerRequest = 8;

  @override
  Future<LocalAiCapabilities> capabilities() async {
    return const LocalAiCapabilities(
      provider: AiProvider.deterministic,
      availability: AiAvailability.available,
      features: <AiFeature>{AiFeature.structuredText},
      languages: <String>{'en'},
      constraints: AiConstraints(maxInputCharacters: maxInputCharacters),
    );
  }

  @override
  Future<void> cancel(String requestId) async {
    // Parsing is synchronous and sub-millisecond; there is nothing in flight
    // to cancel. Present for contract completeness.
  }

  @override
  Future<DurationSuggestion?> estimateDuration(
    String title, {
    String? notes,
  }) async {
    // Only reports a duration the user actually wrote. Guessing how long a
    // task takes is a generative feature (FR-17), not a deterministic one.
    final match = _grammar.findDuration(title);
    if (match == null) return null;
    return DurationSuggestion(minutes: match.value, isEstimate: false);
  }

  @override
  Future<TaskParseResult> parseTasks(TaskParseRequest request) async {
    final stopwatch = Stopwatch()..start();
    final input = request.text.trim();

    if (input.isEmpty) {
      return TaskParseResult(
        requestId: request.requestId,
        drafts: const <TaskDraft>[],
        provider: AiProvider.deterministic,
        tier: CapabilityTier.baselineParsing,
        latency: stopwatch.elapsed,
      );
    }
    if (input.length > maxInputCharacters) {
      throw LocalAiException(
        LocalAiErrorCode.inputTooLong,
        details: 'length=${input.length}',
        retainedInput: request.text,
      );
    }

    final segments = request.allowMultipleTasks
        ? splitIntoSegments(input)
        : <String>[input];

    final drafts = <TaskDraft>[];
    for (final segment in segments.take(maxDraftsPerRequest)) {
      final draft = _parseSegment(segment, request);
      if (draft != null) drafts.add(draft);
    }

    stopwatch.stop();
    return TaskParseResult(
      requestId: request.requestId,
      drafts: drafts,
      provider: AiProvider.deterministic,
      tier: CapabilityTier.baselineParsing,
      latency: stopwatch.elapsed,
    );
  }

  // ------------------------------------------------------------- segmenting

  static final RegExp _segmentSeparator = RegExp(
    r'(?:\s*[;]\s*)|(?:\s*,\s*(?:and\s+|then\s+|also\s+)?)|'
    r'(?:\s+(?:and(?:\s+then)?|then|also)\s+)',
    caseSensitive: false,
  );

  /// Splits conjoined input into independently actionable commitments (FR-05).
  ///
  /// A split is only accepted when the right-hand side starts with a known
  /// action verb. "Buy milk and email Ana tonight" splits; "Call David and
  /// Sam tomorrow" does not, because inventing a phantom task is far worse
  /// than leaving one to edit.
  static List<String> splitIntoSegments(String input) {
    final pieces = <String>[];
    var cursor = 0;
    var current = StringBuffer();

    for (final match in _segmentSeparator.allMatches(input)) {
      final left = input.substring(cursor, match.start);
      final rightRemainder = input.substring(match.end);
      if (_startsWithActionVerb(rightRemainder) && left.trim().isNotEmpty) {
        current.write(left);
        pieces.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current
          ..write(left)
          ..write(match.group(0));
      }
      cursor = match.end;
    }
    current.write(input.substring(cursor));
    final tail = current.toString().trim();
    if (tail.isNotEmpty) pieces.add(tail);

    final cleaned = pieces.where((piece) => piece.isNotEmpty).toList();
    return cleaned.isEmpty ? <String>[input] : cleaned;
  }

  static bool _startsWithActionVerb(String text) {
    final match = RegExp(r'^\s*([A-Za-z]+)').firstMatch(text);
    if (match == null) return false;
    return NaturalLanguageGrammar.actionVerbs.contains(
      match.group(1)!.toLowerCase(),
    );
  }

  // ---------------------------------------------------------------- parsing

  TaskDraft? _parseSegment(String segment, TaskParseRequest request) {
    final consumed = <Span>[];
    final ambiguities = <DraftAmbiguity>[];
    final warnings = <DraftWarning>[];
    final now = request.referenceNow;

    final recurrence = _grammar.findRecurrence(segment);
    if (recurrence != null) consumed.add(recurrence.span);

    final priority = _grammar.findPriority(segment);
    if (priority != null) consumed.add(priority.span);

    final duration = _grammar.findDuration(segment);
    if (duration != null) consumed.add(duration.span);

    final tags = _grammar.findTags(segment);
    consumed.addAll(tags.map((tag) => tag.span));

    final offset = _grammar.findRelativeTimeOffset(segment);
    final date = offset == null ? _grammar.findDate(segment, now) : null;
    if (date != null) consumed.add(date.span);
    if (offset != null) consumed.add(offset.span);

    final time = offset == null
        ? _grammar.findTime(segment, excluded: consumed)
        : null;
    if (time != null) consumed.add(time.span);

    final vague = (date == null && time == null && offset == null)
        ? _grammar.findVagueTime(segment)
        : null;
    if (vague != null) consumed.add(vague.span);

    final title = _buildTitle(segment, consumed);
    if (title.isEmpty) return null;

    final resolved = _resolveDateTime(
      date: date?.value,
      time: time?.value,
      offset: offset?.value,
      recurrence: recurrence?.value,
      now: now,
      ambiguities: ambiguities,
      warnings: warnings,
      dateSpanText: date?.text,
      timeSpanText: time?.text,
    );

    if (vague != null) {
      ambiguities.add(
        DraftAmbiguity(
          field: DraftField.dueAt,
          reason: '“${vague.text}” doesn’t say when. Pick a time.',
          sourceSpan: vague.text,
          alternatives: _quickTimeAlternatives(now),
        ),
      );
    }

    if (recurrence != null && resolved == null) {
      warnings.add(
        const DraftWarning(
          code: 'RECURRENCE_WITHOUT_DATE',
          message: 'A repeating task needs a first date before it can repeat.',
          field: DraftField.recurrence,
        ),
      );
    }

    return TaskDraft(
      id: _uuid.v4(),
      title: title,
      dueAt: resolved,
      reminderAt: resolved,
      recurrence: resolved == null ? null : recurrence?.value,
      priority: priority?.value ?? TaskPriority.none,
      durationMinutes: duration?.value,
      tags: _resolveTags(tags, request.knownTags),
      ambiguities: ambiguities,
      warnings: warnings,
      sourceText: segment,
      confidenceByField: <DraftField, double>{
        DraftField.title: 0.9,
        if (date != null) DraftField.dueAt: time == null ? 0.7 : 0.95,
        if (recurrence != null) DraftField.recurrence: 0.9,
      },
    );
  }

  /// Combines the extracted date and time into an absolute local timestamp,
  /// recording every assumption it had to make along the way.
  DateTime? _resolveDateTime({
    required DateOnly? date,
    required TimeOfDayValue? time,
    required Duration? offset,
    required RecurrenceRule? recurrence,
    required DateTime now,
    required List<DraftAmbiguity> ambiguities,
    required List<DraftWarning> warnings,
    String? dateSpanText,
    String? timeSpanText,
  }) {
    if (offset != null) {
      return now.add(offset);
    }

    if (date == null && time == null) {
      // A bare recurring phrase ("every monday") implies its own first date.
      if (recurrence != null) {
        final next = recurrence.nextOccurrenceAfter(
          DateTime(now.year, now.month, now.day, 9),
        );
        if (next != null) {
          warnings.add(
            const DraftWarning(
              code: 'TIME_ASSUMED',
              message: 'No time was given, so 9:00 AM was used.',
              field: DraftField.dueAt,
            ),
          );
          return next;
        }
      }
      return null;
    }

    var hour = time?.hour ?? 9;
    final minute = time?.minute ?? 0;
    var year = date?.year ?? now.year;
    var month = date?.month ?? now.month;
    var day = date?.day ?? now.day;

    if (time == null) {
      warnings.add(
        DraftWarning(
          code: 'TIME_ASSUMED',
          message: 'No time was specified, so 9:00 AM was used.',
          field: DraftField.dueAt,
        ),
      );
    } else if (time.approximate) {
      warnings.add(
        DraftWarning(
          code: 'TIME_APPROXIMATE',
          message:
              '“${timeSpanText?.trim() ?? 'that'}” was read as '
              '${_formatHour(hour, minute)}.',
          field: DraftField.dueAt,
        ),
      );
    }

    // A bare hour like "at 9" could mean either half of the day. Rather than
    // guess, offer both (US-03).
    if (time != null && !time.meridiemStated) {
      final morning = hour % 12;
      final evening = (hour % 12) + 12;
      ambiguities.add(
        DraftAmbiguity(
          field: DraftField.dueAt,
          reason: 'Did you mean ${_formatHour(morning, minute)} or '
              '${_formatHour(evening, minute)}?',
          sourceSpan: timeSpanText?.trim(),
          alternatives: <DraftAlternative>[
            DraftAlternative(
              label: _formatHour(morning, minute),
              dateTime: _safeLocal(year, month, day, morning, minute),
            ),
            DraftAlternative(
              label: _formatHour(evening, minute),
              dateTime: _safeLocal(year, month, day, evening, minute),
            ),
          ],
        ),
      );
      // Default to the morning reading while the ambiguity is unresolved; the
      // review screen keeps it flagged until the user confirms.
      hour = morning;
    }

    var resolved = _safeLocal(year, month, day, hour, minute);

    // A time with no date that has already passed today means tomorrow.
    if (date == null && resolved.isBefore(now)) {
      final rolled = DateTime(year, month, day + 1, hour, minute);
      warnings.add(
        DraftWarning(
          code: 'ROLLED_TO_TOMORROW',
          message:
              '${_formatHour(hour, minute)} has already passed today, so this '
              'was set for tomorrow.',
          field: DraftField.dueAt,
        ),
      );
      resolved = rolled;
      year = rolled.year;
      month = rolled.month;
      day = rolled.day;
    } else if (resolved.isBefore(now)) {
      warnings.add(
        const DraftWarning(
          code: 'TIME_IN_PAST',
          message: 'That time is in the past. No reminder will be scheduled.',
          field: DraftField.reminderAt,
        ),
      );
    }

    // DST gap: the requested wall-clock time does not exist on that day, and
    // Dart silently shifts it. Say so rather than letting the user discover it.
    if (resolved.hour != hour || resolved.minute != minute) {
      warnings.add(
        DraftWarning(
          code: 'DST_SHIFT',
          message:
              '${_formatHour(hour, minute)} does not exist on that date '
              '(clock change), so ${_formatHour(resolved.hour, resolved.minute)} '
              'was used.',
          field: DraftField.dueAt,
        ),
      );
    }

    return resolved;
  }

  /// Builds the task title from whatever text no extractor claimed.
  static String _buildTitle(String segment, List<Span> consumed) {
    final buffer = StringBuffer();
    for (var i = 0; i < segment.length; i++) {
      final covered = consumed.any((span) => i >= span.start && i < span.end);
      buffer.write(covered ? ' ' : segment[i]);
    }

    var title = buffer
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    title = const NaturalLanguageGrammar().stripLeadingFiller(title);

    // Prepositions and conjunctions stranded by a removed date phrase.
    title = title
        .replaceAll(
          RegExp(
            r'\s+\b(on|at|by|for|in|from|to|and|then)\b\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'^\s*\b(on|at|by|and|then)\b\s+', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+([,.;:])'), r'$1')
        .replaceAll(RegExp(r'[\s,;]+$'), '')
        .trim();

    if (title.isEmpty) return '';
    if (title.length > maxTitleCharacters) {
      title = '${title.substring(0, maxTitleCharacters - 1).trimRight()}…';
    }
    return title[0].toUpperCase() + title.substring(1);
  }

  /// Prefers an existing tag whose normalized name matches, so capture does
  /// not create near-duplicates that differ only by case.
  static List<String> _resolveTags(
    List<Extraction<String>> found,
    List<String> knownTags,
  ) {
    final knownByNormalized = <String, String>{
      for (final tag in knownTags) tag.trim().toLowerCase(): tag,
    };
    final result = <String>[];
    for (final tag in found) {
      final normalized = tag.value.trim().toLowerCase();
      final resolved = knownByNormalized[normalized] ?? tag.value;
      if (!result.contains(resolved)) result.add(resolved);
    }
    return result;
  }

  static List<DraftAlternative> _quickTimeAlternatives(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return <DraftAlternative>[
      DraftAlternative(
        label: 'This evening',
        dateTime: today.add(const Duration(hours: 19)),
      ),
      DraftAlternative(
        label: 'Tomorrow morning',
        dateTime: today.add(const Duration(days: 1, hours: 9)),
      ),
      DraftAlternative(
        label: 'Next week',
        dateTime: today.add(const Duration(days: 7, hours: 9)),
      ),
    ];
  }

  /// Constructs a local timestamp. Dart normalizes non-existent wall-clock
  /// times, which the caller then detects and reports.
  static DateTime _safeLocal(
    int year,
    int month,
    int day,
    int hour,
    int minute,
  ) => DateTime(year, month, day, hour, minute);

  static String _formatHour(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    final minutes = minute.toString().padLeft(2, '0');
    return '$display:$minutes $period';
  }
}
