import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/features/today/today_page.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';

import '../support/drift_widget_harness.dart';

void main() {
  group('AppLocalizations (UI Localization)', () {
    test('provides English UI strings', () {
      final l10n = lookupAppLocalizations(const Locale('en', 'US'));
      expect(l10n.appTitle, equals('Romlerk'));
      expect(l10n.today, equals('Today'));
      expect(l10n.settings, equals('Settings'));
      expect(l10n.markComplete, equals('Mark complete'));
      expect(l10n.planMyDay, equals('Plan My Day'));
    });

    test('provides Khmer UI strings', () {
      final l10n = lookupAppLocalizations(const Locale('km', 'KH'));
      expect(l10n.appTitle, equals('រំលឹក'));
      expect(l10n.today, equals('ថ្ងៃនេះ'));
      expect(l10n.settings, equals('ការកំណត់'));
      expect(l10n.markComplete, equals('សញ្ញាជោគជ័យ'));
      expect(l10n.planMyDay, equals('រៀបចំផែនការថ្ងៃនេះ'));
    });
  });

  group('Today in Khmer', () {
    final now = DateTime(2026, 8, 10, 14, 30);
    late AppDatabase database;

    setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => database.close());

    Future<void> pumpKhmer(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(database),
            clockProvider.overrideWithValue(() => now),
            appLocaleProvider.overrideWithValue(const Locale('km')),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('km'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TodayPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testDriftWidgets('an empty day reads in Khmer', (tester) async {
      await pumpKhmer(tester);
      expect(find.text('ថ្ងៃនេះគ្មានអ្វីត្រូវធ្វើទេ'), findsOneWidget);
      expect(find.text('Nothing due today'), findsNothing);
    });

    testDriftWidgets('dates and overdue wording are Khmer too', (tester) async {
      await DriftTaskRepository(database).createTask(
        Task(
          id: 'late',
          title: 'បង់ថ្លៃផ្ទះ',
          status: TaskStatus.active,
          priority: TaskPriority.none,
          dueAt: DateTime(2026, 8, 8, 9),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await pumpKhmer(tester);
      expect(find.text('បង់ថ្លៃផ្ទះ'), findsOneWidget);
      expect(find.text('ហួសកំណត់ 2 ថ្ងៃ'), findsOneWidget);
      // Weekday header comes from Khmer date data, not English.
      expect(find.text('Monday'), findsNothing);
    });
  });
}
