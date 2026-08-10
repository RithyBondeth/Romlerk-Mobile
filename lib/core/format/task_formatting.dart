import 'package:intl/intl.dart';

import '../../domain/entities/recurrence_rule.dart';
import '../../domain/enums.dart';

/// Date and time wording for the whole app.
///
/// The BRD's copy guidance is specific: review screens show the exact resolved
/// local date ("Tuesday, 11 August at 9:00 AM") even when the user typed
/// "tomorrow", so nothing important is scheduled off a phrase the user has not
/// actually seen resolved.
class TaskFormatting {
  const TaskFormatting({this.locale});

  final String? locale;

  DateFormat get _weekdayDayMonth => DateFormat('EEEE, d MMMM', locale);
  DateFormat get _dayMonth => DateFormat('d MMMM', locale);
  DateFormat get _dayMonthYear => DateFormat('d MMMM y', locale);
  DateFormat get _weekday => DateFormat('EEEE', locale);
  DateFormat get _time => DateFormat.jm(locale);

  /// Unambiguous, fully spelled out. Used wherever a mistake would be costly:
  /// draft review, task detail, reminder confirmation.
  String exact(DateTime moment, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final datePart = moment.year == reference.year
        ? _weekdayDayMonth.format(moment)
        : _dayMonthYear.format(moment);
    return '$datePart at ${_time.format(moment)}';
  }

  /// Compact form for list rows, where the surrounding grouping already gives
  /// context. Never used to confirm a reminder.
  String relative(DateTime moment, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final day = DateTime(moment.year, moment.month, moment.day);
    final dayDelta = day.difference(today).inDays;
    final time = _time.format(moment);

    return switch (dayDelta) {
      0 => time,
      1 => 'Tomorrow, $time',
      -1 => 'Yesterday, $time',
      _ when dayDelta > 1 && dayDelta < 7 =>
        '${_weekday.format(moment)}, $time',
      _ when dayDelta < -1 && dayDelta > -7 =>
        'Last ${_weekday.format(moment)}, $time',
      _ when moment.year == reference.year =>
        '${_dayMonth.format(moment)}, $time',
      _ => '${_dayMonthYear.format(moment)}, $time',
    };
  }

  /// Heading for a day group in Upcoming.
  String dayHeading(DateTime day, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final delta = DateTime(
      day.year,
      day.month,
      day.day,
    ).difference(today).inDays;
    return switch (delta) {
      0 => 'Today · ${_dayMonth.format(day)}',
      1 => 'Tomorrow · ${_dayMonth.format(day)}',
      _ => _weekdayDayMonth.format(day),
    };
  }

  String timeOnly(DateTime moment) => _time.format(moment);

  /// How overdue something is, in the largest unit that still reads naturally.
  String overdueBy(DateTime due, DateTime now) {
    final elapsed = now.difference(due);
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min overdue';
    if (elapsed.inHours < 24) return '${elapsed.inHours} h overdue';
    final days = elapsed.inDays;
    if (days < 7) return '$days ${days == 1 ? 'day' : 'days'} overdue';
    final weeks = days ~/ 7;
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} overdue';
  }

  String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  String priority(TaskPriority priority) => switch (priority) {
    TaskPriority.none => 'No priority',
    TaskPriority.low => 'Low',
    TaskPriority.medium => 'Medium',
    TaskPriority.high => 'High',
  };

  static const List<String> _weekdayAbbreviations = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Plain-language recurrence, so the user can verify a repeating commitment
  /// before confirming it.
  String recurrence(RecurrenceRule rule) {
    final every = rule.interval == 1 ? '' : 'every ${rule.interval} ';
    final base = switch (rule.frequency) {
      RecurrenceFrequency.daily => rule.interval == 1
          ? 'Every day'
          : 'Every ${rule.interval} days',
      RecurrenceFrequency.weekly => _weeklyDescription(rule, every),
      RecurrenceFrequency.monthly => rule.interval == 1
          ? 'Every month'
          : 'Every ${rule.interval} months',
      RecurrenceFrequency.yearly => rule.interval == 1
          ? 'Every year'
          : 'Every ${rule.interval} years',
    };

    if (rule.count != null) return '$base, ${rule.count} times';
    if (rule.until != null) {
      return '$base, until ${_dayMonth.format(rule.until!)}';
    }
    return base;
  }

  static String _weeklyDescription(RecurrenceRule rule, String every) {
    if (rule.byWeekday.isEmpty) {
      return rule.interval == 1 ? 'Every week' : 'Every ${rule.interval} weeks';
    }
    final days = (rule.byWeekday.toList()..sort())
        .map((day) => _weekdayAbbreviations[day - 1])
        .join(', ');
    if (rule.byWeekday.length == 5 &&
        rule.byWeekday.toSet().containsAll(<int>{1, 2, 3, 4, 5})) {
      return 'Every weekday';
    }
    return 'Every ${every}week on $days'.replaceAll('every week', 'week');
  }
}
