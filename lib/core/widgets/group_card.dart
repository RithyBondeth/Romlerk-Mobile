import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// A sheet of paper that a group of rows sits on.
///
/// Grouping is what turns a long undifferentiated list into a scannable page:
/// "overdue" becomes an object you can take in at a glance rather than a run of
/// rows you have to read. The card is a sliver so the list inside it stays
/// virtualised — a search across a few thousand tasks must not build every row.
class SliverGroupCard extends StatelessWidget {
  const SliverGroupCard({required this.sliver, this.accent, super.key});

  final Widget sliver;

  /// Tints the border. Used for overdue, where the group itself is the warning.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: semantics.raised,
          borderRadius: Corners.group,
          border: Border.all(
            color: accent == null
                ? semantics.hairline
                : accent!.withValues(alpha: 0.35),
          ),
          boxShadow: semantics.restingShadow,
        ),
        sliver: SliverMainAxisGroup(
          slivers: <Widget>[
            const SliverToBoxAdapter(child: SizedBox(height: Insets.xs)),
            sliver,
            const SliverToBoxAdapter(child: SizedBox(height: Insets.xs)),
          ],
        ),
      ),
    );
  }
}

/// The box-widget equivalent, for the places that are not building slivers —
/// settings panels, notices, the draft cards in capture.
class GroupCard extends StatelessWidget {
  const GroupCard({
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(Insets.lg),
    super.key,
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: semantics.raised,
        borderRadius: Corners.card,
        border: Border.all(
          color: accent == null
              ? semantics.hairline
              : accent!.withValues(alpha: 0.45),
        ),
        boxShadow: semantics.restingShadow,
      ),
      child: child,
    );
  }
}
