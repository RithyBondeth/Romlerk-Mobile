import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/reminder.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums.dart';

/// What the OS currently allows.
enum NotificationPermission { granted, denied, notDetermined, restricted }

/// Outcome of one scheduling attempt.
///
/// Scheduling deliberately returns a value instead of throwing: a failed
/// reminder must never prevent a task from being saved (BRD "failure
/// atomicity"), so the caller records the outcome and warns in the UI.
class ScheduleOutcome {
  const ScheduleOutcome({
    required this.state,
    this.platformId,
    this.failureCode,
  });

  final ReminderState state;
  final int? platformId;
  final String? failureCode;

  bool get succeeded => state == ReminderState.scheduled;
}

/// Local notification scheduling, isolated behind a facade so the rest of the
/// app never touches the plugin (NFR-15).
class ReminderScheduler {
  ReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String androidChannelId = 'romlerk_reminders';
  static const String androidChannelName = 'Task reminders';
  static const String androidChannelDescription =
      'Reminders for tasks you scheduled in Romlerk.';

  static const String completeActionId = 'complete';
  static const String snoozeActionId = 'snooze';

  /// How long "snooze" defers a reminder.
  static const Duration snoozeDuration = Duration(minutes: 15);

  bool _initialized = false;
  String _localTimezone = 'UTC';

  /// Deep-link target when a notification is tapped: the task's id.
  final StreamController<String> _taskOpenRequests =
      StreamController<String>.broadcast();

  /// Emits (taskId, actionId) for notification action buttons.
  final StreamController<({String taskId, String actionId})> _actionRequests =
      StreamController<({String taskId, String actionId})>.broadcast();

  Stream<String> get taskOpenRequests => _taskOpenRequests.stream;

  Stream<({String taskId, String actionId})> get actionRequests =>
      _actionRequests.stream;

  String get localTimezone => _localTimezone;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      _localTimezone = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(_localTimezone));
    } on Object {
      // An unknown zone name must not stop the app from starting; UTC keeps
      // scheduling functional and the timezone is re-read on next launch.
      _localTimezone = tz.local.name;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      // Permission is requested at the moment of value, not on first launch
      // (NFR-09), so all three are false here.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            androidChannelId,
            androidChannelName,
            description: androidChannelDescription,
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  void _handleResponse(NotificationResponse response) {
    final taskId = response.payload;
    if (taskId == null || taskId.isEmpty) return;
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      _actionRequests.add((taskId: taskId, actionId: actionId));
      return;
    }
    _taskOpenRequests.add(taskId);
  }

  /// The task id from a notification that launched the app, if any.
  Future<String?> launchTaskId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  Future<NotificationPermission> currentPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      return enabled == true
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    }

    // iOS/macOS expose no "check without asking" API through the plugin, so
    // an unknown state is reported rather than guessed.
    return NotificationPermission.notDetermined;
  }

  /// Asks for permission. Only called when the user has just done something
  /// that needs it (NFR-09).
  Future<NotificationPermission> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted == true
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    }

    final darwin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (darwin != null) {
      final granted = await darwin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted == true
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    }

    return NotificationPermission.notDetermined;
  }

  /// Schedules (or reschedules) the reminder for [task].
  ///
  /// Never throws. A refused permission, a past timestamp, or a platform error
  /// all come back as a non-scheduled [ScheduleOutcome] so the task itself
  /// still saves.
  Future<ScheduleOutcome> schedule(Task task, Reminder reminder) async {
    await initialize();

    if (!reminder.scheduledAt.isAfter(DateTime.now())) {
      return const ScheduleOutcome(
        state: ReminderState.failed,
        failureCode: 'REMINDER_IN_PAST',
      );
    }

    final permission = await currentPermission();
    if (permission == NotificationPermission.denied ||
        permission == NotificationPermission.restricted) {
      return const ScheduleOutcome(
        state: ReminderState.blocked,
        failureCode: 'NOTIFICATION_PERMISSION_DENIED',
      );
    }

    final platformId = reminder.platformId ?? platformIdFor(reminder.id);

    try {
      await _plugin.zonedSchedule(
        id: platformId,
        title: task.title,
        body: _bodyFor(task),
        scheduledDate: tz.TZDateTime.from(reminder.scheduledAt, tz.local),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: task.id,
      );
      return ScheduleOutcome(
        state: ReminderState.scheduled,
        platformId: platformId,
      );
    } on Object catch (error) {
      return ScheduleOutcome(
        state: ReminderState.failed,
        platformId: platformId,
        failureCode: 'NOTIFICATION_SCHEDULE_FAILED: ${error.runtimeType}',
      );
    }
  }

  Future<void> cancel(int? platformId) async {
    if (platformId == null) return;
    await initialize();
    try {
      await _plugin.cancel(id: platformId);
    } on Object {
      // Cancelling something the OS already forgot is not an error.
    }
  }

  Future<void> cancelAll() async {
    await initialize();
    try {
      await _plugin.cancelAll();
    } on Object {
      // Best effort.
    }
  }

  /// Ids the OS currently holds, used to detect drift from the database.
  Future<Set<int>> pendingPlatformIds() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toSet();
  }

  /// Derives a stable 31-bit notification id from a reminder id, so
  /// rescheduling the same reminder replaces it instead of duplicating.
  static int platformIdFor(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;

  String? _bodyFor(Task task) {
    final due = task.effectiveDate;
    if (due == null) return task.notes;
    final notes = task.notes;
    return notes == null || notes.isEmpty ? null : notes;
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannelId,
        androidChannelName,
        channelDescription: androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            completeActionId,
            'Complete',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            snoozeActionId,
            'Snooze 15m',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(categoryIdentifier: 'romlerk_reminder'),
    );
  }

  Future<void> dispose() async {
    await _taskOpenRequests.close();
    await _actionRequests.close();
  }
}

/// Runs in a separate isolate when an action is tapped while the app is not
/// in the foreground. Must be a top-level function.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // The database is not available in this isolate, so nothing is written here.
  // The app reconciles notification state on next resume instead.
}
