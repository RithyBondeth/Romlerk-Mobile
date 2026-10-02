import '../../domain/entities/recurrence_rule.dart';
import '../../domain/enums.dart';
import 'grammar.dart';

/// Khmer natural language grammar for Romlerk.
///
/// Converts Khmer natural language inputs and Khmer numerals (០-៩) into
/// structured dates, times, recurrences, and priorities. Titles are left in
/// Khmer.
///
/// Like the English grammar this is a supported *subset*, and it leans the
/// same way: a phrase it does not recognise stays in the title for the user to
/// fix, rather than being guessed into a date.
///
/// The finders expect text that has already been through [normalize], so
/// every span they return indexes the same string the title is built from.
class KhmerNaturalLanguageGrammar {
  const KhmerNaturalLanguageGrammar();

  static const Map<String, String> _khmerDigits = <String, String>{
    '០': '0',
    '១': '1',
    '២': '2',
    '៣': '3',
    '៤': '4',
    '៥': '5',
    '៦': '6',
    '៧': '7',
    '៨': '8',
    '៩': '9',
  };

  static const Map<String, int> _khmerWeekdays = <String, int>{
    'ច័ន្ទ': DateTime.monday,
    'អង្គារ': DateTime.tuesday,
    'ពុធ': DateTime.wednesday,
    'ព្រហស្បតិ៍': DateTime.thursday,
    'សុក្រ': DateTime.friday,
    'សៅរ៍': DateTime.saturday,
    'អាទិត្យ': DateTime.sunday,
  };

  /// Weekday names that are also everyday words (ច័ន្ទ is "moon", អាទិត្យ is
  /// "sun" and "week"), so they only count as a day when ថ្ងៃ comes first or
  /// a qualifier like ក្រោយ follows.
  static const Set<String> _weekdaysNeedingContext = <String>{
    'ច័ន្ទ',
    'អាទិត្យ',
  };

  /// Gregorian month names as used in Cambodia. កុម្ភៈ is also typed with
  /// ះ in place of ៈ, and ឧសភា with ឩ.
  static const Map<String, int> _khmerMonths = <String, int>{
    'មករា': 1,
    'កុម្ភៈ': 2,
    'កុម្ភះ': 2,
    'មីនា': 3,
    'មេសា': 4,
    'ឧសភា': 5,
    'ឩសភា': 5,
    'មិថុនា': 6,
    'កក្កដា': 7,
    'សីហា': 8,
    'កញ្ញា': 9,
    // Not តុលាការ ("court").
    'តុលា(?!ការ)': 10,
    'វិច្ឆិកា': 11,
    'ធ្នូ': 12,
  };

  /// Subscript ដ and subscript ត render identically, so words such as
  /// សប្ដាហ៍ and ម្ដង are typed both ways. Patterns accept either.
  static const String _coengDa = '្[ដត]';
  static const String _week = 'សប$_coengDaាហ៍';
  static const String _once = 'ម$_coengDaង';

  static const String _every = '(?:ជារៀងរាល់|រៀងរាល់|រាល់)';
  static const String _next = '(?:ខាងមុខ|ក្រោយ|មុខ)';
  static const String _periods = '(?:ព្រឹក|ថ្ងៃត្រង់|រសៀល|ល្ងាច|យប់)';

  /// Prepositions that belong to the date or time after them ("នៅស្អែក",
  /// "ត្រឹមថ្ងៃសុក្រ"), consumed with it so they do not dangle in the title.
  static const String _lead = '(?:(?:នៅ|ត្រឹម|មុន)\\s*)?';

  static final String _weekdayAlternation = _khmerWeekdays.keys.join('|');
  static final String _monthAlternation = _khmerMonths.keys.join('|');

  /// In ល្ងាចនេះ ("this evening") only នេះ is the date, so the time finder
  /// can still read ល្ងាច.
  static final RegExp _relativeDay = RegExp(
    '$_lead((?:ថ្ងៃ\\s*)?ខាន\\s*ស្អែក|(?:ថ្ងៃ\\s*)?ស្អែក|ថ្ងៃ\\s*នេះ|'
    '(?<=$_periods\\s*)នេះ)',
  );

