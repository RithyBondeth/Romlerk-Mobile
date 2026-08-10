import '../../domain/enums.dart';
import '../../domain/entities/recurrence_rule.dart';

/// A matched region of the original input.
///
/// Spans are collected rather than removed immediately, so the title can be
/// rebuilt in one pass at the end and every extraction can report the exact
/// words it came from (used for `sourceSpan` on ambiguities).
class Span {
  const Span(this.start, this.end);

  final int start;
  final int end;

  bool overlaps(Span other) => start < other.end && other.start < end;
}

class Extraction<T> {
  const Extraction(this.value, this.span, {this.text});

  final T value;
  final Span span;

  /// The literal words matched, for user-facing explanations.
  final String? text;
}

/// A calendar date with no time component.
class DateOnly {
  const DateOnly(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;
}

/// A wall-clock time, plus whether the user actually said which half of the
/// day they meant.
class TimeOfDayValue {
  const TimeOfDayValue(
    this.hour,
    this.minute, {
    this.meridiemStated = true,
    this.approximate = false,
  });

  final int hour;
  final int minute;

  /// False for a bare "at 9" — the parser must not guess silently.
  final bool meridiemStated;

  /// True for "in the morning" style phrasing, where a conventional hour was
  /// chosen and should be surfaced as an assumption.
  final bool approximate;
}

/// Regex-based English grammar for the deterministic (tier C) parser.
///
/// Deliberately a *supported subset*, not an attempt at open-ended
/// understanding: anything outside it falls through to manual editing, which
/// is the behaviour the BRD asks for.
class NaturalLanguageGrammar {
  const NaturalLanguageGrammar();

