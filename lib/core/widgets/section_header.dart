import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// Small-caps rule that separates groups within a list.
///
/// Deliberately quieter than the task titles below it: the section label is
/// orientation, not content.
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
        Insets.lg,
        Insets.xl,
        Insets.lg,
        Insets.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(
              color: color,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(child: Divider(color: semantics.hairline)),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Insets.md),
            Text(
              trailing!,
              style: context.texts.labelSmall?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}
