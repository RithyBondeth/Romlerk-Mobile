import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/features/today/daily_planning_sheet.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import '../support/drift_widget_harness.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 8, 12, 10);
  late List<Task> tasks;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tasks = [
      for (var i = 1; i <= 2; i++)
        Task(
          id: '$i',
          title: 'Task ${i == 1 ? 'A' : 'B'}',
          status: TaskStatus.active,
          priority: TaskPriority.none,
          durationMinutes: i * 30,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    final repository = DriftTaskRepository(db);
    for (final task in tasks) {
      await repository.createTask(task);
    }
  });
  tearDown(() => db.close());
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => DailyPlanningSheet.show(context, tasks),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testDriftWidgets('planner saves selections and restores them when reopened', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('1.5 h · 2 tasks'), findsOneWidget);
    await tester.tap(find.text('Task B'));
    await tester.pumpAndSettle();
    expect(find.text('0.5 h · 1 task'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final tiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(tiles.map((t) => t.value), [true, false]);
  });
}