  /// Not after ទី: ថ្ងៃទី៥ ខែក្រោយ is "the 5th of next month", not "in five
  /// months".
  static final RegExp _inNUnits = RegExp(
    '$_lead(?:ក្នុង(?:រយៈពេល)?\\s*)?(?<![\\d:]|ទី\\s?)(\\d{1,3})\\s*'
    '(ថ្ងៃ|$_week|អាទិត្យ|ខែ|ឆ្នាំ)\\s*(?:ទៀត|ក្រោយ|ខាងមុខ)',
  );

  static final RegExp _weekend = RegExp(
    '$_lead(?:ចុង\\s*(?:$_week|អាទិត្យ))(?:\\s*(នេះ|$_next))?',
  );

  /// "សប្ដាហ៍ក្រោយ" or a bare "អាទិត្យក្រោយ" is next week; with ថ្ងៃ in front
  /// it is next Sunday, which the weekday pattern handles.
  static final RegExp _nextWeek = RegExp(
    '$_lead(?:$_week|(?<!ថ្ងៃ\\s?)អាទិត្យ)\\s*$_next',
  );

  static final RegExp _nextMonth = RegExp('$_lead(?<!\\d\\s?)ខែ\\s*$_next');

  static final RegExp _endOfMonth = RegExp('$_lead(?:ចុង\\s*ខែ)(?:\\s*នេះ)?');

  static final RegExp _dayMonthName = RegExp(
    '$_lead(?:ថ្ងៃ\\s*(?:ទី\\s*)?)?(?<![\\d:])(\\d{1,2})\\s*(?:ខែ\\s*)?'
    '($_monthAlternation)(?:\\s*(?:ឆ្នាំ\\s*)?(\\d{4}))?',
  );

  static final RegExp _dayMonthNumber = RegExp(
    '$_leadថ្ងៃ\\s*ទី\\s*(\\d{1,2})\\s*ខែ\\s*(\\d{1,2})(?!\\d)'
    '(?:\\s*(?:ឆ្នាំ\\s*)?(\\d{4}))?',
  );

  static final RegExp _dayNextMonth = RegExp(
    '$_leadថ្ងៃ\\s*ទី\\s*(\\d{1,2})\\s*ខែ\\s*$_next',
  );

  /// Needs ថ្ងៃ: a bare ទី២ is just "second", as in ជាន់ទី២ ("2nd floor").
  static final RegExp _dayOfMonth = RegExp(
    '$_leadថ្ងៃ\\s*ទី\\s*(\\d{1,2})(?!\\d)',
  );

  static final RegExp _weekday = RegExp(
    '$_lead(ថ្ងៃ\\s*)?($_weekdayAlternation)(?:\\s*(នេះ|$_next))?',
  );

  /// ម៉ោង ៩, ម៉ោង ៩:៣០, ម៉ោង៩កន្លះ, ម៉ោង ៣ និង ១៥ នាទី, ម៉ោង ៦ ល្ងាច. A
  /// ម៉ោង straight after a number is a duration (២ម៉ោង, "two hours"), not a
  /// clock time.
  static final RegExp _clock = RegExp(
    '$_lead(?<!\\d\\s?)ម៉ោង\\s*(\\d{1,2})'
    '(?:\\s*[:.]\\s*(\\d{2})|\\s*(កន្លះ)|\\s*(?:និង\\s*)?(\\d{1,2})\\s*នាទី)?'
    '(?:\\s*(am|pm|$_periods))?',
    caseSensitive: false,
  );

  /// A part of day said before the clock time: ល្ងាចនេះម៉ោង ៦.
  static final RegExp _periodBeforeClock = RegExp(
    '$_lead($_periods)\\s*(?:នេះ\\s*)?\$',
  );

  /// ៩ព្រឹក, ៦:៣០ល្ងាច, ៧កន្លះយប់ — a number is only a time when a part of
  /// day follows it.
  static final RegExp _hourWithPeriod = RegExp(
    '$_lead(?<![\\d:])(\\d{1,2})(?:\\s*[:.]\\s*(\\d{2})|\\s*(កន្លះ))?\\s*'
    '($_periods)',
  );

