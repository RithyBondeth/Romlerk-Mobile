import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/local_ai/deterministic/deterministic_parser.dart';
import 'package:romlerk_mobile/local_ai/local_ai.dart';
import 'package:romlerk_mobile/local_ai/local_ai_error.dart';

void main() {
  final parser = DeterministicTaskParser();

  // Monday, 10 August 2026 at 14:30 local. Every expectation below is
  // relative to this instant, never to the real clock.
  final now = DateTime(2026, 8, 10, 14, 30);

  Future<TaskParseResult> parse(String text, {DateTime? at}) {
    return parser.parseTasks(
      TaskParseRequest(
        requestId: 'test',
        text: text,
        referenceNow: at ?? now,
        timezone: 'Europe/Copenhagen',
        locale: 'en-GB',
      ),
    );
  }

  Future<TaskDraft> parseOne(String text, {DateTime? at}) async {
    final result = await parse(text, at: at);
    expect(result.drafts, hasLength(1), reason: 'expected a single draft');
    return result.drafts.single;
  }

  group('title extraction', () {
    test('strips the date phrase and leading filler', () async {
      final draft = await parseOne('Remind me to call David tomorrow at 9am');
      expect(draft.title, 'Call David');
      expect(draft.dueAt, DateTime(2026, 8, 11, 9));
    });

    test('keeps content words that look like nothing else', () async {
      final draft = await parseOne('Call David about the website');
      expect(draft.title, 'Call David about the website');
      expect(draft.dueAt, isNull);
    });

    test('drops a trailing preposition left behind by a date', () async {
      final draft = await parseOne('Submit the report by friday');
      expect(draft.title, 'Submit the report');
      expect(draft.dueAt!.weekday, DateTime.friday);
    });
  });

  group('date resolution', () {
    test('tomorrow resolves against the reference instant', () async {
      final draft = await parseOne('Pay rent tomorrow');
      expect(draft.dueAt, DateTime(2026, 8, 11, 9));
    });

    test('a bare weekday means the next upcoming one', () async {
      // Reference is a Monday, so "friday" is four days out.
      final draft = await parseOne('Team sync on friday at 10am');
      expect(draft.dueAt, DateTime(2026, 8, 14, 10));
    });

    test('"next friday" skips a week beyond the upcoming one', () async {
      final draft = await parseOne('Dentist next friday at 11am');
      expect(draft.dueAt, DateTime(2026, 8, 21, 11));
    });

    test('day-and-month with no year picks the coming occurrence', () async {
      final draft = await parseOne('Renew passport on 3 March at 9am');
      expect(draft.dueAt, DateTime(2027, 3, 3, 9));
    });

    test('"in 2 hours" offsets the clock rather than the calendar', () async {
      final draft = await parseOne('Take the bread out in 2 hours');
      expect(draft.dueAt, DateTime(2026, 8, 10, 16, 30));
      expect(draft.title, 'Take the bread out');
    });

    test('a passed time with no date rolls to tomorrow, and says so', () async {
      // 9:00 AM is already behind the 14:30 reference.
      final draft = await parseOne('Stretch at 9am');
      expect(draft.dueAt, DateTime(2026, 8, 11, 9));
      expect(
        draft.warnings.map((warning) => warning.code),
        contains('ROLLED_TO_TOMORROW'),
      );
    });

    test('a date with no time is flagged as an assumption', () async {
      final draft = await parseOne('Book flights tomorrow');
      expect(draft.dueAt, DateTime(2026, 8, 11, 9));
      expect(
        draft.warnings.map((warning) => warning.code),
        contains('TIME_ASSUMED'),
      );
    });

    test('tonight implies an evening time and marks it approximate', () async {
      final draft = await parseOne('Water the plants tonight');
      expect(draft.dueAt, DateTime(2026, 8, 10, 19));
      expect(
        draft.warnings.map((warning) => warning.code),
        contains('TIME_APPROXIMATE'),
      );
    });
  });

  group('ambiguity', () {
    test('a vague time is flagged with alternatives, never guessed', () async {
      final draft = await parseOne('Call Sam later');
      expect(draft.title, 'Call Sam');
      expect(draft.dueAt, isNull);
      expect(draft.isAmbiguous(DraftField.dueAt), isTrue);
      expect(draft.ambiguities.single.alternatives, hasLength(3));
    });

    test('a bare "at 9" resolves to the morning, per US-01', () async {
      // Hours 8-11 have only one sensible reading, so flagging them would be
      // friction without a decision behind it.
      final draft = await parseOne('Call David tomorrow at 9');
      expect(draft.isAmbiguous(DraftField.dueAt), isFalse);
      expect(draft.dueAt, DateTime(2026, 8, 11, 9));
    });

    test('a bare "at 5" offers both readings', () async {
      final draft = await parseOne('Call the clinic tomorrow at 5');
      expect(draft.isAmbiguous(DraftField.dueAt), isTrue);
      final alternatives = draft.ambiguities.single.alternatives;
      expect(alternatives.map((option) => option.label), <String>[
        '5:00 AM',
        '5:00 PM',
      ]);
      // Defaults to the morning reading, but saving stays blocked until the
      // user picks one.
      expect(draft.dueAt, DateTime(2026, 8, 11, 5));
    });

    test('an explicit meridiem is not ambiguous', () async {
      final draft = await parseOne('Call the clinic tomorrow at 9pm');
      expect(draft.isAmbiguous(DraftField.dueAt), isFalse);
      expect(draft.dueAt, DateTime(2026, 8, 11, 21));
    });

    test('editing a field clears its ambiguity', () async {
      final draft = await parseOne('Call Sam later');
      final resolved = draft
          .copyWith(dueAt: DateTime(2026, 8, 12, 10))
          .resolving(DraftField.dueAt);
      expect(resolved.hasAmbiguities, isFalse);
    });
  });

  group('multi-task capture', () {
    test('splits on a conjunction before a known action verb', () async {
      final result = await parse('Buy milk and email Ana tonight');
      expect(result.drafts, hasLength(2));
      expect(result.drafts[0].title, 'Buy milk');
      expect(result.drafts[0].dueAt, isNull);
      expect(result.drafts[1].title, 'Email Ana');
      expect(result.drafts[1].dueAt, DateTime(2026, 8, 10, 19));
    });

    test('does not split when the right side is not an action', () async {
      final draft = await parseOne('Call David and Sam tomorrow');
      expect(draft.title, 'Call David and Sam');
    });

    test('does not split a comma inside one commitment', () async {
      final draft = await parseOne('Buy milk, eggs and bread');
      expect(draft.title, 'Buy milk, eggs and bread');
    });

    test('honours allowMultipleTasks: false', () async {
      final result = await parser.parseTasks(
        TaskParseRequest(
          requestId: 'single',
          text: 'Buy milk and email Ana',
          referenceNow: now,
          timezone: 'Europe/Copenhagen',
          locale: 'en-GB',
          allowMultipleTasks: false,
        ),
      );
      expect(result.drafts, hasLength(1));
    });
  });

  group('field extraction', () {
    test('reads priority from bangs', () async {
      final draft = await parseOne('Send the invoice !!!');
      expect(draft.priority, TaskPriority.high);
      expect(draft.title, 'Send the invoice');
    });

    test('reads priority from words', () async {
      final draft = await parseOne('Fix the leak urgent');
      expect(draft.priority, TaskPriority.high);
    });

    test('reads hashtags and keeps them out of the title', () async {
      final draft = await parseOne('Review the deck #work #q3');
      expect(draft.tags, <String>['work', 'q3']);
      expect(draft.title, 'Review the deck');
    });

    test('reuses an existing tag spelling', () async {
      final result = await parser.parseTasks(
        TaskParseRequest(
          requestId: 'tags',
          text: 'Review the deck #Work',
          referenceNow: now,
          timezone: 'Europe/Copenhagen',
          locale: 'en-GB',
          knownTags: const <String>['work'],
        ),
      );
      expect(result.drafts.single.tags, <String>['work']);
    });

    test('reads a duration', () async {
      final draft = await parseOne('Walk the dog for 30 minutes');
      expect(draft.durationMinutes, 30);
      expect(draft.title, 'Walk the dog');
    });
  });

  group('recurrence', () {
    test('every monday becomes a weekly rule on that weekday', () async {
      final draft = await parseOne('Standup every monday at 9am');
      expect(draft.recurrence!.frequency, RecurrenceFrequency.weekly);
      expect(draft.recurrence!.byWeekday, <int>[DateTime.monday]);
      expect(draft.title, 'Standup');
    });

    test('every 2 weeks becomes an interval', () async {
      final draft = await parseOne('Water the ferns every 2 weeks');
      expect(draft.recurrence!.frequency, RecurrenceFrequency.weekly);
      expect(draft.recurrence!.interval, 2);
    });

    test('weekdays expands to Monday through Friday', () async {
      final draft = await parseOne('Take vitamins every weekday');
      expect(draft.recurrence!.byWeekday, <int>[1, 2, 3, 4, 5]);
    });

    test('a bare recurrence still gets a first occurrence', () async {
      final draft = await parseOne('Take out the bins every monday');
      expect(draft.dueAt, isNotNull);
      expect(draft.dueAt!.weekday, DateTime.monday);
      expect(draft.dueAt!.isAfter(now), isTrue);
    });
  });

  group('guard rails', () {
    test('empty input produces no drafts rather than an error', () async {
      final result = await parse('   ');
      expect(result.drafts, isEmpty);
    });

    test('over-long input is rejected with the input retained', () async {
      await expectLater(
        parse('x' * 1200),
        throwsA(
          isA<LocalAiException>()
              .having(
                (error) => error.code,
                'code',
                LocalAiErrorCode.inputTooLong,
              )
              .having(
                (error) => error.retainedInput,
                'retainedInput',
                isNotNull,
              ),
        ),
      );
    });

    test('the same input always resolves identically', () async {
      final first = await parseOne('Call David tomorrow at 9am');
      final second = await parseOne('Call David tomorrow at 9am');
      expect(first.title, second.title);
      expect(first.dueAt, second.dueAt);
    });
  });
}
