import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/services/notifications/reminder_scheduler.dart';

void main() {
  final now = DateTime(2026, 8, 10, 14, 30);
  final task = Task(
    id: 't',
    title: 'Pick up test results',
    notes: 'Clinic on 5th street',
    status: TaskStatus.active,
    priority: TaskPriority.none,
    dueAt: DateTime(2026, 8, 11, 9),
    createdAt: now,
    updatedAt: now,
  );

  test('shows the task by default', () {
    final content = ReminderScheduler().contentFor(task);
    expect(content.title, 'Pick up test results');
    expect(content.body, 'Clinic on 5th street');
  });

  test('hidden previews carry no task text at all', () {
    final scheduler = ReminderScheduler()..redactPreviews = true;
    final content = scheduler.contentFor(task);
    expect(content.title, scheduler.strings.notificationRedactedTitle);
    expect(content.body, scheduler.strings.notificationRedactedBody);
    expect('${content.title} ${content.body}', isNot(contains('test results')));
    expect('${content.title} ${content.body}', isNot(contains('Clinic')));
  });
}