  static final RegExp _partOfDay = RegExp('$_lead($_periods)');

  static final RegExp _relativeOffset = RegExp(
    '(?:ក្នុង(?:រយៈពេល)?\\s*)?(?<![\\d:])(\\d{1,3})\\s*(នាទី|ម៉ោង)'
    '(?:\\s*(កន្លះ))?\\s*(?:ទៀត|ក្រោយ)',
  );

  static final RegExp _duration = RegExp(
    '(?:(?:រយៈពេល|ចំណាយពេល|ប្រើពេល)\\s*)?(?<![\\d:])(\\d{1,4})\\s*'
    '(នាទី|ម៉ោង)(?:\\s*(កន្លះ))?',
  );

  static final RegExp _vagueTime = RegExp(
    '(នៅពេលក្រោយ|ពេលក្រោយ|បន្តិចទៀត|ឆាប់ៗនេះ|ឆាប់ៗ|ថ្ងៃណាមួយ|ពេលណាមួយ)',
  );

  static final RegExp _recurrenceInterval = RegExp(
    '(?:$_every\\s*)?(?<![\\d:])(\\d{1,3})\\s*(ថ្ងៃ|$_week|អាទិត្យ|ខែ|ឆ្នាំ)'
    '\\s*$_once',
  );

  static final RegExp _recurrenceWeekdays = RegExp(
    '$_every\\s*(?:ថ្ងៃ\\s*)?(?:$_weekdayAlternation)'
    '(?:\\s*(?:និង|,)?\\s*(?:ថ្ងៃ\\s*)?(?:$_weekdayAlternation))*',
  );

  static final RegExp _weekdayName = RegExp('($_weekdayAlternation)');

  /// ថ្ងៃធ្វើការ is "working day"; ថ្ងៃធ្វើការងារ reads as "every day, do
  /// work" and is left to the daily rule.
  static final RegExp _recurrenceWorkdays = RegExp(
    '$_every\\s*ថ្ងៃ\\s*ធ្វើការ(?!ងារ)',
  );

  static final RegExp _recurrenceWeekends = RegExp(
    '$_every\\s*ចុង\\s*(?:$_week|អាទិត្យ)',
  );

  /// រៀងរាល់ថ្ងៃទី១៥ repeats monthly. Only the "every" part is consumed, so
  /// the date pattern still reads ថ្ងៃទី១៥ as the first occurrence.
  static final RegExp _recurrenceMonthlyOnDay = RegExp(
    '$_every\\s*(?:ខែ\\s*)?(?=ថ្ងៃ\\s*ទី\\s*\\d)',
  );

  static final RegExp _recurrenceUnit = RegExp(
    '(?:$_every|ប្រចាំ)\\s*(ថ្ងៃ|$_week|ខែ|ឆ្នាំ)',
  );

  static final RegExp _lowPriority = RegExp(
    '(មិន\\s*(?:បន្ទាន់|សំខាន់|ប្រញាប់)|ពេល\\s*ទំនេរ)',
  );

  static final RegExp _highPriority = RegExp(
    '(ប្រញាប់ប្រញាល់|បន្ទាន់|សំខាន់ណាស់|សំខាន់|ប្រញាប់)',
  );

  /// Common Khmer filler phrases to strip from task titles.
  ///
  /// Khmer is written without spaces between words, so the unmistakable
  /// phrases match with no separator. Short ones that also begin ordinary
  /// words (ត្រូវ in ត្រូវការ, "need") still require a following space.
  static final RegExp _leadingKhmerFiller = RegExp(
    r'^\s*(?:សូម\s*)?(?:(?:រំលឹកខ្ញុំឲ្យ|រំលឹកខ្ញុំ|កុំភ្លេចធ្វើ|កុំភ្លេច|ត្រូវតែ)\s*|'
    r'(?:រំលឹក|ត្រូវ|សូមធ្វើ)\s+)',
  );

  /// Connectors left dangling once a date or time next to them is removed.
  /// Only stripped when whitespace separates them from the rest of the title.
  static final RegExp _danglingKhmer = RegExp(
    r'\s+(?:នៅ|ត្រឹម|និង|ហើយ|ម៉ោង|ថ្ងៃ)\s*$',
  );

