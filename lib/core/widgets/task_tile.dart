import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/entities/task.dart';
import '../../domain/enums.dart';
import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import '../format/task_formatting.dart';

/// One task in a list.
///
/// The layout is a single line of title over a quiet meta row, so a screen of
/// tasks reads as a list of commitments rather than a grid of cards. Status is
/// carried by more than colour (NFR-10): overdue also gets a left rule and the
/// word "overdue", completed also gets strikethrough.
class TaskTile extends StatelessWidget {
  const TaskTile({
    required this.task,
    required this.now,
    required this.formatting,
    this.onTap,
    this.onToggleComplete,
    this.showDate = true,
    super.key,
  });

  final Task task;
  final DateTime now;
  final TaskFormatting formatting;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  /// Off in Today, where the grouping already implies the day.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final isOverdue = task.isOverdueAt(now);
    final accent = isOverdue ? semantics.overdue : null;

    return Semantics(
      button: true,
      label: _accessibilityLabel(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Insets.minTapTarget + 8),
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.md,
            Insets.lg,
            Insets.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: accent ?? Colors.transparent,
                width: accent == null ? 0 : 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Checkbox(
                completed: task.isCompleted,
                onChanged: onToggleComplete,
                priority: task.priority,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: context.texts.bodyLarge?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted ? semantics.muted : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_metaChildren(context).isNotEmpty) ...<Widget>[
                      const SizedBox(height: Insets.xs + 2),
                      Wrap(
                        spacing: Insets.sm,
                        runSpacing: Insets.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: _metaChildren(context),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _metaChildren(BuildContext context) {
    final semantics = context.semantics;
    final isOverdue = task.isOverdueAt(now);
    final children = <Widget>[];
    final date = task.effectiveDate;

    if (date != null && showDate) {
      children.add(
        _Meta(
          icon: LucideIcons.clock,
          label: isOverdue
              ? formatting.overdueBy(date, now)
              : formatting.relative(date, now: now),
          color: isOverdue ? semantics.overdue : null,
        ),
      );
    } else if (date != null && !showDate) {
      children.add(_Meta(icon: LucideIcons.clock, label: formatting.timeOnly(date)));
    }

    if (task.isRecurring) {
      children.add(
        _Meta(
          icon: LucideIcons.repeat,
          label: formatting.recurrence(task.recurrence!),
        ),
      );
    }

    if (task.durationMinutes != null) {
      children.add(
        _Meta(
          icon: LucideIcons.hourglass,
          label: formatting.duration(task.durationMinutes!),
        ),
      );
    }

    // A reminder that will not fire is one of the few things worth
    // interrupting a list row for (US-07).
    if (task.hasReminderProblem) {
      children.add(
        _Meta(
          icon: LucideIcons.bellOff,
          label: 'Reminder not set',
          color: semantics.overdue,
        ),
      );
    }

    for (final tag in task.tags) {
      children.add(_TagDot(tag: tag.name, color: Color(tag.colorValue)));
    }

    return children;
  }

  String _accessibilityLabel() {
    final parts = <String>[task.title];
    if (task.isCompleted) parts.add('completed');
    final date = task.effectiveDate;
    if (date != null) {
      parts.add(
        task.isOverdueAt(now)
            ? formatting.overdueBy(date, now)
            : 'due ${formatting.exact(date, now: now)}',
      );
    }
    if (task.priority != TaskPriority.none) {
      parts.add('${formatting.priority(task.priority)} priority');
    }
    return parts.join(', ');
  }
}

/// Round checkbox with a priority-coloured ring.
///
/// The ring is how priority is shown in lists: always visible, never relying
/// on colour alone because the ring thickness changes too.
class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.completed,
    required this.priority,
    this.onChanged,
  });

  final bool completed;
  final TaskPriority priority;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final ringColor = switch (priority) {
      TaskPriority.high => semantics.overdue,
      TaskPriority.medium => context.colors.primary,
      TaskPriority.low => semantics.muted,
      TaskPriority.none => semantics.hairline,
    };
    final ringWidth = switch (priority) {
      TaskPriority.high => 2.5,
      TaskPriority.medium => 2.0,
      _ => 1.5,
    };

    return Semantics(
      checked: completed,
      label: completed ? 'Completed' : 'Mark complete',
      child: InkResponse(
        onTap: onChanged,
        radius: Insets.xl,
        child: SizedBox(
          width: Insets.minTapTarget - 20,
          height: Insets.minTapTarget - 20,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Motion.easing,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? semantics.completed : Colors.transparent,
                border: Border.all(
                  color: completed ? semantics.completed : ringColor,
                  width: completed ? 0 : ringWidth,
                ),
              ),
              child: completed
                  ? Icon(
                      LucideIcons.check,
                      size: 14,
                      color: context.colors.surface,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.semantics.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: resolved),
        const SizedBox(width: Insets.xs),
        Text(
          label,
          style: context.texts.bodySmall?.copyWith(color: resolved),
        ),
      ],
    );
  }
}

class _TagDot extends StatelessWidget {
  const _TagDot({required this.tag, required this.color});

  final String tag;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Insets.xs + 1),
        Text(
          tag,
          style: context.texts.bodySmall?.copyWith(
            color: context.semantics.muted,
          ),
        ),
      ],
    );
  }
}
