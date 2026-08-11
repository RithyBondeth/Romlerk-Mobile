import 'package:flutter/material.dart';

/// Romlerk's visual language: paper and ink.
///
/// The product promise is that your commitments stay on your device, so the
/// interface is deliberately closer to a notebook than to a cloud dashboard —
/// warm neutrals, one signal colour, generous whitespace, and no decorative
/// gradients competing with task text.
///
/// Depth is expressed with warm, low-contrast shadows rather than tinted
/// overlays: the page should read as sheets of paper stacked on a desk, which
/// keeps groups legible without introducing a second accent colour.
class RomlerkColors {
  const RomlerkColors._();

  // Light — warm paper. Four steps so grouped content can sit *on* the page
  // rather than merging into it.
  static const Color paper = Color(0xFFFAF7F1);
  static const Color paperRaised = Color(0xFFFFFDFA);
  static const Color paperHigh = Color(0xFFFFFFFF);
  static const Color paperSunken = Color(0xFFF1EBE0);
  static const Color ink = Color(0xFF1B1915);
  static const Color inkMuted = Color(0xFF6B6459);
  static const Color inkFaint = Color(0xFF9A9287);
  static const Color hairline = Color(0xFFE6DFD2);

  // Dark — warm charcoal, never pure black (OLED smear on scroll). The steps
  // widen slightly compared with light, because shadows do almost no work on a
  // dark background and layering has to come from value alone.
  static const Color paperDark = Color(0xFF141310);
  static const Color paperRaisedDark = Color(0xFF1F1D18);
  static const Color paperHighDark = Color(0xFF272420);
  static const Color paperSunkenDark = Color(0xFF0E0D0B);
  static const Color inkDark = Color(0xFFF2ECE2);
  static const Color inkMutedDark = Color(0xFFA8A093);
  static const Color hairlineDark = Color(0xFF35312A);

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

  /// How far list content is inset from the screen edge. Grouped cards use
  /// this, so every surface lines up on the same left margin.
  static const double gutter = 16;

  /// Space reserved at the bottom of every scroll view so the last row is not
  /// hidden behind the capture bar and navigation.
  static const double bottomClearance = 132;
}

class Corners {
  const Corners._();

  static const Radius small = Radius.circular(10);
  static const Radius medium = Radius.circular(16);
  static const Radius large = Radius.circular(24);

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

/// Warm, wide, low-opacity shadows. Two levels only: content that rests on the
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
            color: Color(0x0D3A2E1F),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x123A2E1F),
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
            color: Color(0x143A2E1F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x1F3A2E1F),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ];
}

/// Motion is short and non-bouncy: capture should feel immediate, and the BRD
/// asks for the UI to stay responsive during work rather than animate over it.
class Motion {
  const Motion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);

  /// Reserved for the one moment worth celebrating: a task being completed.
  static const Duration expressive = Duration(milliseconds: 380);

  static const Curve easing = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}
