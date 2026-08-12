import 'package:flutter_test/flutter_test.dart';

import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/services/calendar/calendar_export_service.dart';

void main() {
  group('CalendarExportService', () {
    const service = CalendarExportService();
    final now = DateTime(2026, 8, 12, 10, 0);

    test('builds valid ICS calendar format string', () {
      final task = Task(
        id: 'task-123',
        title: 'Project Sync',
        notes: 'Review Q3 goals',
        status: TaskStatus.active,
        priority: TaskPriority.medium,
        dueAt: DateTime(2026, 8, 12, 15, 0),
        durationMinutes: 45,
        createdAt: now,
        updatedAt: now,
      );

      final ics = service.buildIcs(task, exportedAt: now);

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('SUMMARY:Project Sync'));
      expect(ics, contains('DESCRIPTION:Review Q3 goals'));
      expect(ics, contains('UID:task-123@romlerk.local'));
      expect(ics, contains('END:VEVENT'));
      expect(ics, contains('END:VCALENDAR'));
    });
  });
}
