import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// Empty states say what the surface is for, not that something is missing.
///
/// No illustration and no upsell: an empty Today is a good outcome, and the
/// BRD asks for "no shame" framing throughout.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.headline,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String headline;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xxl,
          vertical: Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: semantics.sunken,
                shape: BoxShape.circle,
                border: Border.all(color: semantics.hairline),
              ),
              child: Icon(icon, size: 24, color: semantics.muted),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: context.texts.titleMedium,
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
