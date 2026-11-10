import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import 'illustration.dart';

/// Keeps artwork beside content when space permits, and above it at large
/// text sizes. The words remain the source of meaning for screen readers.
class IllustratedContent extends StatelessWidget {
  const IllustratedContent({
    required this.illustration,
    required this.child,
    this.artSize = 96,
    super.key,
  });

  final String illustration;
  final Widget child;
  final double artSize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final artwork = SizedBox(
        width: artSize,
        child: Illustration(name: illustration, height: artSize),
      );
      if (constraints.maxWidth < 340 &&
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(alignment: Alignment.centerRight, child: artwork),
            const SizedBox(height: Insets.sm),
            child,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: child),
          const SizedBox(width: Insets.md),
          artwork,
        ],
      );
    },
  );
}

/// A small illustrated introduction on populated list screens.
class IllustratedBanner extends StatelessWidget {
  const IllustratedBanner({
    required this.illustration,
    required this.title,
    super.key,
  });

  final String illustration;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Insets.gutter,
      Insets.xs,
      Insets.gutter,
      Insets.md,
    ),
    child: Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: context.semantics.accentSoft,
        borderRadius: Corners.group,
      ),
      child: IllustratedContent(
        illustration: illustration,
        artSize: 88,
        child: Text(
          title,
          style: context.texts.titleMedium?.copyWith(
            color: context.colors.onPrimaryContainer,
          ),
        ),
      ),
    ),
  );
}
