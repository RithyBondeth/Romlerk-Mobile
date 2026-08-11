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
        // Holds the drawing's space during the one genuine decode, so the
        // headline below it does not jump up and then back down.
        placeholderBuilder: (_) => SizedBox(height: height),
      ),
    );
  }
}

/// Remaps the two authored colours to the theme's.
///
/// The value equality below is load-bearing, not boilerplate.
///
/// `SvgAssetLoader`'s own `==` — and the picture cache's key — both include the
/// `colorMapper`. Without `==` here, every rebuild of [Illustration] produced a
/// mapper that compared unequal to the last one, so `SvgPicture` concluded it
/// had been handed a different image: cache miss, full asynchronous re-parse,
/// and the drawing rendering as nothing until it finished. On screen that is
/// the illustration vanishing and snapping back on every rebuild, and it leaked
/// a cache entry each time as well.
///
/// With equality, a rebuild resolves to the same cache entry and the picture is
/// simply reused.
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

  @override
  bool operator ==(Object other) =>
      other is _DoodlePalette && other.ink == ink && other.accent == accent;

  @override
  int get hashCode => Object.hash(ink, accent);
}
