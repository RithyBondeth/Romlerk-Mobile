import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/features/capture/widgets/draft_card.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';

void main() {
  group('quickDates', () {
    test('a weekday afternoon offers all four, each in the future', () {
      final now = DateTime(2026, 8, 10, 14, 30); // Monday
      expect(quickDates(now), <QuickDate, DateTime>{
        QuickDate.thisEvening: DateTime(2026, 8, 10, 19),
        QuickDate.tomorrowMorning: DateTime(2026, 8, 11, 9),
        QuickDate.thisWeekend: DateTime(2026, 8, 15, 9),
        QuickDate.nextWeek: DateTime(2026, 8, 17, 9),
      });
      expect(quickDates(now).values.every((at) => at.isAfter(now)), isTrue);
    });

    test('drops this evening once it has begun', () {
      final now = DateTime(2026, 8, 10, 18, 5);
      expect(quickDates(now).keys, isNot(contains(QuickDate.thisEvening)));
    });

    test('drops this weekend on the weekend itself', () {
      final saturday = DateTime(2026, 8, 15, 10);
      expect(quickDates(saturday).keys, isNot(contains(QuickDate.thisWeekend)));
      expect(quickDates(saturday)[QuickDate.nextWeek], DateTime(2026, 8, 17, 9));
    });

    test('next week from a Monday is the following Monday', () {
      final monday = DateTime(2026, 8, 17, 8);
      expect(quickDates(monday)[QuickDate.nextWeek], DateTime(2026, 8, 24, 9));
    });
  });

  group('DraftCard quick dates', () {
    final now = DateTime(2026, 8, 10, 14, 30);

    Future<List<TaskDraft>> pumpCard(
      WidgetTester tester,
      TaskDraft draft,
    ) async {
      final changes = <TaskDraft>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[clockProvider.overrideWithValue(() => now)],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DraftCard(draft: draft, onChanged: changes.add),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return changes;
    }

    testWidgets('an undated draft gets a date and reminder in one tap', (
      tester,
    ) async {
      final changes = await pumpCard(
        tester,
        const TaskDraft(id: 'd1', title: 'ទៅលេងផ្ទះយាយ'),
      );

      expect(find.text('When?'), findsOneWidget);
      await tester.tap(find.text('Tomorrow morning'));

      final updated = changes.single;
      expect(updated.dueAt, DateTime(2026, 8, 11, 9));
      expect(updated.reminderAt, DateTime(2026, 8, 11, 9));
      expect(updated.title, 'ទៅលេងផ្ទះយាយ');
    });

    testWidgets('a dated draft does not show them', (tester) async {
      await pumpCard(
        tester,
        TaskDraft(id: 'd2', title: 'Call Ana', dueAt: DateTime(2026, 8, 11, 9)),
      );
      expect(find.text('When?'), findsNothing);
    });

    testWidgets('a date question shows its own answers, not these', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const TaskDraft(
          id: 'd3',
          title: 'Call Ana',
          ambiguities: <DraftAmbiguity>[
            DraftAmbiguity(
              field: DraftField.dueAt,
              code: DraftAmbiguity.vagueTimeCode,
              reason: '"later" doesn\'t say when. Pick a time.',
              sourceSpan: 'later',
            ),
          ],
        ),
      );
      expect(find.text('When?'), findsNothing);
    });
  });
}
