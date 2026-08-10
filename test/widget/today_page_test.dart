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

void main() {
  final now = DateTime(2026, 8, 10, 14, 30);

  late AppDatabase database;
  late DriftTaskRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
  });

  tearDown(() => database.close());

  Future<void> pumpToday(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TodayPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addTask({
    required String id,
    required String title,
    DateTime? dueAt,
    TaskStatus status = TaskStatus.active,
    DateTime? completedAt,
  }) {
    return repository.createTask(
      Task(
        id: id,
        title: title,
        status: status,
        priority: TaskPriority.none,
        dueAt: dueAt,
        createdAt: now,
        updatedAt: now,
        completedAt: completedAt,
      ),
    );
  }

  testWidgets('an empty Today explains the surface instead of erroring',
      (tester) async {
    await pumpToday(tester);

    expect(find.text('Nothing due today'), findsOneWidget);
    // The date header is still shown, so the screen never looks broken.
    expect(find.text('Monday'), findsOneWidget);
  });

  testWidgets('overdue is separated from today and counted', (tester) async {
    await addTask(
      id: 'late',
      title: 'Pay the invoice',
      dueAt: DateTime(2026, 8, 8, 9),
    );
    await addTask(
      id: 'now',
      title: 'Send the deck',
      dueAt: DateTime(2026, 8, 10, 16),
    );

    await pumpToday(tester);

    expect(find.text('OVERDUE'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Pay the invoice'), findsOneWidget);
    expect(find.text('Send the deck'), findsOneWidget);
    expect(find.text('10 August · 2 left'), findsOneWidget);
  });

  testWidgets('an overdue task states how late it is, not just a colour',
      (tester) async {
    await addTask(
      id: 'late',
      title: 'Pay the invoice',
      dueAt: DateTime(2026, 8, 8, 9),
    );

    await pumpToday(tester);

    expect(find.text('2 days overdue'), findsOneWidget);
  });

  testWidgets('work finished today is shown, not hidden', (tester) async {
    await addTask(
      id: 'done',
      title: 'Water the plants',
      dueAt: DateTime(2026, 8, 10, 8),
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 8, 10, 8, 30),
    );

    await pumpToday(tester);

    expect(find.text('DONE TODAY'), findsOneWidget);
    expect(find.text('Water the plants'), findsOneWidget);
  });

  testWidgets('tapping the ring completes a task and the list updates',
      (tester) async {
    await addTask(
      id: 'now',
      title: 'Send the deck',
      dueAt: DateTime(2026, 8, 10, 16),
    );
    await pumpToday(tester);

    expect(find.text('10 August · 1 left'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Mark complete'));
    await tester.pumpAndSettle();

    expect(find.text('DONE TODAY'), findsOneWidget);
    expect(find.text('10 August'), findsOneWidget);
  });
}