  /// A filler the user may put between a connector and the next task, as in
  /// "…ហើយត្រូវហៅម៉ាក់".
  static final RegExp _fillerBeforeVerb = RegExp(
    r'^\s*(?:សូម\s*)?(?:ត្រូវតែ|ត្រូវ|កុំភ្លេច|រំលឹកខ្ញុំឲ្យ|រំលឹកខ្ញុំ)?\s*',
  );

  /// Verbs that start a new task after ហើយ / និង / រួច. Splitting only on
  /// these keeps "ទិញបាយនិងទឹក" ("buy rice and water") as one task.
  static const List<String> actionVerbPrefixes = <String>[
    'ទិញ', // buy
    'ហៅ', // call
    'ទូរស័ព្ទ', // phone
    'តេ', // ring (colloquial)
    'ផ្ញើ', // send
    'ប្រជុំ', // meet
    'ជួប', // meet up with
    'ធ្វើ', // do
    'បង់', // pay
    'ទៅ', // go
    'រៀន', // study
    'អាន', // read
    'សរសេរ', // write
    'បោក', // wash (clothes)
    'លាង', // wash
    'សម្អាត', // clean
    'ចម្អិន', // cook
    'ដាំ', // cook rice, plant
    'យក', // take, fetch
    'ទទួល', // receive, pick up
    'កក់', // book
    'ពិនិត្យ', // check
    'ឆែក', // check (colloquial)
    'រៀបចំ', // prepare
    'ត្រៀម', // get ready
    'បញ្ចប់', // finish
    'ផ្ទេរ', // transfer
    'ដក', // withdraw
    'ជួសជុល', // repair
    'ហាត់', // practise, exercise
    'លេប', // take (medicine)
    'សួរ', // ask
    'ប្រាប់', // tell
    'ឆ្លើយ', // answer
    'បោះពុម្ព', // print
    'ចុះឈ្មោះ', // register
    'រំលឹក', // remind
  ];

  /// Digits to ASCII and zero-width spaces removed — the only form the
  /// finders read. Many Khmer keyboards insert U+200B between words.
  String normalize(String input) =>
      normalizeKhmerDigits(input).replaceAll('​', '');

  /// Converts any Khmer numerals (០-៩) to standard ASCII digits (0-9).
  ///
  /// Length-preserving, so spans found in the result index the input too.
  String normalizeKhmerDigits(String input) {
    var result = input;
    _khmerDigits.forEach((khmer, ascii) {
      result = result.replaceAll(khmer, ascii);
    });
    return result;
  }

  /// Detects if text contains Khmer Unicode characters (ក-៿).
  bool containsKhmer(String text) {
    return RegExp(r'[ក-៿]').hasMatch(text);
  }

  /// Whether [text] begins a new task: an optional filler, then a known verb.
  bool startsWithKhmerAction(String text) {
    final rest = text.replaceFirst(_fillerBeforeVerb, '');
    return actionVerbPrefixes.any(rest.startsWith);
  }

  // ------------------------------------------------------------------ dates

