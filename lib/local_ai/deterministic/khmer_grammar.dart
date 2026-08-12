import '../../domain/entities/recurrence_rule.dart';
import '../../domain/enums.dart';
import 'grammar.dart';

/// Khmer Natural Language Grammar & Translation Engine for Romlerk.
///
/// Converts Khmer natural language inputs and Khmer numerals (០-៩) into
/// structured dates, times, recurrences, priorities, and translated titles.
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

  /// Common Khmer filler phrases to strip from task titles.
  static final RegExp _leadingKhmerFiller = RegExp(
    r'^\s*(?:សូម\s+)?(?:រំលឹកខ្ញុំឲ្យ|រំលឹកខ្ញុំ|រំលឹក|ត្រូវតែ|ត្រូវ|កុំភ្លេច|សូមធ្វើ|កុំភ្លេចធ្វើ)\s+',
  );

  /// Converts any Khmer numerals (០-៩) to standard ASCII digits (0-9).
  String normalizeKhmerDigits(String input) {
    var result = input;
    _khmerDigits.forEach((khmer, ascii) {
      result = result.replaceAll(khmer, ascii);
    });
    return result;
  }

  /// Detects if text contains Khmer Unicode characters (\u1780-\u17FF).
  bool containsKhmer(String text) {
    return RegExp(r'[\u1780-\u17FF]').hasMatch(text);
  }

  /// Finds relative and weekday date expressions in Khmer text.
  Extraction<DateOnly>? findKhmerDate(String text, DateTime reference) {
    final normalized = normalizeKhmerDigits(text);

    // 1. Relative day expressions
    final relativeMatch = RegExp(r'(ខានស្អែក|ថ្ងៃស្អែក|ស្អែក|ថ្ងៃនេះ|យប់នេះ)').firstMatch(normalized);
    if (relativeMatch != null) {
      final phrase = relativeMatch.group(1)!;
      final offset = switch (phrase) {
        'ថ្ងៃនេះ' || 'យប់នេះ' => 0,
        'ថ្ងៃស្អែក' || 'ស្អែក' => 1,
        'ខានស្អែក' => 2,
        _ => 0,
      };
      final date = DateTime(reference.year, reference.month, reference.day + offset);
      return Extraction<DateOnly>(
        DateOnly(date.year, date.month, date.day),
        Span(relativeMatch.start, relativeMatch.end),
        text: relativeMatch.group(0),
      );
    }

    // 2. Weekday expressions (e.g. ថ្ងៃច័ន្ទ, ថ្ងៃសុក្រ)
    for (final entry in _khmerWeekdays.entries) {
      final weekdayRegex = RegExp('(?:ថ្ងៃ\s*)?${entry.key}');
      final match = weekdayRegex.firstMatch(normalized);
      if (match != null) {
        final target = entry.value;
        var delta = (target - reference.weekday) % 7;
        if (delta == 0) delta = 7;
        final date = DateTime(reference.year, reference.month, reference.day + delta);
        return Extraction<DateOnly>(
          DateOnly(date.year, date.month, date.day),
          Span(match.start, match.end),
          text: match.group(0),
        );
      }
    }

    return null;
  }

  /// Finds clock time and part of day in Khmer text.
  Extraction<TimeOfDayValue>? findKhmerTime(String text, {List<Span> excluded = const <Span>[]}) {
    final normalized = normalizeKhmerDigits(text);

    // Clock time: ម៉ោង 9:30 or ម៉ោង 9 / ម៉ោង ៩
    final clockMatch = RegExp(r'ម៉ោង\s*(\d{1,2})(?::(\d{2}))?\s*(ព្រឹក|ល្ងាច|រសៀល|យប់)?').firstMatch(normalized);
    if (clockMatch != null) {
      var hour = int.parse(clockMatch.group(1)!);
      final minute = int.parse(clockMatch.group(2) ?? '0');
      final period = clockMatch.group(3);

      if (period == 'ល្ងាច' || period == 'រសៀល' || period == 'យប់') {
        if (hour < 12) hour += 12;
      } else if (period == 'ព្រឹក') {
        if (hour == 12) hour = 0;
      }

      return Extraction<TimeOfDayValue>(
        TimeOfDayValue(hour, minute, meridiemStated: period != null || hour >= 13),
        Span(clockMatch.start, clockMatch.end),
        text: clockMatch.group(0),
      );
    }

    // Part of day standalone (ព្រឹក = 9am, ល្ងាច = 2pm, យប់ = 7pm)
    final partMatch = RegExp(r'(ព្រឹក|ល្ងាច|រសៀល|យប់)').firstMatch(normalized);
    if (partMatch != null) {
      final word = partMatch.group(1)!;
      final hour = switch (word) {
        'ព្រឹក' => 9,
        'រសៀល' => 14,
        'ល្ងាច' => 17,
        'យប់' => 19,
        _ => 9,
      };
      return Extraction<TimeOfDayValue>(
        TimeOfDayValue(hour, 0, approximate: true),
        Span(partMatch.start, partMatch.end),
        text: partMatch.group(0),
      );
    }

    return null;
  }

  /// Finds recurrence patterns in Khmer text (e.g. រៀងរាល់ថ្ងៃច័ន្ទ, រៀងរាល់ថ្ងៃ).
  Extraction<RecurrenceRule>? findKhmerRecurrence(String text) {
    final normalized = normalizeKhmerDigits(text);

    // Every weekday: រៀងរាល់ថ្ងៃច័ន្ទ
    for (final entry in _khmerWeekdays.entries) {
      final match = RegExp('(?:រៀងរាល់|រាល់)\s*(?:ថ្ងៃ\s*)?${entry.key}').firstMatch(normalized);
      if (match != null) {
        return Extraction<RecurrenceRule>(
          RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>[entry.value],
          ),
          Span(match.start, match.end),
          text: match.group(0),
        );
      }
    }

    // Daily / Every day: រៀងរាល់ថ្ងៃ
    final dailyMatch = RegExp(r'(?:រៀងរាល់|រាល់)\s*ថ្ងៃ').firstMatch(normalized);
    if (dailyMatch != null) {
      return Extraction<RecurrenceRule>(
        const RecurrenceRule(frequency: RecurrenceFrequency.daily),
        Span(dailyMatch.start, dailyMatch.end),
        text: dailyMatch.group(0),
      );
    }

    return null;
  }

  /// Finds high/low priority keywords in Khmer text.
  Extraction<TaskPriority>? findKhmerPriority(String text) {
    final match = RegExp(r'(បន្ទាន់|សំខាន់|ប្រញាប់|ប្រញាប់ប្រញាល់)').firstMatch(text);
    if (match != null) {
      return Extraction<TaskPriority>(
        TaskPriority.high,
        Span(match.start, match.end),
        text: match.group(0),
      );
    }
    return null;
  }

  /// Strips leading Khmer filler phrases ("រំលឹកខ្ញុំ", "ត្រូវ", etc.).
  String stripKhmerFiller(String text) {
    return text.replaceFirst(_leadingKhmerFiller, '').trim();
  }

  /// Translates common Khmer task phrases to clear English titles while preserving names.
  String translateKhmerTitleToEnglish(String khmerTitle) {
    var title = stripKhmerFiller(khmerTitle);

    // Common action verb dictionary mappings
    title = title
        .replaceAll(RegExp(r'^(?:ទិញ)\s*'), 'Buy ')
        .replaceAll(RegExp(r'^(?:ហៅ|ទូរស័ព្ទទៅ|ទូរស័ព្ទ)\s*'), 'Call ')
        .replaceAll(RegExp(r'^(?:ផ្ញើ)\s*'), 'Send ')
        .replaceAll(RegExp(r'^(?:ប្រជុំ|ប្រជុំជាមួយ)\s*'), 'Meeting with ')
        .replaceAll(RegExp(r'^(?:បង់|បង់ថ្លៃ)\s*'), 'Pay ')
        .replaceAll(RegExp(r'^(?:ធ្វើ)\s*'), 'Do ');

    // Specific noun dictionary mappings
    title = title
        .replaceAll('ទឹកដោះគោ', 'milk')
        .replaceAll('បាយ', 'rice/lunch')
        .replaceAll('ថ្លៃផ្ទះ', 'rent')
        .replaceAll('អគ្គិសនី', 'electricity bill')
        .replaceAll('របាយការណ៍', 'report');

    title = title.trim();
    if (title.isEmpty) return khmerTitle;
    return title[0].toUpperCase() + title.substring(1);
  }
}
