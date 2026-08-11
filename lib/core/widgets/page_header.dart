import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// The masthead every surface opens with.
///
/// One shape for all four tabs — large title, quiet subtitle, optional trailing
/// affordance — so switching tabs feels like turning a page rather than opening
/// a different app.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Sits opposite the title: a progress meter, a settings button, a count.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.sm,
        // Small, because what follows is usually a section label that brings
        // its own generous top margin. Surfaces that open straight onto a card
        // add their own gap.
        Insets.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: context.texts.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: Insets.xs + 2),
                  Text(
                    subtitle!,
                    style: context.texts.bodyMedium?.copyWith(
                      color: semantics.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Insets.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// [PageHeader] in sliver form, since every surface is a [CustomScrollView].
class SliverPageHeader extends StatelessWidget {
  const SliverPageHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: PageHeader(title: title, subtitle: subtitle, trailing: trailing),
    );
  }
}
