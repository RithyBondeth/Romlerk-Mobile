import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/features/today/daily_planning_sheet.dart';

void main() {
  testWidgets('DailyPlanningSheet displays task list and calculate total time', (tester) async {
    final now = DateTime(2026, 8, 12, 10, 0);
    final tasks = <Task>[
      Task(
        id: '1',
        title: 'Task A',
        status: TaskStatus.active,
        priority: TaskPriority.none,
        durationMinutes: 30,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: '2',
        title: 'Task B',
        status: TaskStatus.active,
        priority: TaskPriority.none,
        durationMinutes: 60,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DailyPlanningSheet(tasks: tasks),
          ),
        ),
      ),
    );

    expect(find.text('Plan My Day'), findsOneWidget);
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Task B'), findsOneWidget);
    expect(find.text('1.5 hrs (2 tasks)'), findsOneWidget);
  });
}
