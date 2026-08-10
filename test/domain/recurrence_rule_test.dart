import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/domain/entities/recurrence_rule.dart';
import 'package:romlerk_mobile/domain/enums.dart';

void main() {
  group('daily', () {
    test('advances by the interval', () {
      const rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        interval: 3,
      );
      expect(
        rule.nextOccurrenceAfter(DateTime(2026, 8, 10, 9)),
        DateTime(2026, 8, 13, 9),
      );
    });

    test('keeps the wall-clock time across a DST boundary', () {
      // Adding a raw 24-hour Duration would shift a 9:00 reminder to 8:00 or
      // 10:00 on the changeover day; calendar arithmetic must not.
      const rule = RecurrenceRule(frequency: RecurrenceFrequency.daily);
      final next = rule.nextOccurrenceAfter(DateTime(2026, 10, 24, 9, 30));
      expect(next!.hour, 9);
      expect(next.minute, 30);
    });
  });

  group('weekly', () {
    test('lands on the next listed weekday', () {
      // Monday 10 August 2026 -> the Wednesday of the same week.
      const rule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        byWeekday: <int>[DateTime.wednesday],
      );
      expect(
        rule.nextOccurrenceAfter(DateTime(2026, 8, 10, 9)),
        DateTime(2026, 8, 12, 9),
      );
    });

    test('cycles through several listed weekdays in order', () {
      const rule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        byWeekday: <int>[DateTime.monday, DateTime.thursday],
      );
      final monday = DateTime(2026, 8, 10, 9);
      final thursday = rule.nextOccurrenceAfter(monday)!;
      expect(thursday, DateTime(2026, 8, 13, 9));
      expect(
        rule.nextOccurrenceAfter(thursday),
        DateTime(2026, 8, 17, 9),
      );
    });

    test('with no weekday listed, advances a whole week', () {
      const rule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
      );
      expect(
        rule.nextOccurrenceAfter(DateTime(2026, 8, 10, 9)),
        DateTime(2026, 8, 24, 9),
      );
    });
  });

  group('monthly', () {
    test('clamps to the last day of a shorter month', () {
      // 31 January + 1 month must be 28 February, not 3 March.
      const rule = RecurrenceRule(frequency: RecurrenceFrequency.monthly);
      expect(
        rule.nextOccurrenceAfter(DateTime(2026, 1, 31, 9)),
        DateTime(2026, 2, 28, 9),
      );
    });

    test('rolls the year over', () {
      const rule = RecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        interval: 3,
      );
      expect(
        rule.nextOccurrenceAfter(DateTime(2026, 11, 15, 9)),
        DateTime(2027, 2, 15, 9),
      );
    });
  });

  group('bounds', () {
    test('stops once the count is exhausted', () {
      const rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        count: 3,
      );
      expect(
        rule.nextOccurrenceAfter(
          DateTime(2026, 8, 10, 9),
          occurrencesSoFar: 2,
        ),
        isNotNull,
      );
      expect(
        rule.nextOccurrenceAfter(
          DateTime(2026, 8, 10, 9),
          occurrencesSoFar: 3,
        ),
        isNull,
      );
    });

    test('stops past the until date', () {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        until: DateTime(2026, 8, 11),
      );
      expect(rule.nextOccurrenceAfter(DateTime(2026, 8, 11, 9)), isNull);
    });
  });

  test('round-trips through JSON', () {
    final rule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      interval: 2,
      byWeekday: const <int>[1, 5],
      until: DateTime(2026, 12, 31),
    );
    expect(RecurrenceRule.fromJson(rule.toJson()), rule);
  });
}
