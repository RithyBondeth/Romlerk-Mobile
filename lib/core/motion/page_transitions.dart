import 'dart:ui' show lerpDouble;

// Imported for [CupertinoPageTransitionsBuilder], which material.dart does not
// re-export. Nothing else Cupertino is used in the app.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'motion_prefs.dart';

/// How a pushed page arrives on platforms without a system convention for it.
///
/// The incoming page rises through the outgoing one rather than sliding over
/// it: opening a task is a change of depth, not a step sideways, and the paper
/// metaphor makes "the sheet you tapped comes forward" the honest reading. The
/// page underneath dims and recedes slightly, which gives the stack a physical
/// order without a drop shadow.
///
/// Apple platforms keep their own builder. The horizontal slide there is not a
/// style choice — it is the visual half of the interactive back-swipe, which
/// [CupertinoPageTransitionsBuilder] installs along with the animation. A
/// custom transition would silently cost every iOS user that gesture.
class DepthPageTransitionsBuilder extends PageTransitionsBuilder {
  const DepthPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _Depth(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _Depth extends StatelessWidget {
  const _Depth({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Route transitions are not covered by the implicit-animation opt-out, so
    // the check has to be explicit here.
    if (context.prefersReducedMotion) return child;

    final enter = CurvedAnimation(
      parent: animation,
      curve: Motion.decelerate,
      reverseCurve: Motion.accelerate.flipped,
    );
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.standard,
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[enter, exit]),
      child: child,
      builder: (context, child) {
        final t = enter.value;
        final s = exit.value;
        return Opacity(
          // Fades in over the first half only, so the page is fully legible
          // while it is still finishing its travel.
          opacity: (t * 2).clamp(0.0, 1.0),
          child: Transform.scale(
            // Grows into place on the way in; shrinks away when a further page
            // is pushed on top of it.
            scale: lerpDouble(0.94, 1, t)! * lerpDouble(1, 0.96, s)!,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 24),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Page transitions for every platform, with Apple's left intact.
const PageTransitionsTheme romlerkPageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: DepthPageTransitionsBuilder(),
    TargetPlatform.fuchsia: DepthPageTransitionsBuilder(),
    TargetPlatform.linux: DepthPageTransitionsBuilder(),
    TargetPlatform.windows: DepthPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);
