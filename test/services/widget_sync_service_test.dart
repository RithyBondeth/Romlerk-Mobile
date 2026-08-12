import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/services/widgets/widget_sync_service.dart';

void main() {
  group('WidgetSyncService', () {
    final now = DateTime(2026, 8, 12, 10, 0);
    final service = WidgetSyncService();

    test('builds valid JSON payload with top tasks and counts', () {
      final overdueTask = Task(
        id: '1',
        title: 'Overdue task',
        status: TaskStatus.active,
        priority: TaskPriority.high,
        dueAt: DateTime(2026, 8, 11, 9, 0),
        createdAt: now,
        updatedAt: now,
      );

      final todayTask = Task(
        id: '2',
        title: 'Today task',
        status: TaskStatus.active,
        priority: TaskPriority.none,
        dueAt: DateTime(2026, 8, 12, 14, 0),
        createdAt: now,
        updatedAt: now,
      );

      final payloadStr = service.buildPayload(
        overdueTasks: [overdueTask],
        todayTasks: [todayTask],
        now: now,
      );

      final json = jsonDecode(payloadStr) as Map<String, dynamic>;
      expect(json['overdueCount'], 1);
      expect(json['todayCount'], 1);
      expect(json['totalCount'], 2);

      final tasks = json['topTasks'] as List<dynamic>;
      expect(tasks.length, 2);
      expect(tasks[0]['title'], 'Overdue task');
      expect(tasks[0]['isOverdue'], true);
      expect(tasks[1]['title'], 'Today task');
      expect(tasks[1]['isOverdue'], false);
    });
  });
}
