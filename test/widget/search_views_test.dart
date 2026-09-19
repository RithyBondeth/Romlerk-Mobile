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
import 'package:romlerk_mobile/features/search/search_page.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import '../support/drift_widget_harness.dart';

void main() {
  final now = DateTime(2026, 8, 10, 14, 30);

  late AppDatabase database;
  late DriftTaskRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
    for (final (id, title, status) in <(String, String, TaskStatus)>[
      ('a', 'Call David', TaskStatus.active),
      ('b', 'Pay rent', TaskStatus.completed),
    ]) {
      await repository.createTask(
        Task(
          id: id,
          title: title,
          status: status,
          priority: TaskPriority.none,
          createdAt: now,
          updatedAt: now,
          completedAt: status == TaskStatus.completed ? now : null,
        ),
      );
    }
  });

  tearDown(() => database.close());

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SearchPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testDriftWidgets('All shows every task, Open and Done split them', (
    tester,
  ) async {
    await pumpSearch(tester);
    expect(find.text('Call David'), findsOneWidget);
    expect(find.text('Pay rent'), findsOneWidget);
    expect(find.text('2 tasks'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Call David'), findsNothing);
    expect(find.text('Pay rent'), findsOneWidget);
    expect(find.text('1 done'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Call David'), findsOneWidget);
    expect(find.text('Pay rent'), findsNothing);
  });

  testDriftWidgets('due filters narrow by when a task is due', (tester) async {
    Future<void> dated(String id, String title, DateTime due) =>
        repository.createTask(
          Task(
            id: id,
            title: title,
            status: TaskStatus.active,
            priority: TaskPriority.none,
            dueAt: due,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dated('late', 'Renew licence', DateTime(2026, 8, 8, 9));
    await dated('later', 'Send the deck', DateTime(2026, 8, 10, 16));
    await dated('soon', 'Book flights', DateTime(2026, 8, 13, 9));
    await dated('far', 'Dentist', DateTime(2026, 8, 30, 9));
    await pumpSearch(tester);

    Future<void> tapChip(String label) async {
      await tester.tap(find.widgetWithText(FilterChip, label));
      await tester.pumpAndSettle();
    }

    List<String> shown() => <String>[
      for (final title in <String>[
        'Call David',
        'Pay rent',
        'Renew licence',
        'Send the deck',
        'Book flights',
        'Dentist',
      ])
        if (find.text(title).evaluate().isNotEmpty) title,
    ];

    await tapChip('Overdue');
    expect(shown(), <String>['Renew licence']);

    await tapChip('Today');
    expect(shown(), <String>['Send the deck']);

    await tapChip('Next 7 days');
    expect(shown(), <String>['Send the deck', 'Book flights']);

    // Selecting the same chip again clears it. Counted from the header:
    // with every task back, the last rows are below the fold.
    await tapChip('Next 7 days');
    expect(find.text('6 tasks'), findsOneWidget);

    // A finished task is never overdue.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tapChip('Overdue');
    expect(shown(), isEmpty);
  });
}
