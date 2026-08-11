import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'motion_prefs.dart';

/// Gives a control a physical press.
///
/// A ripple tells you *where* you touched; a scale tells you the thing you
/// touched is a control at all, and it does so on the same frame as the finger
/// rather than after the tap resolves. The two are complementary, so this
/// deliberately does not replace [InkWell] — it wraps around one.
///
/// It listens on the pointer stream rather than adding a gesture recognizer, so
/// it never competes in the gesture arena with the tap handler inside it. The
/// cost is that dragging a finger off the control does not release the scale
/// until the pointer lifts, which is the right trade: the alternative is a
/// control whose ripple and scale can disagree about whether it is pressed.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
    super.key,
  });

  final Widget child;

  /// How far down the control travels. Kept shallow — a deep press on a
  /// full-width bar reads as the whole page flexing.
  final double scale;

  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value || !widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        // Down fast and flat, back up slower and with a little overshoot, so
        // release feels like weight leaving rather than a snap.
        duration: context.motion(_pressed ? Motion.micro : Motion.normal),
        curve: context.motionCurve(
          _pressed ? Motion.accelerate : Motion.settle,
        ),
        child: widget.child,
      ),
    );
  }
}