  /// Finds a relative or absolute date in Khmer text.
  Extraction<DateOnly>? findKhmerDate(String text, DateTime reference) {
    final normalized = normalizeKhmerDigits(text);

    Extraction<DateOnly> found(Match match, DateTime date) =>
        Extraction<DateOnly>(
          DateOnly(date.year, date.month, date.day),
          Span(match.start, match.end),
          text: match.group(0),
        );

    // ស្អែក, ខានស្អែក, ថ្ងៃនេះ, ល្ងាចនេះ
    final relative = _relativeDay.firstMatch(normalized);
    if (relative != null) {
      final phrase = relative.group(1)!;
      final offset = phrase.contains('ខាន')
          ? 2
          : phrase.contains('ស្អែក')
          ? 1
          : 0;
      return found(
        relative,
        DateTime(reference.year, reference.month, reference.day + offset),
      );
    }

    // ៣ថ្ងៃទៀត, ២សប្ដាហ៍ទៀត, ៦ខែទៀត
    final inUnits = _inNUnits.firstMatch(normalized);
    if (inUnits != null) {
      final amount = int.parse(inUnits.group(1)!);
      final unit = inUnits.group(2)!;
      final date = switch (unit) {
        'ថ្ងៃ' => DateTime(
          reference.year,
          reference.month,
          reference.day + amount,
        ),
        'ខែ' => DateTime(
          reference.year,
          reference.month + amount,
          reference.day,
        ),
        'ឆ្នាំ' => DateTime(
          reference.year + amount,
          reference.month,
          reference.day,
        ),
        // សប្ដាហ៍ in either spelling, or អាទិត្យ as "week".
        _ => DateTime(
          reference.year,
          reference.month,
          reference.day + 7 * amount,
        ),
      };
      return found(inUnits, date);
    }

    // ចុងសប្ដាហ៍ — checked before "next week", which it contains.
    final weekend = _weekend.firstMatch(normalized);
    if (weekend != null) {
      var delta = (DateTime.saturday - reference.weekday) % 7;
      if (delta == 0) delta = 7;
      final qualifier = weekend.group(1);
      if (qualifier != null && qualifier != 'នេះ') delta += 7;
      return found(
        weekend,
        DateTime(reference.year, reference.month, reference.day + delta),
      );
    }

    // សប្ដាហ៍ក្រោយ: Monday of the following week, as in English.
    final nextWeek = _nextWeek.firstMatch(normalized);
    if (nextWeek != null) {
      final toMonday = (DateTime.monday - reference.weekday) % 7;
      return found(
        nextWeek,
        DateTime(
          reference.year,
          reference.month,
          reference.day + (toMonday == 0 ? 7 : toMonday),
        ),
      );
    }

    // ថ្ងៃទី១៥ ខែកញ្ញា, ១៥ កញ្ញា ២០២៧
    final dayMonthName = _dayMonthName.firstMatch(normalized);
    if (dayMonthName != null) {
      final day = int.parse(dayMonthName.group(1)!);
      final month = _monthNumber(dayMonthName.group(2)!);
      final year =
          int.tryParse(dayMonthName.group(3) ?? '') ??
          _yearFor(month, day, reference);
      if (_isValidDate(year, month, day)) {
        return found(dayMonthName, DateTime(year, month, day));
      }
    }

    // ថ្ងៃទី១៥ ខែ៩
    final dayMonthNumber = _dayMonthNumber.firstMatch(normalized);
    if (dayMonthNumber != null) {
      final day = int.parse(dayMonthNumber.group(1)!);
      final month = int.parse(dayMonthNumber.group(2)!);
      final year =
          int.tryParse(dayMonthNumber.group(3) ?? '') ??
          _yearFor(month, day, reference);
      if (_isValidDate(year, month, day)) {
        return found(dayMonthNumber, DateTime(year, month, day));
      }
    }

    // ថ្ងៃទី៥ ខែក្រោយ
    final dayNextMonth = _dayNextMonth.firstMatch(normalized);
    if (dayNextMonth != null) {
      final day = int.parse(dayNextMonth.group(1)!);
      final first = DateTime(reference.year, reference.month + 1, 1);
      if (_isValidDate(first.year, first.month, day)) {
        return found(dayNextMonth, DateTime(first.year, first.month, day));
      }
    }

    // ថ្ងៃទី១៥: this month if still ahead, else the next month that has it.
    final dayOfMonth = _dayOfMonth.firstMatch(normalized);
    if (dayOfMonth != null) {
      final day = int.parse(dayOfMonth.group(1)!);
      for (var ahead = 0; ahead <= 2 && day >= 1 && day <= 31; ahead++) {
        final first = DateTime(reference.year, reference.month + ahead, 1);
        if (!_isValidDate(first.year, first.month, day)) continue;
        if (ahead == 0 && day < reference.day) continue;
        return found(dayOfMonth, DateTime(first.year, first.month, day));
      }
    }

    // ខែក្រោយ: the first of next month, as in English.
    final nextMonth = _nextMonth.firstMatch(normalized);
    if (nextMonth != null) {
      return found(nextMonth, DateTime(reference.year, reference.month + 1, 1));
    }

    // ចុងខែ: the last day of this month.
    final endOfMonth = _endOfMonth.firstMatch(normalized);
    if (endOfMonth != null) {
      return found(
        endOfMonth,
        DateTime(reference.year, reference.month + 1, 0),
      );
    }

    // ថ្ងៃសុក្រ, ច័ន្ទក្រោយ
    for (final match in _weekday.allMatches(normalized)) {
      final hasDayWord = match.group(1) != null;
      final name = match.group(2)!;
      final qualifier = match.group(3);
      if (_weekdaysNeedingContext.contains(name) &&
          !hasDayWord &&
          qualifier == null) {
        continue;
      }
      final target = _khmerWeekdays[name]!;
      // As in English: a qualified "next" weekday is that day in the
      // following Monday-start week; a bare or "this" one is the soonest.
      int delta;
      if (qualifier != null && qualifier != 'នេះ') {
        final toNextMonday = DateTime.daysPerWeek + 1 - reference.weekday;
        delta = toNextMonday + (target - DateTime.monday);
      } else {
        delta = (target - reference.weekday) % 7;
        if (delta == 0) delta = 7;
      }
      return found(
        match,
        DateTime(reference.year, reference.month, reference.day + delta),
      );
    }

    return null;
  }

