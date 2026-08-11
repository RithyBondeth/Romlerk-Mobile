import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// The label above a group of rows.
///
/// Deliberately quieter than the task titles below it: the section label is
/// orientation, not content. The count sits in a pill on the far side so the
/// eye can count the day's load without reading a single row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.label,
    this.trailing,
    this.emphasized = false,
    super.key,
  });

  final String label;

  /// Usually a count.
  final String? trailing;

  /// Used for "Overdue", which should catch the eye.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final color = emphasized ? semantics.overdue : semantics.muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter + Insets.xs,
        Insets.xl,
        Insets.gutter + Insets.xs,
        Insets.sm + Insets.xs,
      ),
      child: Row(
        children: <Widget>[
          if (emphasized) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: semantics.overdue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Insets.sm),
          ],
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: context.texts.labelSmall?.copyWith(
                color: color,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Insets.sm),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm - 1,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: emphasized ? semantics.overdueSoft : semantics.sunken,
                borderRadius: Corners.pill,
              ),
              child: Text(
                trailing!,
                textAlign: TextAlign.center,
                style: context.texts.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
