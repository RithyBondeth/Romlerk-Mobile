import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import 'package:romlerk_mobile/local_ai/deterministic/deterministic_parser.dart';
import 'package:romlerk_mobile/local_ai/local_ai.dart';

/// The capture sheet offers these as one-tap examples, so each must show the
/// parser at its best in every UI language: a clean title and a date.
void main() {
  final parser = DeterministicTaskParser();
  final now = DateTime(2026, 8, 10, 14, 30);

  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);
    final examples = <String>[
      l10n.captureExample1,
      l10n.captureExample2,
      l10n.captureExample3,
      l10n.captureExample4,
    ];

    for (final example in examples) {
      test('${locale.languageCode}: "$example" becomes a dated task', () async {
        final result = await parser.parseTasks(
          TaskParseRequest(
            requestId: 'example',
            text: example,
            referenceNow: now,
            timezone: 'Asia/Phnom_Penh',
            locale: locale.toLanguageTag(),
          ),
        );
        expect(result.drafts, isNotEmpty);
        for (final draft in result.drafts) {
          expect(draft.title.trim(), isNotEmpty);
          // No leftover time words or digits in the title.
          expect(draft.title, isNot(contains('ម៉ោង')));
          expect(draft.title, isNot(matches(RegExp(r'[0-9០-៩]'))));
        }
        expect(result.drafts.last.dueAt, isNotNull);
      });
    }
  }

  test('Khmer is one of the supported UI languages', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('km')));
  });
}
