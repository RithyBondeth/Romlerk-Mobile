import 'package:flutter_test/flutter_test.dart';

import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/local_ai/deterministic/deterministic_parser.dart';
import 'package:romlerk_mobile/local_ai/local_ai.dart';

void main() {
  group('Khmer Natural Language Task Parsing & Translation', () {
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

    test('parses Khmer relative dates and translates title', () async {
      final draft = await parseOne('រំលឹកខ្ញុំទិញទឹកដោះគោស្អែកម៉ោង ៩am');
      expect(draft.dueAt, equals(DateTime(2026, 8, 11, 9, 0)));
      expect(draft.title, equals('Buy milk'));
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
}
