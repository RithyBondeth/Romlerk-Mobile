import 'package:flutter/material.dart';

/// Romlerk's visual language: paper and ink.
///
/// The product promise is that your commitments stay on your device, so the
/// interface is deliberately closer to a notebook than to a cloud dashboard —
/// warm neutrals, one signal colour, generous whitespace, and no decorative
/// gradients competing with task text.
class RomlerkColors {
  const RomlerkColors._();

  // Light — warm paper.
  static const Color paper = Color(0xFFFBF8F3);
  static const Color paperRaised = Color(0xFFFFFFFF);
  static const Color paperSunken = Color(0xFFF2EDE4);
  static const Color ink = Color(0xFF1C1A17);
  static const Color inkMuted = Color(0xFF6B655C);
  static const Color inkFaint = Color(0xFF9A9287);
  static const Color hairline = Color(0xFFE4DDD1);

  // Dark — warm charcoal, never pure black (OLED smear on scroll).
  static const Color paperDark = Color(0xFF16150F);
  static const Color paperRaisedDark = Color(0xFF1F1D17);
  static const Color paperSunkenDark = Color(0xFF100F0B);
  static const Color inkDark = Color(0xFFF0EAE0);
  static const Color inkMutedDark = Color(0xFFA39C90);
  static const Color hairlineDark = Color(0xFF322F27);

  /// The single signal colour. Used for the capture affordance, the current
  /// day, and nothing else, so its meaning stays legible.
  static const Color ember = Color(0xFFC2542A);
  static const Color emberDark = Color(0xFFE8874F);

  /// Reserved for states that need attention: overdue, blocked reminders.
  static const Color alert = Color(0xFFB3261E);
  static const Color alertDark = Color(0xFFF2896F);

  /// Confirmation and completion.
  static const Color moss = Color(0xFF3F6C46);
  static const Color mossDark = Color(0xFF86BE8E);

  /// Ambiguity and assumption cues — visible without shouting.
  static const Color caution = Color(0xFF8A6100);
  static const Color cautionDark = Color(0xFFE0B457);
}

/// One spacing scale, used everywhere. Values are multiples of 4 so vertical
/// rhythm survives dynamic type.
class Insets {
  const Insets._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Minimum tap target, per accessibility guidance (NFR-10).
  static const double minTapTarget = 48;
}

class Corners {
  const Corners._();

  static const Radius small = Radius.circular(8);
  static const Radius medium = Radius.circular(14);
  static const Radius large = Radius.circular(22);

  static const BorderRadius card = BorderRadius.all(medium);
  static const BorderRadius sheet = BorderRadius.vertical(top: large);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Motion is short and non-bouncy: capture should feel immediate, and the BRD
/// asks for the UI to stay responsive during work rather than animate over it.
class Motion {
  const Motion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Curve easing = Curves.easeOutCubic;
}