  // ------------------------------------------------------------------ times

  /// Finds a clock time or part of day in Khmer text, skipping anything that
  /// overlaps [excluded] (a date already read from the same words).
  Extraction<TimeOfDayValue>? findKhmerTime(
    String text, {
    List<Span> excluded = const <Span>[],
  }) {
    final normalized = normalizeKhmerDigits(text);
    bool blocked(Match match) =>
        excluded.any((span) => span.overlaps(Span(match.start, match.end)));

    for (final match in _clock.allMatches(normalized)) {
      if (blocked(match)) continue;
      final hour = int.parse(match.group(1)!);
      final minute = match.group(3) != null
          ? 30
          : int.parse(match.group(2) ?? match.group(4) ?? '0');
      // The part of day may also come first. It can overlap a date (the
      // ល្ងាច of ល្ងាចនេះ), which is fine: both readings are true.
      final before = match.group(5) == null
          ? _periodBeforeClock.firstMatch(normalized.substring(0, match.start))
          : null;
      final period = (match.group(5) ?? before?.group(1))?.toLowerCase();
      final value = _clockValue(hour, minute, period);
      if (value == null) continue;
      final start = before?.start ?? match.start;
      return Extraction<TimeOfDayValue>(
        value,
        Span(start, match.end),
        text: normalized.substring(start, match.end),
      );
    }

    for (final match in _hourWithPeriod.allMatches(normalized)) {
      if (blocked(match)) continue;
      final hour = int.parse(match.group(1)!);
      final minute = match.group(3) != null
          ? 30
          : int.parse(match.group(2) ?? '0');
      final value = _clockValue(hour, minute, match.group(4));
      if (value == null) continue;
      return Extraction<TimeOfDayValue>(
        value,
        Span(match.start, match.end),
        text: match.group(0),
      );
    }

    for (final match in _partOfDay.allMatches(normalized)) {
      if (blocked(match)) continue;
      final value = switch (match.group(1)!) {
        'ថ្ងៃត្រង់' => const TimeOfDayValue(12, 0),
        'រសៀល' => const TimeOfDayValue(14, 0, approximate: true, untilHour: 17),
        'ល្ងាច' => const TimeOfDayValue(17, 0, approximate: true, untilHour: 19),
        'យប់' => const TimeOfDayValue(19, 0, approximate: true, untilHour: 23),
        _ => const TimeOfDayValue(9, 0, approximate: true, untilHour: 12),
      };
      return Extraction<TimeOfDayValue>(
        value,
        Span(match.start, match.end),
        text: match.group(0),
      );
    }

    return null;
  }

