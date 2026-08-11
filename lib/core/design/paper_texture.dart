import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Candidate page treatments for the "paper" half of paper-and-ink.
///
/// All of it is painted, not bundled: an app whose promise is that it needs
/// nothing from the network should not ship a texture JPEG either. The rules
/// and the speckle are drawn from a fixed seed, so the grain is identical on
/// every frame and every device rather than shimmering as you scroll.
enum PaperTexture {
  /// Today's look — flat colour.
  none,

  /// Faint notebook rules across the page, with the cards floating over them.
  ruled,

  /// Fine paper speckle, no rules.
  grain,

  /// Both.
  both,
}

/// Paints [texture] behind [child].
class PaperBackground extends StatelessWidget {
  const PaperBackground({
    required this.texture,
    required this.child,
    super.key,
  });

  final PaperTexture texture;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (texture == PaperTexture.none) return child;
    final semantics = context.semantics;

    return CustomPaint(
      painter: _PaperPainter(
        texture: texture,
        rule: semantics.hairline,
        // Dark paper gets light fibres; light paper gets the warm shadow
        // colour, so the grain never reads as grey dirt on a cream page.
        speck: semantics.isDark ? Colors.white : const Color(0xFF3A2E1F),
        speckAlpha: semantics.isDark ? 0.035 : 0.05,
      ),
      child: child,
    );
  }
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter({
    required this.texture,
    required this.rule,
    required this.speck,
    required this.speckAlpha,
  });

  final PaperTexture texture;
  final Color rule;
  final Color speck;
  final double speckAlpha;

  /// Matches the app's 4pt rhythm so the rules never sit a hair off the
  /// baselines of the text laid over them.
  static const double _ruleSpacing = 32;

  static Size? _cachedSize;
  static Float32List? _cachedSpecks;

  @override
  void paint(Canvas canvas, Size size) {
    if (texture == PaperTexture.ruled || texture == PaperTexture.both) {
      final paint = Paint()
        ..color = rule.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (var y = _ruleSpacing; y < size.height; y += _ruleSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    if (texture == PaperTexture.grain || texture == PaperTexture.both) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        _specks(size),
        Paint()
          ..color = speck.withValues(alpha: speckAlpha)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Fixed seed, cached per size: the same fibres every frame.
  Float32List _specks(Size size) {
    if (_cachedSize == size && _cachedSpecks != null) return _cachedSpecks!;

    final random = math.Random(7);
    final count = (size.width * size.height / 140).round();
    final points = Float32List(count * 2);
    for (var i = 0; i < count; i++) {
      points[i * 2] = random.nextDouble() * size.width;
      points[i * 2 + 1] = random.nextDouble() * size.height;
    }

    _cachedSize = size;
    _cachedSpecks = points;
    return points;
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) =>
      oldDelegate.texture != texture ||
      oldDelegate.rule != rule ||
      oldDelegate.speck != speck ||
      oldDelegate.speckAlpha != speckAlpha;
}
