import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'motion_prefs.dart';

/// Cross-fades between sibling surfaces that all stay alive.
///
/// [IndexedStack] preserves scroll position but changes tabs as a hard cut,
/// which makes four related views feel like four unrelated apps. An
/// [AnimatedSwitcher] would animate but destroys the outgoing subtree, losing
/// scroll position and re-running every provider subscription.
///
/// This keeps both properties: every child stays mounted and laid out, and only
/// the two children involved in a change are painted during it. The outgoing
/// surface accelerates away and the incoming one decelerates in from the side
/// it "lives" on, so moving right through the tab bar moves the content right —
/// the bar and the page agree about which direction the app is going.
class SurfaceSwitcher extends StatefulWidget {
  const SurfaceSwitcher({
    required this.index,
    required this.children,
    this.travel = 16,
    super.key,
  });

  final int index;
  final List<Widget> children;

  /// Horizontal distance each surface covers, in logical pixels. Short on
  /// purpose: a full-width slide between peer tabs implies they are pages in a
  /// sequence, which these are not — and the further they travel, the longer
  /// the tab takes to become readable.
  final double travel;

  @override
  State<SurfaceSwitcher> createState() => _SurfaceSwitcherState();
}

class _SurfaceSwitcherState extends State<SurfaceSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.page,
    value: 1,
  );

  late int _current = widget.index;
  int? _outgoing;

  @override
  void didUpdateWidget(SurfaceSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == _current) return;
    // A change mid-transition hands the previous outgoing surface straight to
    // the finished state rather than trying to animate three at once.
    _outgoing = _current;
    _current = widget.index;
    _controller
      ..duration = context.motion(Motion.page)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final settled = t >= 1;
        final direction = (_outgoing != null && _current > _outgoing!) ? 1 : -1;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            for (var i = 0; i < widget.children.length; i++)
              _surface(i, t, settled, direction),
          ],
        );
      },
    );
  }

  Widget _surface(int i, double t, bool settled, int direction) {
    final isCurrent = i == _current;
    final isOutgoing = !settled && i == _outgoing;

    // Everything not taking part stays in the tree — and so keeps its scroll
    // offset and provider subscriptions — but is not painted, hit-tested, or
    // ticked. TickerMode is what stops four surfaces animating at once.
    if (!isCurrent && !isOutgoing) {
      return Offstage(child: _content(i, ticking: false));
    }

    if (settled && isCurrent) {
      return _content(i, ticking: true);
    }

    final double opacity;
    final double dx;
    final double scale;
    if (isCurrent) {
      // Overlaps the outgoing surface rather than waiting for it. A staged
      // hand-off (fade one out, then the other in) is cleaner in the abstract
      // and reads as lag on a tab bar, where the user has already decided.
      opacity = Curves.easeOut.transform(Interval(0.1, 1).transform(t));
      dx = (1 - Motion.decelerate.transform(t)) * widget.travel * direction;
      scale = lerpDouble(0.995, 1, Motion.decelerate.transform(t))!;
    } else {
      final out = Interval(0, 0.55, curve: Motion.accelerate).transform(t);
      opacity = 1 - out;
      dx = -out * widget.travel * direction;
      scale = lerpDouble(1, 0.995, out)!;
    }

    return IgnorePointer(
      ignoring: !isCurrent,
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: scale,
            child: _content(i, ticking: isCurrent),
          ),
        ),
      ),
    );
  }

  /// A surface, in its own compositing layer.
  ///
  /// The [RepaintBoundary] is what makes this transition affordable, and it is
  /// not optional. Fading and moving a subtree costs a full re-rasterisation of
  /// everything inside it on every frame — here, two entire screens of text and
  /// cards, sixty times a second. Behind a repaint boundary the surface is
  /// rasterised once and the opacity and transforms become layer properties the
  /// GPU applies to the cached texture, which is close to free.
  ///
  /// It sits inside [TickerMode] rather than outside so the boundary — and the
  /// cached layer with it — survives a surface going from ticking to not.
  Widget _content(int i, {required bool ticking}) {
    return RepaintBoundary(
      child: TickerMode(enabled: ticking, child: widget.children[i]),
    );
  }
}
