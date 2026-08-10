import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/local/settings_store.dart';
import '../data/export/task_exporter.dart';
import '../data/repositories/drift_task_repository.dart';
import '../core/format/task_formatting.dart';
import '../domain/entities/tag.dart';
import '../domain/entities/task.dart';
import '../domain/enums.dart';
import '../domain/repositories/task_repository.dart';
import '../local_ai/capabilities.dart';
import '../local_ai/capability_router.dart';
import '../local_ai/deterministic/deterministic_parser.dart';
import '../local_ai/local_ai.dart';
import '../local_ai/platform/platform_local_ai.dart';
import '../services/notifications/reminder_scheduler.dart';
import 'task_service.dart';

/// Injection point for tests: override with a fixed instant to make
/// date-dependent widgets deterministic.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
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

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler();
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

final taskExporterProvider = Provider<TaskExporter>(
  (ref) => const TaskExporter(),
);

final formattingProvider = Provider<TaskFormatting>(
  (ref) => const TaskFormatting(),
);

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

    // Both are best-effort background repairs; neither blocks the UI.
    _ref.invalidate(capabilitiesProvider);
    _ref.read(taskServiceProvider).reconcileReminders();
  }
}

final lifecycleReconcilerProvider = Provider<LifecycleReconciler>((ref) {
  final observer = LifecycleReconciler(ref);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  return observer;
});
