import 'package:flutter_test/flutter_test.dart';

import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/local_ai/deterministic/deterministic_parser.dart';
import 'package:romlerk_mobile/local_ai/local_ai.dart';

/// Test case category for AI Quality Scorecard reporting (BRD §20).
enum BenchmarkCategory {
  relativeDate,
  absoluteDate,
  multiTask,
  ambiguity,
  priorityTags,
  recurrence,
  edgeCases,
}

/// A single standardized test entry in the AI evaluation corpus (BRD §20).
class BenchmarkCorpusEntry {
  const BenchmarkCorpusEntry({
    required this.id,
    required this.category,
    required this.input,
    required this.expectedDraftCount,
    required this.expectedTitles,
    this.expectedDueAt,
    this.expectedPriority = TaskPriority.none,
    this.expectedTags = const <String>[],
    this.expectedDurationMinutes,
    this.expectedAmbiguityField,
    this.expectedWarningCodes = const <String>[],
  });

  final String id;
  final BenchmarkCategory category;
  final String input;
  final int expectedDraftCount;
  final List<String> expectedTitles;
  final DateTime? expectedDueAt;
  final TaskPriority expectedPriority;
  final List<String> expectedTags;
  final int? expectedDurationMinutes;
  final DraftField? expectedAmbiguityField;
  final List<String> expectedWarningCodes;
}

/// Evaluation report summary metrics (BRD §20 AI Quality Scorecard).
class BenchmarkScorecard {
  BenchmarkScorecard({
    required this.totalCases,
    required this.exactTitleMatches,
    required this.exactDateMatches,
    required this.exactDraftCountMatches,
    required this.priorityMatches,
    required this.tagMatches,
    required this.ambiguityMatches,
  });

  final int totalCases;
  final int exactTitleMatches;
  final int exactDateMatches;
  final int exactDraftCountMatches;
  final int priorityMatches;
  final int tagMatches;
  final int ambiguityMatches;

  double get titleAccuracy => totalCases == 0 ? 0.0 : exactTitleMatches / totalCases;
  double get dateAccuracy => totalCases == 0 ? 0.0 : exactDateMatches / totalCases;
  double get draftCountAccuracy => totalCases == 0 ? 0.0 : exactDraftCountMatches / totalCases;
  double get priorityAccuracy => totalCases == 0 ? 0.0 : priorityMatches / totalCases;
  double get tagAccuracy => totalCases == 0 ? 0.0 : tagMatches / totalCases;
  double get ambiguityRecall => totalCases == 0 ? 0.0 : ambiguityMatches / totalCases;

  bool get meetsQualityGate =>
      dateAccuracy >= 0.95 && titleAccuracy >= 0.95 && draftCountAccuracy == 1.0;
}

