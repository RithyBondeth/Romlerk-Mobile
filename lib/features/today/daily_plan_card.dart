import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/illustrated_content.dart';
import '../../core/motion/motion_prefs.dart';
import '../../core/motion/pressable.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/entities/task.dart';
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
    final today = ref.watch(todayTasksProvider).valueOrNull;
    final available = today == null
        ? planned
        : <Task>[...today.overdue, ...today.today];
    final progress = planned.isEmpty ? 0.0 : done / planned.length;
    final semantics = context.semantics;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.gutter,
        vertical: Insets.sm,
      ),
      child: Pressable(
        scale: 0.99,
        child: Material(
          color: semantics.accentSoft,
          borderRadius: Corners.group,
          child: InkWell(
            borderRadius: Corners.group,
            onTap: () => DailyPlanningSheet.show(context, available),
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IllustratedContent(
                    illustration: 'coffee',
                    artSize: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.planMyDay,
                                style: context.texts.titleLarge?.copyWith(
                                  color: context.colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Icon(
                              LucideIcons.arrowUpRight,
                              size: 18,
                              color: context.colors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          plan == null
                              ? context.l10n.planEmpty
                              : context.l10n.planProgress(done, planned.length),
                          style: context.texts.bodyMedium?.copyWith(
                            color: context.colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (plan != null) ...[
                    const SizedBox(height: Insets.md),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: context.motion(Motion.expressive),
                      curve: Motion.standard,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        borderRadius: Corners.pill,
                        backgroundColor: context.colors.primary.withValues(
                          alpha: 0.12,
                        ),
                        semanticsLabel: context.l10n.planProgress(
                          done,
                          planned.length,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
