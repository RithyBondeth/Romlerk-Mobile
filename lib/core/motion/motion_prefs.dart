import 'package:flutter/material.dart';

/// Accessibility gate for every animation in the app.
///
/// iOS "Reduce Motion" and Android "Remove animations" both surface as
/// [MediaQueryData.disableAnimations]. Rather than branch on it at each call
/// site, every duration is passed through [BuildContext.motion], which collapses
/// it to zero. Implicit animations, [AnimationController]s, and transitions all
/// treat a zero duration as "jump to the end state", so the interface stays
/// identical — it simply arrives without travelling.
///
/// This matters more here than in most apps: vestibular triggers aside, the
/// product is a place people go to offload something they are worried about
/// forgetting, and motion they did not ask for is friction at exactly the wrong
/// moment.
extension MotionPreferences on BuildContext {
  /// Whether the user has asked the platform to suppress animation.
  bool get prefersReducedMotion =>
      MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// [duration], or zero when the user has asked for reduced motion.
  Duration motion(Duration duration) =>
      prefersReducedMotion ? Duration.zero : duration;

  /// A curve that is linear under reduced motion, since a zero-length
  /// animation with an overshoot curve can still emit one out-of-range frame.
  Curve motionCurve(Curve curve) =>
      prefersReducedMotion ? Curves.linear : curve;
}
