import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/local/database_storage.dart';
import '../data/local/settings_store.dart';
import '../data/export/task_exporter.dart';
import '../data/repositories/drift_task_repository.dart';
import '../core/format/task_formatting.dart';
import '../domain/entities/tag.dart';
import '../domain/entities/task.dart';
import '../domain/entities/note.dart';
import '../domain/enums.dart';
import '../domain/repositories/task_repository.dart';
import '../domain/repositories/note_repository.dart';
import '../data/repositories/drift_note_repository.dart';
import '../local_ai/capabilities.dart';
import '../local_ai/capability_router.dart';
import '../local_ai/deterministic/deterministic_parser.dart';
import '../local_ai/local_ai.dart';
import '../local_ai/platform/platform_local_ai.dart';
import '../services/calendar/calendar_export_service.dart';
import '../services/notifications/reminder_scheduler.dart';
import '../services/security/device_authenticator.dart';
import '../services/voice/platform_voice_capture_service.dart';
import '../services/voice/voice_capture_service.dart';
import '../services/widgets/widget_sync_service.dart';
import 'task_ranker.dart';
import 'task_service.dart';
import '../l10n/l10n.dart';

/// Injection point for tests: override with a fixed instant to make
/// date-dependent widgets deterministic.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final databaseStorageProvider = Provider<DatabaseStorage>(
  (ref) => const DatabaseStorage(),
);

/// The backup choice and whether it is still waiting for a relaunch.
final backupStateProvider =
    FutureProvider.autoDispose<({bool enabled, bool pending})>((ref) async {
      final storage = ref.watch(databaseStorageProvider);
      return (
        enabled: await storage.backupEnabled(),
        pending: await storage.changePending(),
      );
    });

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(appDatabaseProvider)),
);

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsStoreProvider).watch(),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => DriftTaskRepository(ref.watch(appDatabaseProvider)),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => DriftNoteRepository(ref.watch(appDatabaseProvider)),
);

final notesProvider = StreamProvider<List<Note>>(
  (ref) => ref.watch(noteRepositoryProvider).watchAllNotes(),
);


final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler()
    ..strings = lookupAppLocalizations(ref.watch(appLocaleProvider));
  ref.listen<AsyncValue<AppSettings>>(settingsProvider, (_, next) {
    final redact = next.valueOrNull?.redactNotificationPreviews;
    if (redact != null) scheduler.redactPreviews = redact;
  }, fireImmediately: true);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

final taskExporterProvider = Provider<TaskExporter>(
  (ref) => const TaskExporter(),
);

final taskRankerProvider = Provider<TaskRanker>(
  (ref) => const TaskRanker(),
);

final widgetSyncServiceProvider = Provider<WidgetSyncService>((ref) {
  final service = WidgetSyncService();
  ref.listen<AsyncValue<AppSettings>>(settingsProvider, (_, next) {
    final settings = next.valueOrNull;
    if (settings == null) return;
    service.hideTitles =
        settings.redactNotificationPreviews || settings.appLockEnabled;
  }, fireImmediately: true);
  return service;
});

final calendarExportServiceProvider = Provider<CalendarExportService>(
  (ref) => const CalendarExportService(),
);

final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalDeviceAuthenticator(),
);

/// Recognises speech in the device language — what the user speaks — rather
/// than the UI language, which may have been left on English.
final voiceCaptureServiceProvider = Provider<VoiceCaptureService>((ref) {
  final service = PlatformVoiceCaptureService(
    locale: WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Re-read each time capture opens, since permission can change in Settings
/// while the app is in the background.
final voiceAvailabilityProvider = FutureProvider.autoDispose<VoiceAvailability>(
  (ref) => ref.watch(voiceCaptureServiceProvider).availability(),
);

/// The UI language, resolved the same way MaterialApp resolves it, for code
/// that formats text without a BuildContext.
final appLocaleProvider = Provider<Locale>(
  (ref) => resolveAppLocale(WidgetsBinding.instance.platformDispatcher.locale),
);

final formattingProvider = Provider<TaskFormatting>((ref) {
  final locale = ref.watch(appLocaleProvider);
  return TaskFormatting(
    locale: locale.toLanguageTag(),
    strings: lookupAppLocalizations(locale),
  );
});

/// The capability router is the app's only [LocalAi]. It decides per request
/// whether the generative path or the deterministic parser runs.
final localAiProvider = Provider<CapabilityRouter>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return CapabilityRouter(
    generative: PlatformLocalAi(),
    deterministic: DeterministicTaskParser(),
    auditSink:
        ({
          required schemaVersion,
          required provider,
          required tier,
          required latencyBucket,
          required outcome,
          required draftCount,
          errorCode,
        }) async {
          // Content-free by construction: no field here can hold task text.
          await database.into(database.parseAuditRows).insert(
            ParseAuditRowsCompanion.insert(
              occurredAt: DateTime.now(),
              schemaVersion: schemaVersion,
              provider: provider.wire,
              capabilityTier: tier.code,
              latencyBucket: latencyBucket.label,
              outcome: outcome,
              draftCount: Value<int>(draftCount),
              errorCode: Value<String?>(errorCode),
            ),
          );
        },
  );
});

/// Re-probed on resume rather than cached for the app's lifetime, because a
/// model can be enabled, disabled, or finish downloading at any time.
final capabilitiesProvider = FutureProvider<LocalAiCapabilities>(
  (ref) => ref.watch(localAiProvider).capabilities(),
);

final taskServiceProvider = Provider<TaskService>(
  (ref) => TaskService(
    repository: ref.watch(taskRepositoryProvider),
    scheduler: ref.watch(reminderSchedulerProvider),
    widgetSyncService: ref.watch(widgetSyncServiceProvider),
  ),
);

final tagsProvider = StreamProvider<List<Tag>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTags(),
);

