import 'package:collection/collection.dart';

import '../enums.dart';

/// A deterministic, bounded subset of recurrence.
///
/// The BRD requires that recurrence be handled by a deterministic engine, so
/// anything the engine cannot express is rejected at parse time rather than
/// stored and approximated later.
class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byWeekday = const <int>[],
    this.until,
    this.count,
  });

  final RecurrenceFrequency frequency;

  /// Every N periods. Always >= 1.
  final int interval;

  /// ISO weekdays (Mon = 1 ... Sun = 7). Only meaningful for weekly rules.
  final List<int> byWeekday;

  /// Inclusive end date, or null for open-ended.
  final DateTime? until;

  /// Total number of occurrences, or null for open-ended.
  final int? count;

  bool get isBounded => until != null || count != null;

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    List<int>? byWeekday,
    DateTime? until,
    int? count,
    bool clearUntil = false,
    bool clearCount = false,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      byWeekday: byWeekday ?? this.byWeekday,
      until: clearUntil ? null : (until ?? this.until),
      count: clearCount ? null : (count ?? this.count),
    );
  }

  /// The next occurrence strictly after [from], or null once the rule is
  /// exhausted.
  ///
  /// [occurrencesSoFar] lets a `count`-bounded rule terminate correctly; the
  /// caller tracks how many instances have already been generated.
  DateTime? nextOccurrenceAfter(DateTime from, {int occurrencesSoFar = 0}) {
    if (count != null && occurrencesSoFar >= count!) return null;

    final DateTime candidate = switch (frequency) {
      RecurrenceFrequency.daily => _addDaysPreservingWallClock(
        from,
        interval,
      ),
      RecurrenceFrequency.weekly => _nextWeekly(from),
      RecurrenceFrequency.monthly => _addMonthsClamped(from, interval),
      RecurrenceFrequency.yearly => _addMonthsClamped(from, 12 * interval),
    };

    if (until != null && candidate.isAfter(until!)) return null;
    return candidate;
  }

  DateTime _nextWeekly(DateTime from) {
    if (byWeekday.isEmpty) {
      return _addDaysPreservingWallClock(from, 7 * interval);
    }
    final sorted = byWeekday.toSet().toList()..sort();
    // Look ahead far enough to clear the largest interval we support.
    for (var offset = 1; offset <= 7 * interval + 7; offset++) {
      final candidate = _addDaysPreservingWallClock(from, offset);
      if (!sorted.contains(candidate.weekday)) continue;
      if (interval == 1) return candidate;
      // For interval > 1, only accept days in an "on" week.
      final weeksApart = _wholeWeeksBetween(from, candidate);
      if (weeksApart % interval == 0) return candidate;
    }
    return _addDaysPreservingWallClock(from, 7 * interval);
  }

  static int _wholeWeeksBetween(DateTime a, DateTime b) {
    final startOfWeekA = DateTime(a.year, a.month, a.day - (a.weekday - 1));
    final startOfWeekB = DateTime(b.year, b.month, b.day - (b.weekday - 1));
    return startOfWeekB.difference(startOfWeekA).inDays ~/ 7;
  }

  /// Adds calendar days while keeping the local wall-clock time.
  ///
  /// Using `add(Duration(days: n))` would shift the displayed time by an hour
  /// across a DST boundary, which the BRD explicitly calls out.
  static DateTime _addDaysPreservingWallClock(DateTime from, int days) {
    return DateTime(
      from.year,
      from.month,
      from.day + days,
      from.hour,
      from.minute,
      from.second,
    );
  }

  /// Adds months, clamping the day to the last valid day of the target month
  /// so "the 31st, monthly" does not skip February.
  static DateTime _addMonthsClamped(DateTime from, int months) {
    final totalMonths = from.month - 1 + months;
    final year = from.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      from.day > lastDay ? lastDay : from.day,
      from.hour,
      from.minute,
      from.second,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'frequency': frequency.wire,
    'interval': interval,
    if (byWeekday.isNotEmpty) 'byWeekday': byWeekday,
    if (until != null) 'until': until!.toIso8601String(),
    if (count != null) 'count': count,
  };

  static RecurrenceRule fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      frequency: RecurrenceFrequency.fromWire(json['frequency'] as String),
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      byWeekday:
          (json['byWeekday'] as List<dynamic>?)
              ?.map((day) => (day as num).toInt())
              .toList() ??
          const <int>[],
      until: json['until'] == null
          ? null
          : DateTime.parse(json['until'] as String),
      count: (json['count'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule &&
      other.frequency == frequency &&
      other.interval == interval &&
      const ListEquality<int>().equals(other.byWeekday, byWeekday) &&
      other.until == until &&
      other.count == count;

  @override
  int get hashCode => Object.hash(
    frequency,
    interval,
    const ListEquality<int>().hash(byWeekday),
    until,
    count,
  );
}
