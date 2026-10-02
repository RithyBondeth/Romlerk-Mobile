import 'package:flutter_test/flutter_test.dart';

import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/local_ai/deterministic/deterministic_parser.dart';
import 'package:romlerk_mobile/local_ai/local_ai.dart';

void main() {
  group('Khmer Natural Language Task Parsing', () {
    final parser = DeterministicTaskParser();
    final now = DateTime(2026, 8, 10, 14, 30); // Monday, 10 August 2026

    Future<TaskDraft> parseOne(String text) async {
      final result = await parser.parseTasks(
        TaskParseRequest(
          requestId: 'test-km',
          text: text,
          referenceNow: now,
          timezone: 'Asia/Phnom_Penh',
          locale: 'km-KH',
        ),
      );
      expect(result.drafts, hasLength(1));
      return result.drafts.first;
    }

    test('parses Khmer relative dates', () async {
      final draft = await parseOne('រំលឹកខ្ញុំទិញទឹកដោះគោស្អែកម៉ោង ៩am');
      expect(draft.dueAt, equals(DateTime(2026, 8, 11, 9, 0)));
      // The title stays in Khmer; only the "remind me" filler is dropped,
      // as "remind me to" is in English.
      expect(draft.title, equals('ទិញទឹកដោះគោ'));
    });

    test('keeps a word that merely begins like a filler', () async {
      // ត្រូវការ ("need") starts with ត្រូវ ("must") but is not filler.
      final draft = await parseOne('ត្រូវការថ្នាំស្អែក');
      expect(draft.title, equals('ត្រូវការថ្នាំ'));
    });

    test('parses Khmer numerals (០-៩) and clock time', () async {
      final draft = await parseOne('ទិញទឹកដោះគោស្អែកម៉ោង ៩:៣០');
      expect(draft.dueAt, equals(DateTime(2026, 8, 11, 9, 30)));
    });

    test('parses Khmer weekday names', () async {
      final draft = await parseOne('ប្រជុំថ្ងៃសុក្រម៉ោង ១៤:០០');
      expect(draft.dueAt?.weekday, equals(DateTime.friday));
      expect(draft.dueAt, equals(DateTime(2026, 8, 14, 14, 0)));
    });

    test('parses Khmer recurrence (រៀងរាល់ថ្ងៃ)', () async {
      final draft = await parseOne('រៀងរាល់ថ្ងៃរំលឹកខ្ញុំធ្វើលំហាត់ប្រាណ');
      expect(draft.recurrence, isNotNull);
    });
  });

  group('Khmer clock times', () {
    final parser = DeterministicTaskParser();
    final now = DateTime(2026, 8, 10, 14, 30); // Monday, 10 August 2026

    Future<TaskParseResult> parse(String text) => parser.parseTasks(
      TaskParseRequest(
        requestId: 'test-km',
        text: text,
        referenceNow: now,
        timezone: 'Asia/Phnom_Penh',
        locale: 'km-KH',
      ),
    );

    Future<TaskDraft> parseOne(String text) async {
      final result = await parse(text);
      expect(result.drafts, hasLength(1), reason: text);
      return result.drafts.single;
    }

    test('reads កន្លះ as half past', () async {
      final draft = await parseOne('ទិញបាយស្អែកម៉ោង៩កន្លះព្រឹក');
      expect(draft.dueAt, DateTime(2026, 8, 11, 9, 30));
      expect(draft.title, 'ទិញបាយ');
      expect(draft.ambiguities, isEmpty);
    });

    test('reads "និង ១៥ នាទី" as minutes, not a duration', () async {
      final draft = await parseOne('ប្រជុំស្អែកម៉ោង ៣ និង ១៥ នាទីរសៀល');
      expect(draft.dueAt, DateTime(2026, 8, 11, 15, 15));
      expect(draft.durationMinutes, isNull);
      expect(draft.title, 'ប្រជុំ');
    });

    test('asks AM or PM for a bare hour, keeping the minutes', () async {
      final draft = await parseOne('ប្រជុំម៉ោង ៣ និង ១៥ នាទី');
      expect(draft.title, 'ប្រជុំ');
      final question = draft.ambiguities.single;
      expect(question.field, DraftField.dueAt);
      expect(
        question.alternatives.map((alt) => (alt.dateTime!.hour, alt.dateTime!.minute)),
        <(int, int)>[(3, 15), (15, 15)],
      );
    });

    test('reads a part of day without ម៉ោង', () async {
      final draft = await parseOne('ទិញបាយស្អែក ៩ព្រឹក');
      expect(draft.dueAt, DateTime(2026, 8, 11, 9));
      expect(draft.title, 'ទិញបាយ');
      expect(draft.ambiguities, isEmpty);
    });

    test('reads a part of day before the clock time', () async {
      final draft = await parseOne('ល្ងាចនេះម៉ោង ៦ ហៅម៉ាក់');
      expect(draft.dueAt, DateTime(2026, 8, 10, 18));
      expect(draft.title, 'ហៅម៉ាក់');
      expect(draft.ambiguities, isEmpty);
    });

    test('ល្ងាចនេះ on its own is this evening, not 9 AM', () async {
      final draft = await parseOne('ទៅហាងនៅល្ងាចនេះ');
      expect(draft.dueAt, DateTime(2026, 8, 10, 17));
      expect(draft.title, 'ទៅហាង');
    });

    test('ម៉ោង ១២ យប់ is midnight', () async {
      final draft = await parseOne('ដាក់សាកទូរស័ព្ទម៉ោង១២យប់');
      expect(draft.dueAt, DateTime(2026, 8, 11, 0));
    });

    test('a number before ម៉ោង is a duration, not a clock time', () async {
      final draft = await parseOne('ធ្វើការ ២ម៉ោង ៥ល្ងាច');
      expect(draft.dueAt, DateTime(2026, 8, 10, 17));
      expect(draft.durationMinutes, 120);
      expect(draft.title, 'ធ្វើការ');
    });

    test('"៣០នាទីទៀត" moves the clock', () async {
      final draft = await parseOne('ហៅម៉ាក់ ៣០នាទីទៀត');
      expect(draft.dueAt, DateTime(2026, 8, 10, 15));
      expect(draft.title, 'ហៅម៉ាក់');
    });
  });

  group('Khmer dates', () {
    final parser = DeterministicTaskParser();
    final now = DateTime(2026, 8, 10, 14, 30); // Monday, 10 August 2026

    Future<TaskDraft> parseOne(String text) async {
      final result = await parser.parseTasks(
        TaskParseRequest(
          requestId: 'test-km',
          text: text,
          referenceNow: now,
          timezone: 'Asia/Phnom_Penh',
          locale: 'km-KH',
        ),
      );
      expect(result.drafts, hasLength(1), reason: text);
      return result.drafts.single;
    }

    Future<void> expectDate(String text, DateTime date, {String? title}) async {
      final draft = await parseOne(text);
      expect(
        draft.dueAt == null
            ? null
            : DateTime(draft.dueAt!.year, draft.dueAt!.month, draft.dueAt!.day),
        date,
        reason: text,
      );
      if (title != null) expect(draft.title, title, reason: text);
    }

    test('day of the month', () async {
      await expectDate('បង់ថ្លៃផ្ទះថ្ងៃទី១៥', DateTime(2026, 8, 15), title: 'បង់ថ្លៃផ្ទះ');
      // The 5th has passed this month, so it is next month's.
      await expectDate('បង់ថ្លៃផ្ទះថ្ងៃទី៥', DateTime(2026, 9, 5));
      await expectDate('បង់ថ្លៃផ្ទះថ្ងៃទី៥ ខែក្រោយ', DateTime(2026, 9, 5));
    });

    test('day and month', () async {
      await expectDate('បង់ថ្លៃផ្ទះ ១៥ កញ្ញា', DateTime(2026, 9, 15), title: 'បង់ថ្លៃផ្ទះ');
      await expectDate('ប្រជុំថ្ងៃទី១៥ ខែកញ្ញា', DateTime(2026, 9, 15), title: 'ប្រជុំ');
      await expectDate('ប្រជុំថ្ងៃទី២០ ខែ៩', DateTime(2026, 9, 20), title: 'ប្រជុំ');
      // Already past this year, so next year.
      await expectDate('ប្រជុំថ្ងៃទី១ ខែមករា', DateTime(2027, 1, 1));
      await expectDate('ប្រជុំ ១៥ កញ្ញា ២០២៧', DateTime(2027, 9, 15));
    });

    test('តុលាការ ("court") is not October', () async {
      await expectDate('ទៅតុលាការថ្ងៃទី២០', DateTime(2026, 8, 20), title: 'ទៅតុលាការ');
    });

    test('in N days, weeks, months', () async {
      await expectDate('ទៅពេទ្យ ៣ថ្ងៃទៀត', DateTime(2026, 8, 13), title: 'ទៅពេទ្យ');
      await expectDate('ទៅពេទ្យ ២សប្ដាហ៍ទៀត', DateTime(2026, 8, 24));
      // The same word typed with subscript ត instead of ដ.
      await expectDate('ទៅពេទ្យ ២សប្តាហ៍ទៀត', DateTime(2026, 8, 24));
      await expectDate('ទៅពេទ្យ ២អាទិត្យទៀត', DateTime(2026, 8, 24));
      await expectDate('ទៅពេទ្យ ៦ខែទៀត', DateTime(2027, 2, 10));
    });

    test('next week, weekend, next month, end of month', () async {
      await expectDate('ទៅពេទ្យសប្ដាហ៍ក្រោយ', DateTime(2026, 8, 17), title: 'ទៅពេទ្យ');
      await expectDate('ទៅពេទ្យអាទិត្យក្រោយ', DateTime(2026, 8, 17), title: 'ទៅពេទ្យ');
      await expectDate('ប្រជុំចុងសប្ដាហ៍', DateTime(2026, 8, 15), title: 'ប្រជុំ');
      await expectDate('ប្រជុំចុងសប្ដាហ៍ក្រោយ', DateTime(2026, 8, 22), title: 'ប្រជុំ');
      await expectDate('បង់ថ្លៃទឹកខែក្រោយ', DateTime(2026, 9, 1), title: 'បង់ថ្លៃទឹក');
      await expectDate('ផ្ញើរបាយការណ៍ចុងខែ', DateTime(2026, 8, 31), title: 'ផ្ញើរបាយការណ៍');
    });

    test('a weekday with a qualifier leaves nothing behind', () async {
      await expectDate('ប្រជុំថ្ងៃច័ន្ទក្រោយ', DateTime(2026, 8, 17), title: 'ប្រជុំ');
      await expectDate('ប្រជុំច័ន្ទក្រោយ', DateTime(2026, 8, 17), title: 'ប្រជុំ');
      await expectDate('ប្រជុំនៅថ្ងៃសុក្រ', DateTime(2026, 8, 14), title: 'ប្រជុំ');
    });

    test('ច័ន្ទ on its own is the moon, not Monday', () async {
      final draft = await parseOne('ថតរូបព្រះច័ន្ទ');
      expect(draft.dueAt, isNull);
      expect(draft.title, 'ថតរូបព្រះច័ន្ទ');
    });

    test('ignores zero-width spaces from the keyboard', () async {
      await expectDate('ទិញ​បាយ​ស្អែក', DateTime(2026, 8, 11), title: 'ទិញបាយ');
    });

    test('a phrase outside the grammar stays in the title, undated', () async {
      final draft = await parseOne('ទៅលេងផ្ទះយាយពេលណាទំនេរ');
      expect(draft.dueAt, isNull);
      expect(draft.title, 'ទៅលេងផ្ទះយាយពេលណាទំនេរ');
    });
  });

  group('Khmer recurrence, duration, priority', () {
    final parser = DeterministicTaskParser();
    final now = DateTime(2026, 8, 10, 14, 30); // Monday, 10 August 2026

    Future<TaskDraft> parseOne(String text) async {
      final result = await parser.parseTasks(
        TaskParseRequest(
          requestId: 'test-km',
          text: text,
          referenceNow: now,
          timezone: 'Asia/Phnom_Penh',
          locale: 'km-KH',
        ),
      );
      expect(result.drafts, hasLength(1), reason: text);
      return result.drafts.single;
    }

    test('monthly and yearly', () async {
      final monthly = await parseOne('បង់ថ្លៃទឹករៀងរាល់ខែ');
      expect(monthly.recurrence?.frequency, RecurrenceFrequency.monthly);
      expect(monthly.title, 'បង់ថ្លៃទឹក');

      final yearly = await parseOne('បង់ពន្ធប្រចាំឆ្នាំ');
      expect(yearly.recurrence?.frequency, RecurrenceFrequency.yearly);
      expect(yearly.title, 'បង់ពន្ធ');
    });

    test('monthly on a day starts on that day', () async {
      final draft = await parseOne('បង់ថ្លៃផ្ទះរៀងរាល់ថ្ងៃទី៥');
      expect(draft.recurrence?.frequency, RecurrenceFrequency.monthly);
      expect(draft.dueAt, DateTime(2026, 9, 5, 9));
      expect(draft.title, 'បង់ថ្លៃផ្ទះ');
    });

    test('several weekdays', () async {
      final draft = await parseOne('ហាត់ប្រាណរៀងរាល់ថ្ងៃច័ន្ទ និង ថ្ងៃពុធ');
      expect(draft.recurrence?.frequency, RecurrenceFrequency.weekly);
      expect(draft.recurrence?.byWeekday, <int>[1, 3]);
      expect(draft.title, 'ហាត់ប្រាណ');
    });

    test('working days', () async {
      final draft = await parseOne('ដាស់តឿនខ្លួនឯងរៀងរាល់ថ្ងៃធ្វើការ ម៉ោង ៧ ព្រឹក');
      expect(draft.recurrence?.byWeekday, <int>[1, 2, 3, 4, 5]);
      expect(draft.dueAt, DateTime(2026, 8, 11, 7));
    });

    test('every N days', () async {
      final draft = await parseOne('លេបថ្នាំ ២ថ្ងៃម្ដង');
      expect(draft.recurrence?.frequency, RecurrenceFrequency.daily);
      expect(draft.recurrence?.interval, 2);
      expect(draft.title, 'លេបថ្នាំ');
    });

    test('durations', () async {
      final minutes = await parseOne('អានសៀវភៅ ៣០នាទី');
      expect(minutes.durationMinutes, 30);
      expect(minutes.title, 'អានសៀវភៅ');

      final hours = await parseOne('រៀនភាសាអង់គ្លេស ២ម៉ោងកន្លះ');
      expect(hours.durationMinutes, 150);
    });

    test('a negated urgency word is low priority, not high', () async {
      final low = await parseOne('ផ្ញើរបាយការណ៍ មិនបន្ទាន់');
      expect(low.priority, TaskPriority.low);
      expect(low.title, 'ផ្ញើរបាយការណ៍');

      final high = await parseOne('ផ្ញើរបាយការណ៍ ប្រញាប់ប្រញាល់');
      expect(high.priority, TaskPriority.high);
      expect(high.title, 'ផ្ញើរបាយការណ៍');
    });

    test('"later" asks for a time instead of guessing', () async {
      final draft = await parseOne('ហៅម៉ាក់ពេលក្រោយ');
      expect(draft.dueAt, isNull);
      expect(draft.ambiguities.single.code, DraftAmbiguity.vagueTimeCode);
      expect(draft.title, 'ហៅម៉ាក់');
    });
  });

  group('Khmer multi-task splitting', () {
    final parser = DeterministicTaskParser();
    final now = DateTime(2026, 8, 10, 14, 30);

    Future<List<TaskDraft>> parse(String text) async => (await parser.parseTasks(
      TaskParseRequest(
        requestId: 'test-km',
        text: text,
        referenceNow: now,
        timezone: 'Asia/Phnom_Penh',
        locale: 'km-KH',
      ),
    )).drafts;

    test('splits on ហើយ before a verb, with or without spaces', () async {
      final spaced = await parse('ទិញបាយ ហើយហៅទូរស័ព្ទទៅម៉ាក់ស្អែក');
      expect(spaced.map((d) => d.title), <String>['ទិញបាយ', 'ហៅទូរស័ព្ទទៅម៉ាក់']);
      expect(spaced.last.dueAt, DateTime(2026, 8, 11, 9));

      final unspaced = await parse('ទិញបាយហើយហៅម៉ាក់');
      expect(unspaced.map((d) => d.title), <String>['ទិញបាយ', 'ហៅម៉ាក់']);
    });

    test('splits on រួច and through a filler', () async {
      final drafts = await parse('បោកខោអាវរួចត្រូវទៅផ្សារ');
      expect(drafts.map((d) => d.title), <String>['បោកខោអាវ', 'ទៅផ្សារ']);
    });

    test('does not split a list of things', () async {
      final drafts = await parse('ទិញបាយនិងទឹក');
      expect(drafts.single.title, 'ទិញបាយនិងទឹក');
    });
  });
}