void main() {
  group('AI Quality Evaluation Corpus & Scorecard (BRD §20)', () {
    final parser = DeterministicTaskParser();

    // Standardized reference instant: Monday, 10 August 2026 at 14:30.
    final referenceNow = DateTime(2026, 8, 10, 14, 30);

    // Synthetic test corpus covering core beachhead user phrasing.
    final corpus = <BenchmarkCorpusEntry>[
      BenchmarkCorpusEntry(
        id: 'TC-01',
        category: BenchmarkCategory.relativeDate,
        input: 'Call David tomorrow at 9am',
        expectedDraftCount: 1,
        expectedTitles: ['Call David'],
        expectedDueAt: DateTime(2026, 8, 11, 9, 0),
      ),
      BenchmarkCorpusEntry(
        id: 'TC-02',
        category: BenchmarkCategory.relativeDate,
        input: 'Submit quarterly report on friday at 10am',
        expectedDraftCount: 1,
        expectedTitles: ['Submit quarterly report'],
        expectedDueAt: DateTime(2026, 8, 14, 10, 0),
      ),
      BenchmarkCorpusEntry(
        id: 'TC-03',
        category: BenchmarkCategory.relativeDate,
        input: 'Water the plants tonight',
        expectedDraftCount: 1,
        expectedTitles: ['Water the plants'],
        expectedDueAt: DateTime(2026, 8, 10, 19, 0),
        expectedWarningCodes: ['TIME_APPROXIMATE'],
      ),
      BenchmarkCorpusEntry(
        id: 'TC-04',
        category: BenchmarkCategory.multiTask,
        input: 'Buy milk and email Ana tonight',
        expectedDraftCount: 2,
        expectedTitles: ['Buy milk', 'Email Ana'],
        expectedDueAt: DateTime(2026, 8, 10, 19, 0),
      ),
      BenchmarkCorpusEntry(
        id: 'TC-05',
        category: BenchmarkCategory.ambiguity,
        input: 'Call Sam later',
        expectedDraftCount: 1,
        expectedTitles: ['Call Sam'],
        expectedAmbiguityField: DraftField.dueAt,
      ),
      BenchmarkCorpusEntry(
        id: 'TC-06',
        category: BenchmarkCategory.priorityTags,
        input: 'Review Q3 deck #work #urgent !!!',
        expectedDraftCount: 1,
        expectedTitles: ['Review Q3 deck'],
        expectedPriority: TaskPriority.high,
        expectedTags: ['work', 'urgent'],
      ),
      BenchmarkCorpusEntry(
        id: 'TC-07',
        category: BenchmarkCategory.recurrence,
        input: 'Team standup every monday at 9am',
        expectedDraftCount: 1,
        expectedTitles: ['Standup'],
        expectedDueAt: DateTime(2026, 8, 17, 9, 0),
      ),
      BenchmarkCorpusEntry(
        id: 'TC-08',
        category: BenchmarkCategory.edgeCases,
        input: 'Walk the dog for 30 minutes',
        expectedDraftCount: 1,
        expectedTitles: ['Walk the dog'],
        expectedDurationMinutes: 30,
      ),
    ];

    test('evaluates benchmark corpus against quality gate thresholds', () async {
      var titleMatches = 0;
      var dateMatches = 0;
      var countMatches = 0;
      var priorityMatches = 0;
      var tagMatches = 0;
      var ambiguityMatches = 0;

      for (final entry in corpus) {
        final result = await parser.parseTasks(
          TaskParseRequest(
            requestId: entry.id,
            text: entry.input,
            referenceNow: referenceNow,
            timezone: 'Europe/Copenhagen',
            locale: 'en-GB',
          ),
        );

        if (result.drafts.length == entry.expectedDraftCount) {
          countMatches++;
        }

        if (result.drafts.isNotEmpty) {
          final first = result.drafts.first;

          if (first.title == entry.expectedTitles.first) {
            titleMatches++;
          }

          if (entry.expectedDueAt != null) {
            if (first.dueAt == entry.expectedDueAt ||
                (result.drafts.length > 1 && result.drafts.last.dueAt == entry.expectedDueAt)) {
              dateMatches++;
            }
          } else if (first.dueAt == null) {
            dateMatches++;
          }

          if (first.priority == entry.expectedPriority) {
            priorityMatches++;
          }

          if (entry.expectedTags.isEmpty ||
              entry.expectedTags.every((tag) => first.tags.contains(tag))) {
            tagMatches++;
          }

          if (entry.expectedAmbiguityField != null) {
            if (first.isAmbiguous(entry.expectedAmbiguityField!)) {
              ambiguityMatches++;
            }
          } else {
            ambiguityMatches++;
          }
        }
      }

      final scorecard = BenchmarkScorecard(
        totalCases: corpus.length,
        exactTitleMatches: titleMatches,
        exactDateMatches: dateMatches,
        exactDraftCountMatches: countMatches,
        priorityMatches: priorityMatches,
        tagMatches: tagMatches,
        ambiguityMatches: ambiguityMatches,
      );

      expect(scorecard.titleAccuracy, greaterThanOrEqualTo(0.95));
      expect(scorecard.dateAccuracy, greaterThanOrEqualTo(0.95));
      expect(scorecard.draftCountAccuracy, equals(1.0));
      expect(scorecard.meetsQualityGate, isTrue);
    });
  });
}