  /// Applies a part of day to a clock hour. Null for an impossible time.
  static TimeOfDayValue? _clockValue(int hour, int minute, String? period) {
    if (minute > 59) return null;
    if (period == null) {
      if (hour > 23) return null;
      // Like the English parser, a bare ម៉ោង ៣ asks rather than guesses.
      return TimeOfDayValue(
        hour,
        minute,
        meridiemStated: hour >= 13 || hour == 0,
      );
    }
    if (hour < 1 || hour > 12) return null;
    final resolved = switch (period) {
      'am' || 'ព្រឹក' => hour == 12 ? 0 : hour,
      // ម៉ោង ១២ យប់ is midnight; ម៉ោង ២ យប់ is the small hours.
      'យប់' => hour == 12 ? 0 : (hour <= 4 ? hour : hour + 12),
      // ថ្ងៃត្រង់ ("midday") covers late morning through early afternoon.
      'ថ្ងៃត្រង់' => hour <= 5 ? hour + 12 : hour,
      _ => hour == 12 ? 12 : hour + 12,
    };
    return TimeOfDayValue(resolved, minute);
  }

  /// "៣០នាទីទៀត" / "២ម៉ោងទៀត" — moves the clock rather than naming a day.
  Extraction<Duration>? findKhmerRelativeTimeOffset(String text) {
    final match = _relativeOffset.firstMatch(normalizeKhmerDigits(text));
    if (match == null) return null;
    final amount = int.parse(match.group(1)!);
    final half = match.group(3) != null;
    final duration = match.group(2) == 'ម៉ោង'
        ? Duration(minutes: amount * 60 + (half ? 30 : 0))
        : Duration(minutes: amount);
    if (duration == Duration.zero) return null;
    return Extraction<Duration>(
      duration,
      Span(match.start, match.end),
      text: match.group(0),
    );
  }

  /// "៣០នាទី", "២ម៉ោងកន្លះ", in minutes. Call after [findKhmerTime] with its
  /// span excluded, so the ១៥ នាទី in "ម៉ោង ៣ និង ១៥ នាទី" is not read twice.
  Extraction<int>? findKhmerDuration(
    String text, {
    List<Span> excluded = const <Span>[],
  }) {
    for (final match in _duration.allMatches(normalizeKhmerDigits(text))) {
      if (excluded.any((span) => span.overlaps(Span(match.start, match.end)))) {
        continue;
      }
      final amount = int.parse(match.group(1)!);
      final half = match.group(3) != null;
      final minutes = match.group(2) == 'ម៉ោង'
          ? amount * 60 + (half ? 30 : 0)
          : amount;
      if (minutes <= 0 || minutes > 60 * 24) continue;
      return Extraction<int>(
        minutes,
        Span(match.start, match.end),
        text: match.group(0),
      );
    }
    return null;
  }

  /// Words that gesture at a time without naming one (ពេលក្រោយ, "later").
  Extraction<String>? findKhmerVagueTime(String text) {
    final match = _vagueTime.firstMatch(text);
    if (match == null) return null;
    return Extraction<String>(
      match.group(1)!,
      Span(match.start, match.end),
      text: match.group(0),
    );
  }

  // ------------------------------------------------------------- recurrence

  /// Finds recurrence patterns in Khmer text (e.g. រៀងរាល់ថ្ងៃច័ន្ទ, រៀងរាល់ថ្ងៃ).
  Extraction<RecurrenceRule>? findKhmerRecurrence(String text) {
    final normalized = normalizeKhmerDigits(text);

    Extraction<RecurrenceRule> found(Match match, RecurrenceRule rule) =>
        Extraction<RecurrenceRule>(
          rule,
          Span(match.start, match.end),
          text: match.group(0),
        );

    // ២ថ្ងៃម្ដង — "once every two days"
    final interval = _recurrenceInterval.firstMatch(normalized);
    if (interval != null) {
      final amount = int.parse(interval.group(1)!);
      if (amount >= 1 && amount <= 365) {
        final frequency = switch (interval.group(2)!) {
          'ថ្ងៃ' => RecurrenceFrequency.daily,
          'ខែ' => RecurrenceFrequency.monthly,
          'ឆ្នាំ' => RecurrenceFrequency.yearly,
          _ => RecurrenceFrequency.weekly,
        };
        return found(
          interval,
          RecurrenceRule(frequency: frequency, interval: amount),
        );
      }
    }

    // រៀងរាល់ថ្ងៃច័ន្ទ និង ថ្ងៃពុធ
    final weekly = _recurrenceWeekdays.firstMatch(normalized);
    if (weekly != null) {
      final weekdays =
          _weekdayName
              .allMatches(weekly.group(0)!)
              .map((match) => _khmerWeekdays[match.group(1)!]!)
              .toSet()
              .toList()
            ..sort();
      return found(
        weekly,
        RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          byWeekday: weekdays,
        ),
      );
    }

