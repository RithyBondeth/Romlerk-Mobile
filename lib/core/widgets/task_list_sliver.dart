import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/task.dart';
import '../../features/task_detail/task_detail_page.dart';
import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import 'task_tile.dart';

/// The one list body every task surface uses.
///
/// Keeping completion, navigation, and separators in a single place means
/// Today, Upcoming, Inbox, and Search cannot drift apart in behaviour.
class TaskListSliver extends ConsumerWidget {
  const TaskListSliver({
    required this.tasks,
    required this.now,
    this.showDate = true,
    super.key,
  });

  final List<Task> tasks;
  final DateTime now;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatting = ref.watch(formattingProvider);
    final service = ref.watch(taskServiceProvider);

    return SliverList.separated(
      itemCount: tasks.length,
      separatorBuilder: (context, _) =>
          Divider(color: context.semantics.hairline, indent: Insets.lg + 40),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskTile(
          task: task,
          now: now,
          formatting: formatting,
          showDate: showDate,
          onTap: () => TaskDetailPage.open(context, task.id),
          onToggleComplete: () => task.isCompleted
              ? service.reopenTask(task.id)
              : service.completeTask(task.id),
        );
      },
    );
  }
}
