import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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
    return _HeaderContent(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      collapse: 0,
    );
  }
}

/// [PageHeader] in sliver form — and, because every surface is a
/// [CustomScrollView], the place where the header earns its keep.
///
/// It pins and collapses rather than scrolling away. Scrolling a long list is
/// the moment you are most likely to lose track of which of four near-identical
/// surfaces you are on, so the title stays; what goes is everything that was
/// only useful on arrival. The large display title shrinks toward a compact
/// one, the subtitle fades and lifts out, and the padding closes up, leaving a
/// slim bar with a hairline beneath it.
///
/// The collapse is driven by scroll offset rather than by a duration, so it is
/// under the user's finger the whole way — reversible, interruptible, and never
/// running on after they stop. That also means it needs no reduced-motion
/// branch: there is no self-directed movement to suppress.
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
    // Extents are derived from the text styles themselves — both size and line
    // height — so a user at 200% text scale gets a taller header instead of an
    // overflow, and so retuning the type scale cannot silently desync from the
    // header. Hard-coding the multipliers here once meant a font change left
    // this two pixels short and the header overflowed on every surface.
    final scaler = MediaQuery.textScalerOf(context);
    final texts = context.texts;
    final titleLine = _lineHeight(scaler, texts.headlineMedium);
    final subtitleLine = subtitle == null
        ? 0.0
        : _lineHeight(scaler, texts.bodyMedium) + Insets.xs + 2;

    // One pixel of slack absorbs the rounding between this estimate and the
    // Column's actual laid-out height.
    final expanded = Insets.md + titleLine + subtitleLine + Insets.sm + 1;
    // The floor keeps the trailing affordance (a 42pt button, a 46pt ring)
    // laid out at full size no matter how far the type shrinks — it is scaled
    // for balance, and [Transform.scale] does not give the space back.
    final collapsed = math.max(
      Insets.minTapTarget + Insets.lg,
      Insets.sm + titleLine * _HeaderContent.collapsedTitleScale + Insets.sm,
    );

    return SliverPersistentHeader(
      pinned: true,
      delegate: _PageHeaderDelegate(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        // Whole pixels: a sliver whose extents carry a fraction can compute a
        // paintExtent a hair under its layoutExtent and trip the framework's
        // geometry assertion.
        minExtent: math.min(collapsed, expanded).ceilToDouble(),
        maxExtent: math.max(collapsed, expanded).ceilToDouble(),
      ),
    );
  }

  /// The height one line of [style] will actually occupy.
  ///
  /// [TextStyle.height] is a multiple of the font size and, when set, defines
  /// the line box outright — which is what makes this exact rather than a
  /// guess. When it is not set the font's own ascent and descent decide, and
  /// those run generous on a serif, so 1.3 is the conservative fallback.
  static double _lineHeight(TextScaler scaler, TextStyle? style) {
    return scaler.scale(style?.fontSize ?? 16) * (style?.height ?? 1.3);
  }
}

class _PageHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PageHeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.minExtent,
    required this.maxExtent,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  final double minExtent;

  @override
  final double maxExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final collapse = range <= 0 ? 0.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final semantics = context.semantics;

    // The delegate is laid out with a *maximum* of the current extent, not an
    // exact one, so content shorter than the extent would report a paintExtent
    // below the layoutExtent the sliver already promised. Filling the box is
    // what keeps the two in agreement at every point in the collapse.
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Opaque only once it has something to hide, so an unscrolled page
          // still shows the paper texture running behind the title.
          color: context.colors.surface.withValues(alpha: collapse),
          border: Border(
            bottom: BorderSide(
              color: semantics.hairline.withValues(alpha: collapse),
            ),
          ),
        ),
        child: ClipRect(
          child: _HeaderContent(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            collapse: collapse,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_PageHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      subtitle != oldDelegate.subtitle ||
      trailing != oldDelegate.trailing ||
      minExtent != oldDelegate.minExtent ||
      maxExtent != oldDelegate.maxExtent;
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.collapse,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// 0 = fully expanded, 1 = collapsed to the pinned bar.
  final double collapse;

  /// How much of its original size the title keeps when collapsed. Scaled
  /// rather than restyled so it travels continuously instead of snapping to a
  /// second type ramp partway down.
  static const double collapsedTitleScale = 0.72;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    // The subtitle is gone well before the header finishes collapsing, so the
    // last stretch is the title settling alone rather than two things moving.
    final subtitleFade = (1 - collapse * 1.9).clamp(0.0, 1.0);

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.scale(
            scale: lerpDouble(1, collapsedTitleScale, collapse),
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: context.texts.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (subtitle != null)
          // Height is animated to zero alongside the fade so the title can
          // take the space back as it goes, instead of leaving a gap.
          Align(
            heightFactor: subtitleFade,
            alignment: Alignment.topLeft,
            child: Opacity(
              opacity: subtitleFade,
              child: Padding(
                padding: const EdgeInsets.only(top: Insets.xs + 2),
                child: Text(
                  subtitle!,
                  style: context.texts.bodyMedium?.copyWith(
                    color: semantics.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        lerpDouble(Insets.md, Insets.sm, collapse)!,
        Insets.sm,
        Insets.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: heading),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Insets.md),
            // Shrinks with the title so the bar stays optically balanced, but
            // never past the point where it is awkward to hit.
            Transform.scale(
              scale: lerpDouble(1, 0.88, collapse),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
