import 'dart:ui';

import 'package:intl/intl.dart';

import '../../domain/entities/recurrence_rule.dart';
import '../../domain/enums.dart';
import '../../l10n/app_localizations.dart';

/// Date and time wording for the whole app.
///
/// The BRD's copy guidance is specific: review screens show the exact resolved
/// local date ("Tuesday, 11 August at 9:00 AM") even when the user typed
/// "tomorrow", so nothing important is scheduled off a phrase the user has not
/// actually seen resolved.
class TaskFormatting {
  const TaskFormatting({this.locale, AppLocalizations? strings})
    : _strings = strings;

  final String? locale;
  final AppLocalizations? _strings;

  static final AppLocalizations _english = lookupAppLocalizations(
    const Locale('en'),
  );

  AppLocalizations get _s => _strings ?? _english;

  /// A formatter in [locale] when its date data is loaded (MaterialApp's
  /// localization delegates load it for every supported language), otherwise
  /// in intl's built-in English, so formatting can never throw.
  DateFormat _format(DateFormat Function(String? locale) build) {
    try {
      return build(locale);
    } on Exception {
      // intl's LocaleDataException, which it does not export.
      return build(null);
    }
  }

  DateFormat get _weekdayDayMonth =>
      _format((l) => DateFormat('EEEE, d MMMM', l));
  DateFormat get _dayMonth => _format((l) => DateFormat('d MMMM', l));
  DateFormat get _dayMonthYear => _format((l) => DateFormat('d MMMM y', l));
  DateFormat get _weekday => _format((l) => DateFormat('EEEE', l));
  DateFormat get _time => _format(DateFormat.jm);

  /// Unambiguous, fully spelled out. Used wherever a mistake would be costly:
  /// draft review, task detail, reminder confirmation.
  String exact(DateTime moment, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final datePart = moment.year == reference.year
        ? _weekdayDayMonth.format(moment)
        : _dayMonthYear.format(moment);
    return _s.formatExactAt(datePart, _time.format(moment));
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
      1 => _s.formatTomorrowAt(time),
      -1 => _s.formatYesterdayAt(time),
      _ when dayDelta > 1 && dayDelta < 7 =>
        _s.formatWeekdayAt(_weekday.format(moment), time),
      _ when dayDelta < -1 && dayDelta > -7 =>
        _s.formatLastWeekdayAt(_weekday.format(moment), time),
      _ when moment.year == reference.year =>
        _s.formatDateAt(_dayMonth.format(moment), time),
      _ => _s.formatDateAt(_dayMonthYear.format(moment), time),
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
      0 => _s.formatTodayHeading(_dayMonth.format(day)),
      1 => _s.formatTomorrowHeading(_dayMonth.format(day)),
      _ => _weekdayDayMonth.format(day),
    };
  }

  String timeOnly(DateTime moment) => _time.format(moment);

  /// "Monday", in the current language.
  String weekdayName(DateTime moment) => _weekday.format(moment);

  /// "10 August", in the current language.
  String dayMonth(DateTime moment) => _dayMonth.format(moment);

  /// How overdue something is, in the largest unit that still reads naturally.
  String overdueBy(DateTime due, DateTime now) {
    final elapsed = now.difference(due);
    if (elapsed.inMinutes < 60) return _s.overdueMinutes(elapsed.inMinutes);
    if (elapsed.inHours < 24) return _s.overdueHours(elapsed.inHours);
    final days = elapsed.inDays;
    if (days < 7) return _s.overdueDays(days);
    return _s.overdueWeeks(days ~/ 7);
  }

  String duration(int minutes) {
    if (minutes < 60) return _s.durationMinutes(minutes);
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0
        ? _s.durationHours(hours)
        : _s.durationHoursMinutes(hours, rest);
  }

  String priority(TaskPriority priority) => switch (priority) {
    TaskPriority.none => _s.priorityNone,
    TaskPriority.low => _s.priorityLow,
    TaskPriority.medium => _s.priorityMedium,
    TaskPriority.high => _s.priorityHigh,
  };

  /// Short weekday name in the current language; 1 January 2024 was a
  /// Monday, so ISO weekday n falls on the nth.
  String _weekdayShort(int isoWeekday) =>
      _format(DateFormat.E).format(DateTime(2024, 1, isoWeekday));

  /// Plain-language recurrence, so the user can verify a repeating commitment
  /// before confirming it.
  String recurrence(RecurrenceRule rule) {
    final n = rule.interval;
    final base = switch (rule.frequency) {
      RecurrenceFrequency.daily =>
        n == 1 ? _s.recurEveryDay : _s.recurEveryNDays(n),
      RecurrenceFrequency.weekly => _weeklyDescription(rule),
      RecurrenceFrequency.monthly =>
        n == 1 ? _s.recurEveryMonth : _s.recurEveryNMonths(n),
      RecurrenceFrequency.yearly =>
        n == 1 ? _s.recurEveryYear : _s.recurEveryNYears(n),
    };

    if (rule.count != null) return _s.recurTimes(base, rule.count!);
    if (rule.until != null) {
      return _s.recurUntil(base, _dayMonth.format(rule.until!));
    }
    return base;
  }

  String _weeklyDescription(RecurrenceRule rule) {
    final n = rule.interval;
    if (rule.byWeekday.isEmpty) {
      return n == 1 ? _s.recurEveryWeek : _s.recurEveryNWeeks(n);
    }
    if (n == 1 &&
        rule.byWeekday.length == 5 &&
        rule.byWeekday.toSet().containsAll(<int>{1, 2, 3, 4, 5})) {
      return _s.recurEveryWeekday;
    }
    final days = (rule.byWeekday.toList()..sort())
        .map(_weekdayShort)
        .join(', ');
    return n == 1 ? _s.recurWeeklyOn(days) : _s.recurEveryNWeeksOn(n, days);
  }
}
