import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/entities/task.dart';
import '../../domain/enums.dart';
import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import '../format/task_formatting.dart';

/// One task in a list.
///
/// The layout is a line of title over a quiet meta row, so a screen of tasks
/// reads as a list of commitments rather than a grid of cards. Status is
/// carried by more than colour (NFR-10): an overdue task also gets a warning
/// glyph and the words "2 days overdue", and a completed one also gets
/// strikethrough and reduced opacity.
class TaskTile extends StatelessWidget {
  const TaskTile({
    required this.task,
    required this.now,
    required this.formatting,
    this.onTap,
    this.onToggleComplete,
    this.showDate = true,
    this.borderRadius,
    super.key,
  });

  final Task task;
  final DateTime now;
  final TaskFormatting formatting;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  /// Off in Today, where the grouping already implies the day.
  final bool showDate;

  /// Set for the first and last row of a grouped card so a tap ripple cannot
  /// spill past the card's rounded corner.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Semantics(
      button: true,
      label: _accessibilityLabel(),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: semantics.accentSoft.withValues(alpha: 0.5),
        highlightColor: semantics.sunken.withValues(alpha: 0.6),
        child: AnimatedOpacity(
          duration: Motion.normal,
          curve: Motion.easing,
          opacity: task.isCompleted ? 0.62 : 1,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: Insets.minTapTarget + 12,
            ),
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.md,
              Insets.lg,
              Insets.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Checkbox(
                  completed: task.isCompleted,
                  onChanged: onToggleComplete,
                  priority: task.priority,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        // Optically centres the title against the ring.
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.title,
                          style: context.texts.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: semantics.muted,
                            color: task.isCompleted ? semantics.muted : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final meta = _metaChildren(context);
                          if (meta.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: Insets.sm),
                            child: Wrap(
                              spacing: Insets.sm,
                              runSpacing: Insets.sm - 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: meta,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        isOverdue
            // The one meta that earns a filled background: an overdue date is
            // the reason this row is at the top of the screen.
            ? _MetaPill(
                icon: LucideIcons.triangleAlert,
                label: formatting.overdueBy(date, now),
                foreground: semantics.overdue,
                background: semantics.overdueSoft,
              )
            : _MetaPill(
                icon: LucideIcons.clock,
                label: formatting.relative(date, now: now),
                foreground: semantics.muted,
                background: semantics.sunken,
              ),
      );
    } else if (date != null && !showDate) {
      children.add(
        _MetaPill(
          icon: LucideIcons.clock,
          label: formatting.timeOnly(date),
          foreground: semantics.muted,
          background: semantics.sunken,
        ),
      );
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
        _MetaPill(
          icon: LucideIcons.bellOff,
          label: 'Reminder not set',
          foreground: semantics.overdue,
          background: semantics.overdueSoft,
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
/// on colour alone because the ring thickness changes too. Completing pops the
/// ring briefly — the single piece of expressive motion in the app, and the
/// only moment that deserves one.
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
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!();
              },
        radius: Insets.xl,
        containedInkWell: false,
        child: SizedBox(
          width: Insets.minTapTarget - 12,
          height: Insets.minTapTarget - 14,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.expressive,
              curve: Motion.emphasized,
              width: completed ? 23 : 22,
              height: completed ? 23 : 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? semantics.completed : Colors.transparent,
                border: Border.all(
                  color: completed ? semantics.completed : ringColor,
                  width: completed ? 0 : ringWidth,
                ),
              ),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: completed
                    ? Icon(
                        LucideIcons.check,
                        key: const ValueKey<bool>(true),
                        size: 14,
                        color: semantics.isDark
                            ? const Color(0xFF0F2413)
                            : Colors.white,
                      )
                    : const SizedBox.shrink(key: ValueKey<bool>(false)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A meta fact with a background — used only where the fact changes what the
/// user should do next.
class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: Corners.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: Insets.xs + 1),
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final resolved = context.semantics.muted;
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
