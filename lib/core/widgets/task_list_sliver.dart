import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/task.dart';
import '../../features/task_detail/task_detail_page.dart';
import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import 'group_card.dart';
import 'task_tile.dart';

/// The one list body every task surface uses.
///
/// Keeping completion, navigation, grouping, and separators in a single place
/// means Today, Upcoming, Inbox, and Search cannot drift apart in behaviour or
/// in looks.
class TaskListSliver extends ConsumerWidget {
  const TaskListSliver({
    required this.tasks,
    required this.now,
    this.showDate = true,
    this.accent,
    super.key,
  });

  final List<Task> tasks;
  final DateTime now;
  final bool showDate;

  /// Tints the group's border — set for overdue.
  final Color? accent;

  /// Left edge of the separator, aligned with the start of the title column so
  /// the rules read as part of the text block rather than as full-width cuts.
  static const double _separatorIndent = Insets.md + 36 + Insets.sm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatting = ref.watch(formattingProvider);
    final service = ref.watch(taskServiceProvider);
    final last = tasks.length - 1;

    return SliverGroupCard(
      accent: accent,
      sliver: SliverList.separated(
        itemCount: tasks.length,
        separatorBuilder: (context, _) => Divider(
          color: context.semantics.hairline,
          indent: _separatorIndent,
          endIndent: Insets.lg,
        ),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskTile(
            task: task,
            now: now,
            formatting: formatting,
            showDate: showDate,
            borderRadius: switch (index) {
              0 when index == last => Corners.group,
              0 => Corners.groupTop,
              _ when index == last => Corners.groupBottom,
              _ => null,
            },
            onTap: () => TaskDetailPage.open(context, task.id),
            onToggleComplete: () => task.isCompleted
                ? service.reopenTask(task.id)
                : service.completeTask(task.id),
          );
        },
      ),
    );
  }
}
