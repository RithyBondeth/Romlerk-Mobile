import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/app_theme.dart';

/// The app's line illustrations — Open Doodles (CC0), bundled unmodified.
///
/// The assets ship with the app rather than being fetched. An app whose promise
/// is that it needs nothing from the network should not make an exception for
/// decoration.
///
/// Each doodle is drawn with exactly two colours, which is what makes them
/// usable here at all: the line art is remapped to the theme's ink and the
/// accent to ember, so one file serves light and dark and the drawings stay
/// inside the app's one-signal-colour rule instead of importing a second
/// palette. See `assets/illustrations/README.md`.
class Illustration extends StatelessWidget {
  const Illustration({
    required this.name,
    this.height = 168,
    this.tint,
    super.key,
  });

  /// File stem under `assets/illustrations/`.
  final String name;

  final double height;

  /// Overrides the line-art colour. Onboarding uses a stronger ink, because
  /// there the drawing is the content rather than an aside next to it.
  final Color? tint;

  /// The colours as authored by Open Doodles.
  static const Color _sourceInk = Color(0xFF000000);
  static const Color _sourceAccent = Color(0xFFFF5678);

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    // Decorative: the headline and body beneath already say everything a
    // screen reader needs, so announcing the drawing would only add noise.
    return ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/illustrations/$name.svg',
        height: height,
        fit: BoxFit.contain,
        colorMapper: _DoodlePalette(
          // Not full-strength ink by default: next to a headline, a pure black
          // figure would out-weigh the words it is supposed to introduce.
          ink: tint ?? semantics.muted,
          accent: context.colors.primary,
        ),
      ),
    );
  }
}

@immutable
class _DoodlePalette extends ColorMapper {
  const _DoodlePalette({required this.ink, required this.accent});

  final Color ink;
  final Color accent;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == Illustration._sourceInk) return ink;
    if (color == Illustration._sourceAccent) return accent;
    return color;
  }
}
