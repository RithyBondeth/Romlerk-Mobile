import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import '../motion/motion_prefs.dart';

/// How much of today is behind you, as a ring.
///
/// Deliberately not a score: an empty day reads as "nothing to do" rather than
/// "0%", and a finished day fills to a quiet moss rather than congratulating
/// anyone. It exists to make the header feel alive, not to gamify the list.
///
/// The arc is the only thing in the header that moves on its own, so it is the
/// app's ambient confirmation that a tap landed: complete a task anywhere on
/// the page and the ring sweeps forward. The number counts rather than cuts,
/// for the same reason — a digit that changes between frames is a fact you have
/// to re-read, while one that moves is a change you can watch happen.
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
            duration: context.motion(Motion.expressive),
            curve: Motion.standard,
            builder: (context, value, _) {
              return TweenAnimationBuilder<Color?>(
                // The colour shift to moss is slower than the sweep, so the
                // ring is seen to *finish* and then turn, rather than changing
                // meaning while it is still moving.
                tween: ColorTween(end: accent),
                duration: context.motion(Motion.page),
                curve: Motion.easing,
                builder: (context, colour, _) {
                  return CustomPaint(
                    painter: _RingPainter(
                      fraction: value,
                      track: semantics.hairline,
                      accent: colour ?? accent,
                    ),
                    child: Center(
                      child: _Remaining(
                        remaining: total - completed,
                        isDone: isDone,
                        accent: colour ?? accent,
                        size: size,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The count at the centre of the ring.
///
/// Counting down is a slide, not a cut: the old figure leaves upward and the
/// new one arrives from below, which is the direction the number is going.
/// Reaching zero swaps the count for a check that scales in over the top.
class _Remaining extends StatelessWidget {
  const _Remaining({
    required this.remaining,
    required this.isDone,
    required this.accent,
    required this.size,
  });

  final int remaining;
  final bool isDone;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(Motion.normal),
      switchInCurve: Motion.decelerate,
      switchOutCurve: Motion.accelerate,
      transitionBuilder: (child, animation) {
        final isCheck = child.key == const ValueKey<String>('done');
        final slide = SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, isCheck ? 0 : 0.55),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
        return FadeTransition(
          opacity: animation,
          child: isCheck
              ? ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1).animate(
                    CurvedAnimation(parent: animation, curve: Motion.settle),
                  ),
                  child: slide,
                )
              : slide,
        );
      },
      // Both figures occupy the same spot mid-swap instead of pushing each
      // other around the centre of the ring.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: <Widget>[...previous, ?current],
      ),
      child: isDone
          ? Icon(
              Icons.check_rounded,
              key: const ValueKey<String>('done'),
              size: size * 0.42,
              color: accent,
            )
          : Text(
              '$remaining',
              key: ValueKey<int>(remaining),
              style: context.texts.titleMedium?.copyWith(
                fontSize: size * 0.34,
                letterSpacing: -0.5,
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

    // A soft wash under the arc's leading portion. It reads as the arc having
    // just been laid down rather than as a glow effect — enough to give the
    // sweep a direction without introducing a second colour to the palette.
    canvas.drawArc(
      inner,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 2.4
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.13),
    );

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