/// Tasks due today or already overdue, plus today's completions.
final todayTasksProvider = StreamProvider<TodayView>((ref) {
  final now = ref.watch(clockProvider)();
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  final repository = ref.watch(taskRepositoryProvider);

  return repository
      .watchTasks(
        TaskQuery(
          statuses: const <TaskStatus>{
            TaskStatus.active,
            TaskStatus.completed,
          },
          dueBefore: startOfTomorrow,
        ),
      )
      .map((tasks) {
        final startOfToday = DateTime(now.year, now.month, now.day);
        return TodayView(
          overdue: tasks
              .where((task) => !task.isCompleted && task.isOverdueAt(now))
              .where((task) => task.effectiveDate!.isBefore(startOfToday))
              .toList(),
          today: tasks
              .where((task) => !task.isCompleted && task.isDueOn(now))
              .toList(),
          completedToday: tasks
              .where(
                (task) =>
                    task.isCompleted &&
                    task.completedAt != null &&
                    !task.completedAt!.isBefore(startOfToday),
              )
              .toList(),
        );
      });
});

/// Dated tasks from tomorrow onward, grouped by day.
final upcomingTasksProvider = StreamProvider<List<UpcomingDay>>((ref) {
  final now = ref.watch(clockProvider)();
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);

  return ref
      .watch(taskRepositoryProvider)
      .watchTasks(TaskQuery(dueAfter: startOfTomorrow))
      .map((tasks) {
        final grouped = <DateTime, List<Task>>{};
        for (final task in tasks) {
          final date = task.effectiveDate;
          if (date == null) continue;
          final day = DateTime(date.year, date.month, date.day);
          grouped.putIfAbsent(day, () => <Task>[]).add(task);
        }
        final days = grouped.keys.toList()..sort();
        return days
            .map((day) => UpcomingDay(day: day, tasks: grouped[day]!))
            .toList();
      });
});

/// Everything with no date at all.
final inboxTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref
      .watch(taskRepositoryProvider)
      .watchTasks(const TaskQuery(onlyUnscheduled: true)),
);

final completedTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(
    const TaskQuery(statuses: <TaskStatus>{TaskStatus.completed}),
  ),
);

final taskDetailProvider = StreamProvider.family<Task?, String>(
  (ref, id) => ref.watch(taskRepositoryProvider).watchTask(id),
);

/// Grouped payload for the Today screen, so the UI does not re-derive it on
/// every rebuild.
class TodayView {
  const TodayView({
    required this.overdue,
    required this.today,
    required this.completedToday,
  });

  final List<Task> overdue;
  final List<Task> today;
  final List<Task> completedToday;

  bool get isEmpty =>
      overdue.isEmpty && today.isEmpty && completedToday.isEmpty;

  int get remaining => overdue.length + today.length;
}

class UpcomingDay {
  const UpcomingDay({required this.day, required this.tasks});

  final DateTime day;
  final List<Task> tasks;
}

/// Re-probes capabilities and reconciles reminders whenever the app returns to
/// the foreground.
class LifecycleReconciler extends WidgetsBindingObserver {
  LifecycleReconciler(this._ref);

  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final router = _ref.read(localAiProvider);
    router.isForeground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) return;

    // All best-effort background repairs; none blocks the UI.
    _ref.invalidate(capabilitiesProvider);
    _ref.read(taskServiceProvider).reconcileReminders();
    // A notification button may have changed tasks from its own isolate
    // while this one was suspended; its signal can be missed, this cannot.
    refreshAfterExternalWrite(_ref.read(appDatabaseProvider));
  }
}

/// Re-runs every live query. Drift only notices writes made through its own
/// connection, so a change from the notification-action isolate needs this
/// to reach the lists on screen.
void refreshAfterExternalWrite(AppDatabase database) {
  database.markTablesUpdated(database.allTables);
}

final lifecycleReconcilerProvider = Provider<LifecycleReconciler>((ref) {
  final observer = LifecycleReconciler(ref);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  return observer;
});
