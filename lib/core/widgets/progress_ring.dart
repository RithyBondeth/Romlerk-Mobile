import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// How much of today is behind you, as a ring.
///
/// Deliberately not a score: an empty day reads as "nothing to do" rather than
/// "0%", and a finished day fills to a quiet moss rather than congratulating
/// anyone. It exists to make the header feel alive, not to gamify the list.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.completed,
    required this.total,
    this.size = 52,
    super.key,
  });

  final int completed;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final fraction = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final isDone = total > 0 && completed >= total;
    final accent = isDone ? semantics.completed : context.colors.primary;

    return Semantics(
      label: total == 0
          ? 'Nothing scheduled'
          : '$completed of $total tasks complete',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraction),
            duration: Motion.expressive,
            curve: Motion.easing,
            builder: (context, value, _) {
              return CustomPaint(
                painter: _RingPainter(
                  fraction: value,
                  track: semantics.hairline,
                  accent: accent,
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check_rounded, size: 22, color: accent)
                      : Text(
                          '${total - completed}',
                          style: context.texts.titleMedium?.copyWith(
                            fontSize: size * 0.34,
                            letterSpacing: -0.5,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.accent,
  });

  final double fraction;
  final Color track;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.5;
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(inner, 0, math.pi * 2, false, trackPaint);

    if (fraction <= 0) return;

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawArc(
      inner,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}
