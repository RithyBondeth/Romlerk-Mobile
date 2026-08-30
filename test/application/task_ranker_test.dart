import 'package:flutter_test/flutter_test.dart';

import 'package:romlerk_mobile/application/task_ranker.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';

void main() {
  group('TaskRanker (FR-18)', () {
    const ranker = TaskRanker();
    final now = DateTime(2026, 8, 12, 10, 0);

    test('ranks overdue tasks above future tasks', () {
      final overdueTask = Task(
        id: '1',
        title: 'Overdue bill',
        status: TaskStatus.active,
        priority: TaskPriority.none,
        dueAt: DateTime(2026, 8, 11, 9, 0),
        createdAt: now,
        updatedAt: now,
      );

      final futureTask = Task(
        id: '2',
        title: 'Future meeting',
        status: TaskStatus.active,
        priority: TaskPriority.none,
        dueAt: DateTime(2026, 8, 12, 15, 0),
        createdAt: now,
        updatedAt: now,
      );

      final ranked = ranker.rankTasks([futureTask, overdueTask], now: now);

      expect(ranked.first.task.id, equals('1'));
      expect(ranked.first.reasons, contains('Overdue commitment'));
    });

    test('boosts high priority and quick win tasks', () {
      final normalTask = Task(
        id: '1',
        title: 'Long task',
        status: TaskStatus.active,
        priority: TaskPriority.none,
        createdAt: now,
        updatedAt: now,
      );

      final quickHighTask = Task(
        id: '2',
        title: 'Quick high priority task',
        status: TaskStatus.active,
        priority: TaskPriority.high,
        durationMinutes: 10,
        createdAt: now,
        updatedAt: now,
      );

      final ranked = ranker.rankTasks([normalTask, quickHighTask], now: now);

      expect(ranked.first.task.id, equals('2'));
      expect(ranked.first.reasons, contains('High priority'));
      expect(ranked.first.reasons, contains('Quick win (10m)'));
    });
  });
}
