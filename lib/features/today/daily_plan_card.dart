import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/entities/task.dart';
import '../../core/design/design_tokens.dart';
import '../../l10n/l10n.dart';
import 'daily_planning_sheet.dart';

final plannedTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref
      .watch(taskRepositoryProvider)
      .watchTasks(
        const TaskQuery(statuses: {TaskStatus.active, TaskStatus.completed}),
      ),
);

class DailyPlanCard extends ConsumerWidget {
  const DailyPlanCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final date = DateTime(now.year, now.month, now.day);
    final plan = ref.watch(dailyPlanProvider(date)).valueOrNull;
    final all = ref.watch(plannedTasksProvider).valueOrNull ?? [];
    final planned = all
        .where((t) => plan?.occurrences.containsKey(t.id) ?? false)
        .toList();
    final done = planned.where((t) => plan!.completed(t)).length;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.gutter,
        vertical: Insets.sm,
      ),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(
          plan == null
              ? context.l10n.planMyDay
              : context.l10n.planProgress(done, planned.length),
        ),
        onPressed: () => DailyPlanningSheet.show(context, planned),
      ),
    );
  }
}
