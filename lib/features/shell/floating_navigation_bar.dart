import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/motion/motion_prefs.dart';
import '../../core/motion/pressable.dart';

@immutable
class FloatingNavigationDestination {
  const FloatingNavigationDestination({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

/// A floating dock whose active destination expands into an icon-and-label row.
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  }) : assert(destinations.length >= 2),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingNavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final labelStyle = context.texts.labelMedium!.copyWith(
      color: context.colors.onPrimaryContainer,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.localeOf(context);

    return DecoratedBox(
      key: const ValueKey('floating-navigation-surface'),
      decoration: BoxDecoration(
        borderRadius: Corners.pill,
        boxShadow: semantics.floatingShadow,
      ),
      child: Material(
        color: semantics.raised,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.pill,
          side: BorderSide(color: semantics.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(Insets.xs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final label = TextPainter(
                text: TextSpan(
                  text: destinations[selectedIndex].label,
                  style: labelStyle,
                ),
                textDirection: direction,
                textScaler: scaler,
                locale: locale,
                maxLines: 3,
              )..layout();
              // All inactive destinations keep a 48px touch target. The active
              // label gets the remaining room, and wraps at large text sizes.
              const rowChrome = 20.0 + Insets.sm + Insets.lg;
              final selectedWidth = math.min(
                math.max(
                  Insets.minTapTarget * 2 + Insets.sm,
                  label.width + rowChrome,
                ),
                constraints.maxWidth -
                    Insets.minTapTarget * (destinations.length - 1),
              );
              label.layout(maxWidth: math.max(1, selectedWidth - rowChrome));
              final height = math.max(
                Insets.minTapTarget,
                label.height + Insets.lg,
              );
              label.dispose();
              final idleWidth =
                  (constraints.maxWidth - selectedWidth) /
                  (destinations.length - 1);
              final duration = context.motion(Motion.page);
              final curve = context.motionCurve(Motion.standard);

              return AnimatedContainer(
                duration: duration,
                curve: curve,
                height: height,
                child: Stack(
                  children: [
                    AnimatedPositionedDirectional(
                      duration: duration,
                      curve: curve,
                      start: selectedIndex * idleWidth,
                      top: 0,
                      bottom: 0,
                      width: selectedWidth,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: const ValueKey('floating-navigation-indicator'),
                          decoration: BoxDecoration(
                            color: semantics.accentSoft,
                            borderRadius: Corners.pill,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          AnimatedContainer(
                            duration: duration,
                            curve: curve,
                            width: i == selectedIndex
                                ? selectedWidth
                                : idleWidth,
                            child: FloatingNavigationItem(
                              key: ValueKey('floating-navigation-item-$i'),
                              destination: destinations[i],
                              selected: i == selectedIndex,
                              labelStyle: labelStyle,
                              index: i,
                              count: destinations.length,
                              onTap: () => onDestinationSelected(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Full labels remain available to screen readers and long-press tooltips.
class FloatingNavigationItem extends StatelessWidget {
  const FloatingNavigationItem({
    required this.destination,
    required this.selected,
    required this.labelStyle,
    required this.index,
    required this.count,
    required this.onTap,
    super.key,
  });

  final FloatingNavigationDestination destination;
  final bool selected;
  final TextStyle labelStyle;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    selected: selected,
    inMutuallyExclusiveGroup: true,
    label: destination.label,
    value: MaterialLocalizations.of(
      context,
    ).tabLabel(tabIndex: index + 1, tabCount: count),
    child: Tooltip(
      message: destination.label,
      excludeFromSemantics: true,
      child: Pressable(
        scale: 0.92,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          focusColor: context.colors.primary.withValues(alpha: 0.12),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NavigationIcon(icon: destination.icon, selected: selected),
                  if (selected) ...[
                    const SizedBox(width: Insets.sm),
                    Flexible(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: context.motion(Motion.page),
                        curve: context.motionCurve(Motion.decelerate),
                        builder: (context, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                        child: Text(
                          destination.label,
                          style: labelStyle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: selected ? const Offset(0, -0.04) : Offset.zero,
    duration: context.motion(Motion.fast),
    curve: context.motionCurve(Motion.settle),
    child: AnimatedScale(
      scale: selected ? 1.08 : 1,
      duration: context.motion(Motion.expressive),
      curve: context.motionCurve(Motion.settle),
      child: Icon(
        icon,
        size: 20,
        color: selected ? context.colors.primary : context.semantics.muted,
      ),
    ),
  );
}
