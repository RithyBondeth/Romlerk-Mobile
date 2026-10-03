import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/domain/entities/reminder.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/services/notifications/reminder_scheduler.dart';

class _PermissionScheduler extends ReminderScheduler {
  int prompts = 0;
  bool initializationFails = false;
  bool permissionCheckFails = false;

  @override
  Future<void> initialize() async {
    if (initializationFails) throw StateError('Plugin unavailable');
  }

  @override
  Future<NotificationPermission> currentPermission() async {
    if (permissionCheckFails) throw StateError('Permission check unavailable');
    return NotificationPermission.denied;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    prompts++;
    return NotificationPermission.denied;
  }
}

void main() {
  final now = DateTime.now();
  final task = Task(
    id: 't',
    title: 'Tomorrow',
    status: TaskStatus.active,
    priority: TaskPriority.none,
    createdAt: now,
    updatedAt: now,
  );
  final reminder = Reminder(
    id: 'r',
    taskId: 't',
    scheduledAt: now.add(const Duration(days: 1)),
    timezone: 'UTC',
    state: ReminderState.blocked,
  );

  test('reconciliation checks permission without prompting', () async {
    final scheduler = _PermissionScheduler();
    final result = await scheduler.schedule(
      task,
      reminder,
      requestPermission: false,
    );
    expect(result.state, ReminderState.blocked);
    expect(scheduler.prompts, 0);
  });

  test('user initiated save can still request permission', () async {
    final scheduler = _PermissionScheduler();
    final result = await scheduler.schedule(task, reminder);
    expect(result.state, ReminderState.blocked);
    expect(scheduler.prompts, 1);
  });

  test(
    'initialization failure is recorded instead of escaping the save',
    () async {
      final scheduler = _PermissionScheduler()..initializationFails = true;
      final result = await scheduler.schedule(task, reminder);
      expect(result.state, ReminderState.failed);
      expect(result.failureCode, contains('NOTIFICATION_SCHEDULE_FAILED'));
    },
  );

  test('permission check failure is recorded during reconciliation', () async {
    final scheduler = _PermissionScheduler()..permissionCheckFails = true;
    final result = await scheduler.schedule(
      task,
      reminder,
      requestPermission: false,
    );
    expect(result.state, ReminderState.failed);
    expect(scheduler.prompts, 0);
  });
}
