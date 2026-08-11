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

  /// Fades in over the first half of the travel only, so the page is fully
  /// legible while it is still finishing its move.
  static final Animatable<double> _fade = CurveTween(
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );

  /// Grows into place on the way in.
  static final Animatable<double> _enterScale = Tween<double>(
    begin: 0.94,
    end: 1,
  ).chain(CurveTween(curve: Motion.decelerate));

  /// A short rise, as a fraction of the page's own height rather than a pixel
  /// count, so it reads the same on any screen size.
  static final Animatable<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).chain(CurveTween(curve: Motion.decelerate));

  /// Recedes when a further page is pushed on top of this one.
  static final Animatable<double> _exitScale = Tween<double>(
    begin: 1,
    end: 0.96,
  ).chain(CurveTween(curve: Motion.standard));

  @override
  Widget build(BuildContext context) {
    // Route transitions are not covered by the implicit-animation opt-out, so
    // the check has to be explicit here.
    if (context.prefersReducedMotion) return child;

    // Built from `Animatable`s driven through transition widgets, deliberately.
    //
    // `buildTransitions` is called from the framework's own `AnimatedBuilder`,
    // so this method runs on *every frame* of the transition. A
    // `CurvedAnimation` constructed here would register a status listener on
    // the route's animation and never remove it — dozens of leaked listeners
    // per push, held for the life of the route. `drive` returns a plain
    // evaluation that listens to nothing, the tweens are static so no frame
    // allocates, and the transition widgets repaint the child instead of
    // rebuilding its subtree.
    return FadeTransition(
      opacity: animation.drive(_fade),
      child: ScaleTransition(
        scale: secondaryAnimation.drive(_exitScale),
        child: ScaleTransition(
          scale: animation.drive(_enterScale),
          child: SlideTransition(
            position: animation.drive(_rise),
            child: child,
          ),
        ),
      ),
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