  static const Map<String, int> _weekdays = <String, int>{
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  static const Map<String, int> _months = <String, int>{
    'january': 1,
    'jan': 1,
    'february': 2,
    'feb': 2,
    'march': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'may': 5,
    'june': 6,
    'jun': 6,
    'july': 7,
    'jul': 7,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sep': 9,
    'sept': 9,
    'october': 10,
    'oct': 10,
    'november': 11,
    'nov': 11,
    'december': 12,
    'dec': 12,
  };

  static final String _weekdayAlternation = _weekdays.keys.join('|');
  static final String _monthAlternation = _months.keys.join('|');

  // ------------------------------------------------------------------ dates

  static final RegExp _relativeDay = RegExp(
    r'\b(day after tomorrow|tomorrow|tmrw|tmr|today|tonight)\b',
    caseSensitive: false,
  );

  static final RegExp _inNUnits = RegExp(
    r'\bin\s+(a|an|\d+)\s+(minute|min|hour|hr|day|week|month|year)s?\b',
    caseSensitive: false,
  );

  static final RegExp _weekdayPhrase = RegExp(
    r'\b(?:(on|next|this|coming)\s+)?(' '$_weekdayAlternation' r')\b',
    caseSensitive: false,
  );

  static final RegExp _dayThenMonth = RegExp(
    r'\b(?:on\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?('
    '$_monthAlternation'
    r')\b(?:\s+(\d{4}))?',
    caseSensitive: false,
  );

  static final RegExp _monthThenDay = RegExp(
    r'\b(?:on\s+)?(' '$_monthAlternation' r')\s+(\d{1,2})(?:st|nd|rd|th)?\b'
    r'(?:,?\s+(\d{4}))?',
    caseSensitive: false,
  );

  static final RegExp _numericDate = RegExp(
    r'\b(?:on\s+)?(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b',
  );

  static final RegExp _nextPeriod = RegExp(
    r'\b(next|this)\s+(week|month|weekend)\b',
    caseSensitive: false,
  );

  static final RegExp _endOfPeriod = RegExp(
    r'\bend of (?:the\s+)?(week|month)\b',
    caseSensitive: false,
  );

  // ------------------------------------------------------------------ times

  static final RegExp _namedTime = RegExp(
    r'\b(noon|midday|midnight)\b',
    caseSensitive: false,
  );

  static final RegExp _clockTime = RegExp(
    r'\b(?:at\s+)?(\d{1,2})(?::|\.)(\d{2})\s*(am|pm|a\.m\.|p\.m\.)?\b',
    caseSensitive: false,
  );

  static final RegExp _hourWithMeridiem = RegExp(
    r'\b(?:at\s+)?(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)\b',
    caseSensitive: false,
  );

  static final RegExp _bareHour = RegExp(
    r'\bat\s+(\d{1,2})\b(?!\s*(?::|\.)\d)',
    caseSensitive: false,
  );

  static final RegExp _partOfDay = RegExp(
    r'\b(?:in the\s+)?(morning|afternoon|evening)\b',
    caseSensitive: false,
  );

  /// Conventional hours for part-of-day phrasing. Always reported as
  /// approximate so the review screen can say the time was assumed.
  static const Map<String, int> _partOfDayHours = <String, int>{
    'morning': 9,
    'afternoon': 14,
    'evening': 18,
  };

  // ------------------------------------------------------- other extractions

  static final RegExp _vagueTime = RegExp(
    r'\b(later|soon|sometime|some time|someday|at some point|'
    r'in a bit|in a while)\b',
    caseSensitive: false,
  );

  static final RegExp _recurrenceEveryUnit = RegExp(
    r'\bevery\s+(?:(\d+|other)\s+)?(day|week|month|year|weekday|weekend)s?\b',
    caseSensitive: false,
  );

  static final RegExp _recurrenceEveryWeekday = RegExp(
    r'\bevery\s+(' '$_weekdayAlternation' r')s?\b',
    caseSensitive: false,
  );

  static final RegExp _recurrenceAdverb = RegExp(
    r'\b(daily|weekly|fortnightly|monthly|yearly|annually)\b',
    caseSensitive: false,
  );

  static final RegExp _duration = RegExp(
    r'\b(?:for|takes?)\s+(\d+)\s*(minutes?|mins?|m|hours?|hrs?|h)\b',
    caseSensitive: false,
  );

  static final RegExp _highPriorityWord = RegExp(
    r'\b(urgent|urgently|asap|important|high priority|top priority)\b',
    caseSensitive: false,
  );

  static final RegExp _lowPriorityWord = RegExp(
    r'\b(low priority|no rush|whenever|someday maybe)\b',
    caseSensitive: false,
  );

  static final RegExp _bangPriority = RegExp(r'(?:^|\s)(!{1,3})(?=\s|$)');

  static final RegExp _tag = RegExp(r'(?:^|\s)#([\w\-]+)');

  static final RegExp _leadingFiller = RegExp(
    r'^\s*(?:please\s+)?(?:remind me to|remind me|remember to|remember|'
    r"i need to|i have to|i must|need to|have to|don'?t forget to|"
    r"don'?t forget|make sure to|todo:?|task:?)\s+",
    caseSensitive: false,
  );

  // ----------------------------------------------------------------- lookups

  /// Verbs that may begin a second task after "and"/"then".
  ///
  /// A curated list is deliberate: a wrong split invents a task the user never
  /// asked for, while a missed split just leaves one task to edit. Precision
  /// beats recall here.
  static const Set<String> actionVerbs = <String>{
    'add', 'apply', 'ask', 'back', 'backup', 'book', 'bring', 'buy', 'cancel',
    'call', 'charge', 'check', 'clean', 'collect', 'confirm', 'cook', 'deliver',
    'download', 'drop', 'email', 'feed', 'fetch', 'file', 'finish', 'fix',
    'follow', 'get', 'install', 'invite', 'mail', 'meet', 'message', 'order',
    'pack', 'pay', 'pick', 'plan', 'post', 'prepare', 'print', 'read',
    'register', 'refill', 'remind', 'renew', 'reply', 'return', 'review',
    'schedule', 'send', 'sign', 'start', 'study', 'submit', 'take', 'text',
    'tell', 'update', 'upload', 'visit', 'walk', 'wash', 'water', 'write',
  };

  // --------------------------------------------------------------- extractors

  /// Finds an absolute or relative date. Returns null when the text has none.
  ///
  /// [reference] anchors relative expressions; nothing here reads the clock.
  Extraction<DateOnly>? findDate(String text, DateTime reference) {
    final relative = _relativeDay.firstMatch(text);
    if (relative != null) {
      final word = relative.group(1)!.toLowerCase();
      final offset = switch (word) {
        'today' || 'tonight' => 0,
        'tomorrow' || 'tmr' || 'tmrw' => 1,
        _ => 2, // day after tomorrow
      };
      final date = DateTime(
        reference.year,
        reference.month,
        reference.day + offset,
      );
      return Extraction<DateOnly>(
        DateOnly(date.year, date.month, date.day),
        Span(relative.start, relative.end),
        text: relative.group(0),
      );
    }

    final inUnits = _inNUnits.firstMatch(text);
    if (inUnits != null) {
      final rawAmount = inUnits.group(1)!.toLowerCase();
      final amount = rawAmount == 'a' || rawAmount == 'an'
          ? 1
          : int.parse(rawAmount);
      final unit = inUnits.group(2)!.toLowerCase();
      // Sub-day units shift the clock, so they are handled as a time offset
      // by findRelativeTimeOffset instead.
      if (unit == 'minute' || unit == 'min' || unit == 'hour' || unit == 'hr') {
        return null;
      }
      final date = switch (unit) {
        'day' => DateTime(
          reference.year,
          reference.month,
          reference.day + amount,
        ),
        'week' => DateTime(
          reference.year,
          reference.month,
          reference.day + 7 * amount,
        ),
        'month' => DateTime(
          reference.year,
          reference.month + amount,
          reference.day,
        ),
        _ => DateTime(
          reference.year + amount,
          reference.month,
          reference.day,
        ),
      };
      return Extraction<DateOnly>(
        DateOnly(date.year, date.month, date.day),
        Span(inUnits.start, inUnits.end),
        text: inUnits.group(0),
      );
    }

    final weekday = _weekdayPhrase.firstMatch(text);
    if (weekday != null) {
      final qualifier = weekday.group(1)?.toLowerCase();
      final target = _weekdays[weekday.group(2)!.toLowerCase()]!;
      // "next friday" means the friday of the following week; a bare or
      // "this" friday means the soonest upcoming one.
      var delta = (target - reference.weekday) % 7;
      if (delta == 0) delta = 7;
      if (qualifier == 'next') delta += 7;
      final date = DateTime(
        reference.year,
        reference.month,
        reference.day + delta,
      );
      return Extraction<DateOnly>(
        DateOnly(date.year, date.month, date.day),
        Span(weekday.start, weekday.end),
        text: weekday.group(0),
      );
    }

    final dayMonth = _dayThenMonth.firstMatch(text);
    if (dayMonth != null) {
      final day = int.parse(dayMonth.group(1)!);
      final month = _months[dayMonth.group(2)!.toLowerCase()]!;
      final year =
          int.tryParse(dayMonth.group(3) ?? '') ??
          _yearFor(month, day, reference);
      if (_isValidDate(year, month, day)) {
        return Extraction<DateOnly>(
          DateOnly(year, month, day),
          Span(dayMonth.start, dayMonth.end),
          text: dayMonth.group(0),
        );
      }
    }

    final monthDay = _monthThenDay.firstMatch(text);
    if (monthDay != null) {
      final month = _months[monthDay.group(1)!.toLowerCase()]!;
      final day = int.parse(monthDay.group(2)!);
      final year =
          int.tryParse(monthDay.group(3) ?? '') ??
          _yearFor(month, day, reference);
      if (_isValidDate(year, month, day)) {
        return Extraction<DateOnly>(
          DateOnly(year, month, day),
          Span(monthDay.start, monthDay.end),
          text: monthDay.group(0),
        );
      }
    }

    final period = _nextPeriod.firstMatch(text);
    if (period != null) {
      final qualifier = period.group(1)!.toLowerCase();
      final unit = period.group(2)!.toLowerCase();
      final DateTime date;
      if (unit == 'weekend') {
        var delta = (DateTime.saturday - reference.weekday) % 7;
        if (delta == 0) delta = 7;
        if (qualifier == 'next') delta += 7;
        date = DateTime(reference.year, reference.month, reference.day + delta);
      } else if (unit == 'week') {
        // Monday of the following week.
        final toMonday = (DateTime.monday - reference.weekday) % 7;
        date = DateTime(
          reference.year,
          reference.month,
          reference.day + (toMonday == 0 ? 7 : toMonday),
        );
      } else {
        date = qualifier == 'next'
            ? DateTime(reference.year, reference.month + 1, 1)
            : DateTime(reference.year, reference.month, reference.day);
      }
      return Extraction<DateOnly>(
        DateOnly(date.year, date.month, date.day),
        Span(period.start, period.end),
        text: period.group(0),
      );
    }

    final endOf = _endOfPeriod.firstMatch(text);
    if (endOf != null) {
      final unit = endOf.group(1)!.toLowerCase();
      final date = unit == 'week'
          ? DateTime(
              reference.year,
              reference.month,
              reference.day + (DateTime.friday - reference.weekday) % 7,
            )
          : DateTime(reference.year, reference.month + 1, 0);
      return Extraction<DateOnly>(
        DateOnly(date.year, date.month, date.day),
        Span(endOf.start, endOf.end),
        text: endOf.group(0),
      );
    }

    final numeric = _numericDate.firstMatch(text);
    if (numeric != null) {
      // Day-first, matching the BRD's "11 August" examples. A locale-aware
      // order is a follow-up once additional locales ship.
      final day = int.parse(numeric.group(1)!);
      final month = int.parse(numeric.group(2)!);
      final rawYear = numeric.group(3);
      final year = rawYear == null
          ? _yearFor(month, day, reference)
          : (rawYear.length == 2 ? 2000 + int.parse(rawYear) : int.parse(rawYear));
      if (_isValidDate(year, month, day)) {
        return Extraction<DateOnly>(
          DateOnly(year, month, day),
          Span(numeric.start, numeric.end),
          text: numeric.group(0),
        );
      }
    }

    return null;
  }

  /// Handles "in 20 minutes" / "in 2 hours", which move the clock rather than
  /// naming a calendar day.
  Extraction<Duration>? findRelativeTimeOffset(String text) {
    final match = _inNUnits.firstMatch(text);
    if (match == null) return null;
    final unit = match.group(2)!.toLowerCase();
    if (unit != 'minute' && unit != 'min' && unit != 'hour' && unit != 'hr') {
      return null;
    }
    final raw = match.group(1)!.toLowerCase();
    final amount = raw == 'a' || raw == 'an' ? 1 : int.parse(raw);
    final duration = unit.startsWith('h')
        ? Duration(hours: amount)
        : Duration(minutes: amount);
    return Extraction<Duration>(
      duration,
      Span(match.start, match.end),
      text: match.group(0),
    );
  }

  /// Finds a wall-clock time. [excluded] spans (an already-matched date, for
  /// example) are skipped so "12/08" is not also read as "12:08".
  Extraction<TimeOfDayValue>? findTime(
    String text, {
    List<Span> excluded = const <Span>[],
  }) {
    bool blocked(int start, int end) =>
        excluded.any((span) => span.overlaps(Span(start, end)));

    final named = _namedTime.firstMatch(text);
    if (named != null && !blocked(named.start, named.end)) {
      final word = named.group(1)!.toLowerCase();
      return Extraction<TimeOfDayValue>(
        word == 'midnight'
            ? const TimeOfDayValue(0, 0)
            : const TimeOfDayValue(12, 0),
        Span(named.start, named.end),
        text: named.group(0),
      );
    }

    for (final match in _clockTime.allMatches(text)) {
      if (blocked(match.start, match.end)) continue;
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (hour > 23 || minute > 59) continue;
      final meridiem = match.group(3)?.toLowerCase().replaceAll('.', '');
      if (meridiem != null) {
        hour = _applyMeridiem(hour, meridiem);
      }
      return Extraction<TimeOfDayValue>(
        TimeOfDayValue(
          hour,
          minute,
          // 13:00 and up are unambiguous without a meridiem.
          meridiemStated: meridiem != null || hour == 0 || hour > 12,
        ),
        Span(match.start, match.end),
        text: match.group(0),
      );
    }

    for (final match in _hourWithMeridiem.allMatches(text)) {
      if (blocked(match.start, match.end)) continue;
      final hour = int.parse(match.group(1)!);
      if (hour > 12) continue;
      final meridiem = match.group(2)!.toLowerCase().replaceAll('.', '');
      return Extraction<TimeOfDayValue>(
        TimeOfDayValue(_applyMeridiem(hour, meridiem), 0),
        Span(match.start, match.end),
        text: match.group(0),
      );
    }

    for (final match in _bareHour.allMatches(text)) {
      if (blocked(match.start, match.end)) continue;
      final hour = int.parse(match.group(1)!);
      if (hour > 23) continue;
      // 8-11 and 13+ read unambiguously; 1-7 and 12 do not, and the caller
      // turns that into an explicit chooser rather than a guess.
      final unambiguous = (hour >= 8 && hour <= 11) || hour > 12;
      return Extraction<TimeOfDayValue>(
        TimeOfDayValue(hour, 0, meridiemStated: unambiguous),
        Span(match.start, match.end),
        text: match.group(0),
      );
    }

    final part = _partOfDay.firstMatch(text);
    if (part != null && !blocked(part.start, part.end)) {
      final hour = _partOfDayHours[part.group(1)!.toLowerCase()]!;
      return Extraction<TimeOfDayValue>(
        TimeOfDayValue(hour, 0, approximate: true),
        Span(part.start, part.end),
        text: part.group(0),
      );
    }

    // "tonight" carries an implied evening time when no clock time was given.
    final tonight = RegExp(
      r'\btonight\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (tonight != null) {
      return Extraction<TimeOfDayValue>(
        const TimeOfDayValue(19, 0, approximate: true),
        Span(tonight.start, tonight.end),
        text: tonight.group(0),
      );
    }

    return null;
  }

  /// Detects words that gesture at a time without naming one.
  Extraction<String>? findVagueTime(String text) {
    final match = _vagueTime.firstMatch(text);
    if (match == null) return null;
    return Extraction<String>(
      match.group(1)!.toLowerCase(),
      Span(match.start, match.end),
      text: match.group(0),
    );
  }

  Extraction<RecurrenceRule>? findRecurrence(String text) {
    final weekly = _recurrenceEveryWeekday.firstMatch(text);
    if (weekly != null) {
      final weekday = _weekdays[weekly.group(1)!.toLowerCase()]!;
      return Extraction<RecurrenceRule>(
        RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          byWeekday: <int>[weekday],
        ),
        Span(weekly.start, weekly.end),
        text: weekly.group(0),
      );
    }

    final everyUnit = _recurrenceEveryUnit.firstMatch(text);
    if (everyUnit != null) {
      final rawInterval = everyUnit.group(1)?.toLowerCase();
      final interval = rawInterval == null
          ? 1
          : (rawInterval == 'other' ? 2 : int.parse(rawInterval));
      final unit = everyUnit.group(2)!.toLowerCase();
      final rule = switch (unit) {
        'day' => RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          interval: interval,
        ),
        'week' => RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: interval,
        ),
        'month' => RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
          interval: interval,
        ),
        'year' => RecurrenceRule(
          frequency: RecurrenceFrequency.yearly,
          interval: interval,
        ),
        'weekday' => const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          byWeekday: <int>[1, 2, 3, 4, 5],
        ),
        _ => const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          byWeekday: <int>[6, 7],
        ),
      };
      return Extraction<RecurrenceRule>(
        rule,
        Span(everyUnit.start, everyUnit.end),
        text: everyUnit.group(0),
      );
    }

    final adverb = _recurrenceAdverb.firstMatch(text);
    if (adverb != null) {
      final word = adverb.group(1)!.toLowerCase();
      final rule = switch (word) {
        'daily' => const RecurrenceRule(frequency: RecurrenceFrequency.daily),
        'weekly' => const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
        'fortnightly' => const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
        ),
        'monthly' => const RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
        ),
        _ => const RecurrenceRule(frequency: RecurrenceFrequency.yearly),
      };
      return Extraction<RecurrenceRule>(
        rule,
        Span(adverb.start, adverb.end),
        text: adverb.group(0),
      );
    }

    return null;
  }

  Extraction<int>? findDuration(String text) {
    final match = _duration.firstMatch(text);
    if (match == null) return null;
    final amount = int.parse(match.group(1)!);
    final unit = match.group(2)!.toLowerCase();
    final minutes = unit.startsWith('h') ? amount * 60 : amount;
    if (minutes <= 0 || minutes > 60 * 24) return null;
    return Extraction<int>(
      minutes,
      Span(match.start, match.end),
      text: match.group(0),
    );
  }

  Extraction<TaskPriority>? findPriority(String text) {
    final bang = _bangPriority.firstMatch(text);
    if (bang != null) {
      final level = bang.group(1)!.length;
      final priority = switch (level) {
        1 => TaskPriority.low,
        2 => TaskPriority.medium,
        _ => TaskPriority.high,
      };
      return Extraction<TaskPriority>(
        priority,
        Span(bang.start, bang.end),
        text: bang.group(1),
      );
    }

    final high = _highPriorityWord.firstMatch(text);
    if (high != null) {
      return Extraction<TaskPriority>(
        TaskPriority.high,
        Span(high.start, high.end),
        text: high.group(0),
      );
    }

    final low = _lowPriorityWord.firstMatch(text);
    if (low != null) {
      return Extraction<TaskPriority>(
        TaskPriority.low,
        Span(low.start, low.end),
        text: low.group(0),
      );
    }

    return null;
  }

  List<Extraction<String>> findTags(String text) {
    return _tag
        .allMatches(text)
        .map(
          (match) => Extraction<String>(
            match.group(1)!,
            Span(match.start, match.end),
            text: match.group(1),
          ),
        )
        .toList();
  }

  /// Strips "remind me to", "I need to", and friends from the front of a
  /// title. Returns the text unchanged when nothing matches.
  String stripLeadingFiller(String text) =>
      text.replaceFirst(_leadingFiller, '');

  static int _applyMeridiem(int hour, String meridiem) {
    if (meridiem == 'am') return hour == 12 ? 0 : hour;
    return hour == 12 ? 12 : hour + 12;
  }

  /// Picks the year for a date given without one: this year if it has not
  /// passed, otherwise next year.
  static int _yearFor(int month, int day, DateTime reference) {
    final thisYear = DateTime(reference.year, month, day);
    final referenceDay = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    return thisYear.isBefore(referenceDay)
        ? reference.year + 1
        : reference.year;
  }

  static bool _isValidDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return false;
    final lastDay = DateTime(year, month + 1, 0).day;
    return day <= lastDay;
  }
}