    final workdays = _recurrenceWorkdays.firstMatch(normalized);
    if (workdays != null) {
      return found(
        workdays,
        const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          byWeekday: <int>[1, 2, 3, 4, 5],
        ),
      );
    }

    final weekends = _recurrenceWeekends.firstMatch(normalized);
    if (weekends != null) {
      return found(
        weekends,
        const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          byWeekday: <int>[6, 7],
        ),
      );
    }

    final monthlyOnDay = _recurrenceMonthlyOnDay.firstMatch(normalized);
    if (monthlyOnDay != null) {
      return found(
        monthlyOnDay,
        const RecurrenceRule(frequency: RecurrenceFrequency.monthly),
      );
    }

    // រៀងរាល់ថ្ងៃ, រៀងរាល់ខែ, ប្រចាំឆ្នាំ
    final unit = _recurrenceUnit.firstMatch(normalized);
    if (unit != null) {
      final frequency = switch (unit.group(1)!) {
        'ថ្ងៃ' => RecurrenceFrequency.daily,
        'ខែ' => RecurrenceFrequency.monthly,
        'ឆ្នាំ' => RecurrenceFrequency.yearly,
        _ => RecurrenceFrequency.weekly,
      };
      return found(unit, RecurrenceRule(frequency: frequency));
    }

    return null;
  }

  // ------------------------------------------------------------- priorities

  /// Finds priority keywords in Khmer text. A negated one (មិនបន្ទាន់, "not
  /// urgent") is low, not high.
  Extraction<TaskPriority>? findKhmerPriority(String text) {
    final low = _lowPriority.firstMatch(text);
    if (low != null) {
      return Extraction<TaskPriority>(
        TaskPriority.low,
        Span(low.start, low.end),
        text: low.group(0),
      );
    }
    final high = _highPriority.firstMatch(text);
    if (high != null) {
      return Extraction<TaskPriority>(
        TaskPriority.high,
        Span(high.start, high.end),
        text: high.group(0),
      );
    }
    return null;
  }

  // ------------------------------------------------------------------ title

  /// Strips leading Khmer filler phrases ("រំលឹកខ្ញុំ", "ត្រូវ", etc.).
  String stripKhmerFiller(String text) {
    final stripped = text.replaceFirst(_leadingKhmerFiller, '').trim();
    // Unspaced ត្រូវ is only a filler when a known verb follows it, so
    // ត្រូវទៅផ្សារ loses it but ត្រូវការថ្នាំ ("need medicine") does not.
    final unspaced = RegExp(r'^(?:ត្រូវតែ|ត្រូវ)').firstMatch(stripped);
    if (unspaced != null) {
      final rest = stripped.substring(unspaced.end);
      if (actionVerbPrefixes.any(rest.startsWith)) return rest;
    }
    return stripped;
  }

  /// Strips a connector left at the end once the words after it were read
  /// as a date or time.
  String stripDanglingKhmer(String text) =>
      text.replaceFirst(_danglingKhmer, '').trim();

  static int _monthNumber(String name) {
    for (final entry in _khmerMonths.entries) {
      if (RegExp('^(?:${entry.key})\$').hasMatch(name)) return entry.value;
    }
    throw ArgumentError.value(name, 'name', 'not a Khmer month');
  }

  /// This year if the date has not passed, otherwise next year.
  static int _yearFor(int month, int day, DateTime reference) {
    final thisYear = DateTime(reference.year, month, day);
    final today = DateTime(reference.year, reference.month, reference.day);
    return thisYear.isBefore(today) ? reference.year + 1 : reference.year;
  }

  static bool _isValidDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return false;
    return day <= DateTime(year, month + 1, 0).day;
  }
}
