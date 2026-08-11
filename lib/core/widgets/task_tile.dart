import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/entities/task.dart';
import '../../domain/enums.dart';
import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import '../format/task_formatting.dart';
import '../motion/motion_prefs.dart';

/// One task in a list.
///
/// The layout is a line of title over a quiet meta row, so a screen of tasks
/// reads as a list of commitments rather than a grid of cards. Status is
/// carried by more than colour (NFR-10): an overdue task also gets a warning
/// glyph and the words "2 days overdue", and a completed one also gets
/// strikethrough and reduced opacity.
///
/// Completing writes immediately. An earlier version held the write for the
/// length of a completion animation, on the theory that the write re-sorts the
/// list and destroys the row before the animation can be seen. That theory was
/// right and the conclusion was wrong: half a second between tapping a checkbox
/// and the list responding is worse than an animation nobody finishes watching.
/// The feedback that matters is instant anyway — haptics on the frame of the
/// tap, and the progress ring in the header, which survives the row.
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

  void _toggle() {
    if (onToggleComplete == null) return;
    HapticFeedback.selectionClick();
    onToggleComplete!();
  }

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final completed = task.isCompleted;

    return Semantics(
      button: true,
      label: _accessibilityLabel(),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: semantics.accentSoft.withValues(alpha: 0.5),
        highlightColor: semantics.sunken.withValues(alpha: 0.6),
        child: AnimatedOpacity(
          duration: context.motion(Motion.fast),
          curve: Motion.easing,
          opacity: completed ? 0.62 : 1,
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
                  completed: completed,
                  onChanged: onToggleComplete == null ? null : _toggle,
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
                        child: _Title(title: task.title, completed: completed),
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

/// The task title, easing from ink to muted as it is struck through.
///
/// Deliberately one [Text] rather than a crossfade of two. A crossfade would
/// let the rule draw itself in, but it puts the title in the tree twice, and a
/// task list where every title exists in duplicate is a trap for anything that
/// reads the tree — assistive technology, tests, and future find-by-text code
/// all get the wrong answer.
///
/// So the colour, which [TextStyle.lerp] interpolates properly, carries the
/// transition, and the strikethrough — which it cannot interpolate, and flips
/// at the midpoint — lands under the colour shift.
class _Title extends StatelessWidget {
  const _Title({required this.title, required this.completed});

  final String title;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final base = context.texts.bodyLarge!.copyWith(
      fontWeight: FontWeight.w500,
    );

    return AnimatedDefaultTextStyle(
      duration: context.motion(Motion.expressive),
      curve: Motion.standard,
      style: base.copyWith(
        color: completed ? semantics.muted : base.color,
        decoration: completed ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: semantics.muted,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      child: Text(title),
    );
  }
}

/// Round checkbox with a priority-coloured ring.
///
/// The ring is how priority is shown in lists: always visible, never relying
/// on colour alone because the ring thickness changes too.
///
/// Ticking it fills the ring from the rim inward and draws the check as a
/// stroke rather than fading it in — the mark is made, the way it would be on
/// paper. It is one implicit tween off a bool, so a tile built already-ticked
/// (scrolled into view, or rebuilt after the write landed) simply renders the
/// end state, with nothing to replay.
class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.completed,
    required this.priority,
    this.onChanged,
  });

  final bool completed;
  final TaskPriority priority;
  final VoidCallback? onChanged;

  static const double _size = 22;

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
        containedInkWell: false,
        child: SizedBox(
          width: Insets.minTapTarget - 12,
          height: Insets.minTapTarget - 14,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: completed ? 1 : 0),
              duration: context.motion(Motion.expressive),
              curve: Motion.decelerate,
              builder: (context, progress, _) => CustomPaint(
                size: const Size.square(_size),
                painter: _CheckboxPainter(
                  progress: progress,
                  ringColor: ringColor,
                  ringWidth: ringWidth,
                  fill: semantics.completed,
                  mark: semantics.isDark
                      ? const Color(0xFF0F2413)
                      : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckboxPainter extends CustomPainter {
  const _CheckboxPainter({
    required this.progress,
    required this.ringColor,
    required this.ringWidth,
    required this.fill,
    required this.mark,
  });

  /// 0 = empty ring, 1 = filled with a fully drawn check.
  final double progress;

  final Color ringColor;
  final double ringWidth;
  final Color fill;
  final Color mark;

  /// The fill and the check overlap: the stroke starts before the disc has
  /// finished arriving, so the two read as one gesture instead of two events.
  static const _Phase _flood = _Phase(0, 0.72);
  static const _Phase _draw = _Phase(0.28, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final t = progress.clamp(0.0, 1.0);

    // A single small overshoot, so ticking has some weight to it. Deliberately
    // not a squash-then-pop: at this duration a two-stage bounce on a 22pt
    // circle reads as a stutter, not as physics.
    final radius =
        (_Checkbox._size / 2) * lerpDouble(1, 1.08, Motion.settle.transform(t))!;

    final flood = Curves.easeOutCubic.transform(_flood.of(t));

    // The empty ring, fading out under the fill rather than being replaced by
    // it, so there is never a frame with neither drawn.
    if (flood < 1) {
      canvas.drawCircle(
        centre,
        radius - ringWidth / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..color = Color.lerp(ringColor, fill, flood)!,
      );
    }

    if (flood > 0) {
      // Floods from the rim inward: a disc growing from the centre would read
      // as a dot appearing, not as the ring filling up.
      //
      // A stroke straddles its radius, so the filled band runs from
      // `centre ± width / 2`. Placing the band's midpoint at
      // `radius * (1 - flood / 2)` keeps its outer edge pinned to the rim and
      // walks its inner edge to the centre — at flood 1 that is exactly a solid
      // disc of `radius`, with no hole left in the middle and nothing spilling
      // past the rim.
      canvas.drawCircle(
        centre,
        radius * (1 - flood / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * flood
          ..color = fill,
      );
    }

    final drawn = Curves.easeOutCubic.transform(_draw.of(t));
    if (drawn <= 0) return;

    // The check, in the proportions of a hand-made tick: a short down-stroke
    // into a long up-stroke, both scaled to the ring.
    final u = radius * 2;
    final origin = centre - Offset(u / 2, u / 2);
    final path = Path()
      ..moveTo(origin.dx + u * 0.26, origin.dy + u * 0.52)
      ..lineTo(origin.dx + u * 0.44, origin.dy + u * 0.70)
      ..lineTo(origin.dx + u * 0.76, origin.dy + u * 0.32);

    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * drawn),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = mark,
    );
  }

  @override
  bool shouldRepaint(_CheckboxPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.ringWidth != ringWidth ||
      oldDelegate.fill != fill ||
      oldDelegate.mark != mark;
}

/// A window onto the parent animation, so each part of the completion sequence
/// can be written in its own 0–1 terms.
class _Phase {
  const _Phase(this.begin, this.end);

  final double begin;
  final double end;

  double of(double t) => ((t - begin) / (end - begin)).clamp(0.0, 1.0);
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
