import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../application/task_service.dart';
import '../../data/local/app_database.dart';
import '../../data/local/settings_store.dart';
import '../../data/repositories/drift_task_repository.dart';
import '../../l10n/l10n.dart';
import '../widgets/widget_sync_service.dart';
import 'reminder_scheduler.dart';

/// Name under which the running app listens for changes made by the
/// notification-action isolate, so its lists refresh at once.
const String notificationActionPortName = 'dev.romlerk/notification_actions';

/// Applies a notification button to its task (FR-11). Shared by the
/// background isolate and the foreground, so both behave identically.
///
/// Returns whether anything changed. A task deleted since the reminder was
/// scheduled is not an error: there is simply nothing left to do.
Future<bool> applyNotificationAction(
  TaskService service, {
  required String taskId,
  required String actionId,
}) async {
  try {
    switch (actionId) {
      case ReminderScheduler.completeActionId:
        await service.completeTask(taskId);
        return true;
      case ReminderScheduler.snoozeActionId:
        await service.snooze(taskId);
        return true;
    }
  } on StateError {
    // Task deleted (or already gone) before the button was pressed.
  }
  return false;
}

/// Entry point for Complete and Snooze.
///
/// Both platforms deliver buttons that do not open the app to a separate,
/// headless isolate — whether or not the app is running — so this is the
/// only place they are ever seen. It opens its own database connection,
/// applies the action, and tells the app (if it is alive) to refresh.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  final taskId = response.payload;
  final actionId = response.actionId;
  if (taskId == null || taskId.isEmpty || actionId == null) return;

  // Plugins implemented in Dart (path_provider) need registering in a
  // headless isolate before first use.
  DartPluginRegistrant.ensureInitialized();

  final database = AppDatabase.forActionIsolate();
  var changed = false;
  try {
    final settings = await SettingsStore(database).read();
    final locale = resolveAppLocale(PlatformDispatcher.instance.locale);
    final hidden =
        settings.redactNotificationPreviews || settings.appLockEnabled;

    final scheduler = ReminderScheduler()
      ..strings = lookupAppLocalizations(locale)
      ..redactPreviews = settings.redactNotificationPreviews;
    final widgets = WidgetSyncService()..hideTitles = hidden;
    final service = TaskService(
      repository: DriftTaskRepository(database),
      scheduler: scheduler,
      widgetSyncService: widgets,
    );

    changed = await applyNotificationAction(
      service,
      taskId: taskId,
      actionId: actionId,
    );
  } finally {
    await database.close();
  }

  if (changed) {
    IsolateNameServer.lookupPortByName(
      notificationActionPortName,
    )?.send(taskId);
  }
}
