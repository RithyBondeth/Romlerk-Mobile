import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/local_ai/local_ai.dart';
import 'package:romlerk_mobile/local_ai/platform/draft_codec.dart';

/// Guards the boundary where untrusted native output enters the app.
///
/// The native adapters are real models: they will occasionally emit an unknown
/// enum, an impossible number, or a date that is not a date. Every one of
/// those must be rejected here rather than reaching the database, and
/// rejection must take down the whole result — a half-decoded model response
/// is worse than none, because the deterministic parser would have produced a
/// complete one.
void main() {
  const codec = DraftCodec();
  final now = DateTime(2026, 8, 11, 14, 30);

  final request = TaskParseRequest(
    requestId: 'req-1',
    text: 'Call David tomorrow at 9am',
    referenceNow: now,
    timezone: 'Europe/Copenhagen',
    locale: 'en',
  );

  Map<Object?, Object?> payload(List<Map<String, Object?>> tasks) {
    return <Object?, Object?>{
      'schemaVersion': 1,
      'provider': 'appleFoundationModels',
      'tasks': tasks,
    };
  }

  group('a well-formed payload', () {
    test('decodes the fields the adapters actually send', () {
      final drafts = codec.decodeDrafts(
        payload(<Map<String, Object?>>[
          <String, Object?>{
            'title': 'Call David',
            'dueAt': '2026-08-12T09:00:00+02:00',
            'reminderAt': '2026-08-12T09:00:00+02:00',
            'priority': 'high',
            'durationMinutes': 30,
            'durationIsEstimate': true,
            'tags': <String>['work'],
            'recurrence': <String, Object?>{
              'frequency': 'weekly',
              'interval': 2,
              'byWeekday': <int>[3],
            },
            'ambiguities': <Map<String, Object?>>[
              <String, Object?>{
                'field': 'dueAt',
                'reason': 'Morning or evening?',
                'sourceSpan': 'at 9',
              },
            ],
            'warnings': <Map<String, Object?>>[
              <String, Object?>{'code': 'TIME_ASSUMED', 'message': '9 AM used'},
            ],
          },
        ]),
        request: request,
      );

      final draft = drafts.single;
      expect(draft.title, 'Call David');
      expect(draft.dueAt, DateTime.parse('2026-08-12T09:00:00+02:00').toLocal());
      expect(draft.priority, TaskPriority.high);
      expect(draft.durationMinutes, 30);
      expect(draft.durationIsEstimate, isTrue);
      expect(draft.tags, <String>['work']);
      expect(draft.recurrence!.frequency, RecurrenceFrequency.weekly);
      expect(draft.recurrence!.interval, 2);
      expect(draft.isAmbiguous(DraftField.dueAt), isTrue);
      expect(draft.warnings.single.code, 'TIME_ASSUMED');
    });

    test('drops a reminder the model placed in the past', () {
      // Scheduling into the past is the one thing that must never survive
      // decoding, however confidently the model asserts it.
      final drafts = codec.decodeDrafts(
        payload(<Map<String, Object?>>[
          <String, Object?>{
            'title': 'Call David',
            'dueAt': '2026-08-12T09:00:00+02:00',
            'reminderAt': '2026-08-01T09:00:00+02:00',
          },
        ]),
        request: request,
      );
      expect(drafts.single.reminderAt, isNull);
      expect(drafts.single.dueAt, isNotNull);
    });

    test('skips a task with no usable title instead of failing', () {
      final drafts = codec.decodeDrafts(
        payload(<Map<String, Object?>>[
          <String, Object?>{'title': '   '},
          <String, Object?>{'title': 'Real task'},
        ]),
        request: request,
      );
      expect(drafts.map((draft) => draft.title), <String>['Real task']);
    });
  });

  group('malformed output is rejected whole', () {
    void expectRejected(Map<Object?, Object?> raw, String because) {
      expect(
        () => codec.decodeDrafts(raw, request: request),
        throwsA(isA<FormatException>()),
        reason: because,
      );
    }

    test('a schema version newer than this build understands', () {
      expectRejected(
        <Object?, Object?>{'schemaVersion': 99, 'tasks': <Object?>[]},
        'a future shape cannot be interpreted safely',
      );
    });

    test('a missing schema version', () {
      expectRejected(
        <Object?, Object?>{'tasks': <Object?>[]},
        'unversioned output cannot be validated',
      );
    });

    test('tasks that are not a list', () {
      expectRejected(
        <Object?, Object?>{'schemaVersion': 1, 'tasks': 'nope'},
        'the container itself is wrong',
      );
    });

    test('an unknown priority', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          <String, Object?>{'title': 'X', 'priority': 'critical'},
        ]),
        'enum allowlists are exhaustive',
      );
    });

    test('an unsupported recurrence frequency', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          <String, Object?>{
            'title': 'X',
            'recurrence': <String, Object?>{'frequency': 'biweekly'},
          },
        ]),
        'the deterministic engine cannot express it',
      );
    });

    test('a recurrence interval outside the supported range', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          <String, Object?>{
            'title': 'X',
            'recurrence': <String, Object?>{
              'frequency': 'daily',
              'interval': 5000,
            },
          },
        ]),
        'out-of-range intervals would produce nonsense schedules',
      );
    });

    test('an invalid weekday', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          <String, Object?>{
            'title': 'X',
            'recurrence': <String, Object?>{
              'frequency': 'weekly',
              'byWeekday': <int>[9],
            },
          },
        ]),
        'ISO weekdays are 1-7',
      );
    });

    test('a duration outside the supported range', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          <String, Object?>{'title': 'X', 'durationMinutes': 99999},
        ]),
        'a task cannot take 69 days',
      );
    });

    test('a timestamp that is not a timestamp', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          <String, Object?>{'title': 'X', 'dueAt': 'next Friday-ish'},
        ]),
        'the model claimed a date and did not supply one',
      );
    });

    test('a title longer than the bound', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          <String, Object?>{'title': 'x' * 500},
        ]),
        'unbounded text is a denial-of-service on the UI',
      );
    });

    test('more tasks than the cap', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          for (var i = 0; i < 20; i++) <String, Object?>{'title': 'Task $i'},
        ]),
        'a runaway generation should not create twenty tasks',
      );
    });

    test('more tags than the cap', () {
      expectRejected(
        payload(<Map<String, Object?>>[
          <String, Object?>{
            'title': 'X',
            'tags': <String>[for (var i = 0; i < 30; i++) 'tag$i'],
          },
        ]),
        'tag explosion pollutes the tag list permanently',
      );
    });
  });
}
