import 'package:flutter/material.dart';

/// Soft blue surfaces, cobalt actions, and separate semantic status tones.
class RomlerkColors {
  const RomlerkColors._();

  static const Color paper = Color(0xFFF4F7FC);
  static const Color paperRaised = Color(0xFFFFFFFF);
  static const Color paperHigh = Color(0xFFFFFFFF);
  static const Color paperSunken = Color(0xFFE9EFF8);
  static const Color ink = Color(0xFF192B46);
  static const Color inkMuted = Color(0xFF5D708D);
  static const Color inkFaint = Color(0xFF8293AC);
  static const Color hairline = Color(0xFFDCE5F2);

  static const Color paperDark = Color(0xFF101A2B);
  static const Color paperRaisedDark = Color(0xFF192740);
  static const Color paperHighDark = Color(0xFF23344F);
  static const Color paperSunkenDark = Color(0xFF142137);
  static const Color inkDark = Color(0xFFE8F0FC);
  static const Color inkMutedDark = Color(0xFFA7BAD7);
  static const Color hairlineDark = Color(0xFF304565);

  static const Color blue = Color(0xFF285CC4);
  static const Color blueDark = Color(0xFF9CBEFF);
  static const Color alert = Color(0xFFB34538);
  static const Color alertDark = Color(0xFFFFAA9C);
  static const Color completed = Color(0xFF285CC4);
  static const Color completedDark = Color(0xFF9CBEFF);
  static const Color caution = Color(0xFF876018);
  static const Color cautionDark = Color(0xFFE5C17B);
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

  /// How far list content is inset from the screen edge. Grouped cards use
  /// this, so every surface lines up on the same left margin.
  static const double gutter = 20;

  /// Space reserved at the bottom of every scroll view so the last row is not
  /// hidden behind the capture bar and navigation.
  static const double bottomClearance = 32;
}

class Corners {
  const Corners._();

  static const Radius small = Radius.circular(12);
  static const Radius medium = Radius.circular(20);
  static const Radius large = Radius.circular(28);

  static const BorderRadius chip = BorderRadius.all(small);
  static const BorderRadius card = BorderRadius.all(medium);
  static const BorderRadius group = BorderRadius.all(large);
  static const BorderRadius sheet = BorderRadius.vertical(top: large);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// The rounding a row gets when it sits at the top or bottom of a grouped
  /// card. Applied to the row's own ink so a tap ripple cannot spill past the
  /// card's corner.
  static const BorderRadius groupTop = BorderRadius.vertical(top: large);
  static const BorderRadius groupBottom = BorderRadius.vertical(bottom: large);
}

/// Tinted, low-opacity shadows. Two levels only: content that rests on the
/// page, and content that floats above it.
class Shadows {
  const Shadows._();

  static List<BoxShadow> resting(bool isDark) => isDark
      ? const <BoxShadow>[
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ]
      : const <BoxShadow>[
          BoxShadow(
            color: Color(0x081A315A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x081A315A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ];

  static List<BoxShadow> floating(bool isDark) => isDark
      ? const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ]
      : const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A1A315A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x101A315A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ];
}

/// Consistent timing for direct feedback, content transitions, and sheets.
/// Use context.motion for implicit animations; scroll controllers need an
/// explicit jump under reduced motion because animateTo rejects zero duration.
class Motion {
  const Motion._();

  /// Press feedback. Below ~100ms a scale reads as a material response rather
  /// than as an animation, which is exactly what a button press should be.
  static const Duration micro = Duration(milliseconds: 80);

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);

  /// Completion marks and progress feedback.
  static const Duration expressive = Duration(milliseconds: 240);

  /// A whole surface being replaced — tab changes, pushed pages. Short, because
  /// the user has already decided where they are going and is waiting to read
  /// what is there.
  static const Duration page = Duration(milliseconds: 260);

  /// The capture sheet. The one place a little more travel time is earned: it
  /// covers most of the screen, and arriving at capture is a deliberate move.
  static const Duration sheet = Duration(milliseconds: 300);

  static const Curve easing = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;

  /// The default in/out curve: leaves immediately, arrives slowly. Used for
  /// anything that moves position.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// For things that only arrive (entrances, expansions). Flatter tail than
  /// [standard] so the last few pixels are not visible as a crawl.
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// For things that only leave. Movement accelerates away from the user.
  static const Curve accelerate = Cubic(0.3, 0, 1, 1);

  /// A small overshoot that reads as weight settling rather than as a bounce.
  /// Used for the completion pop and for press release.
  static const Curve settle = Cubic(0.34, 1.28, 0.64, 1);
}
