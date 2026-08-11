import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';
import 'illustration.dart';

/// Empty states say what the surface is for, not that something is missing.
///
/// Still no upsell: an empty Today is a good outcome, and the BRD asks for "no
/// shame" framing throughout. The illustrations are drawn to match that — a
/// figure resting, not a figure apologising — and they are tinted from the
/// theme's muted ink so they read as part of the page.
///
/// Failure states deliberately keep the plain icon instead. A drawing of a
/// person is the wrong register for "your database did not open".
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.headline,
    required this.body,
    this.illustration,
    this.action,
    this.tone,
    super.key,
  });

  final IconData icon;
  final String headline;
  final String body;

  /// File stem under `assets/illustrations/`. Replaces the icon halo when set.
  final String? illustration;

  final Widget? action;

  /// Overrides the icon colour. Failure states pass the alert tone; everything
  /// else stays deliberately neutral.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final accent = tone ?? semantics.muted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xxl,
          vertical: Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (illustration != null)
              Illustration(name: illustration!)
            else
              // Two concentric rings: a wide, barely-there halo over a defined
              // inner disc. Cheap to draw and it stops the icon floating.
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: semantics.sunken.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: semantics.raised,
                      shape: BoxShape.circle,
                      border: Border.all(color: semantics.hairline),
                      boxShadow: semantics.restingShadow,
                    ),
                    child: Icon(icon, size: 24, color: accent),
                  ),
                ),
              ),
            const SizedBox(height: Insets.lg),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: context.texts.titleLarge,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(color: semantics.muted),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: Insets.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
