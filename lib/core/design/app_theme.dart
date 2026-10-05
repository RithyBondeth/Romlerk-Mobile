import 'package:flutter/material.dart';

import '../motion/page_transitions.dart';
import 'design_tokens.dart';

/// Semantic colours that Material's [ColorScheme] has no slot for.
///
/// Attached as a [ThemeExtension] so widgets read them from the theme rather
/// than importing the palette directly, which keeps light/dark switching in
/// one place.
@immutable
class RomlerkSemantics extends ThemeExtension<RomlerkSemantics> {
  const RomlerkSemantics({
    required this.overdue,
    required this.completed,
    required this.caution,
    required this.hairline,
    required this.sunken,
    required this.raised,
    required this.high,
    required this.muted,
    required this.accentSoft,
    required this.overdueSoft,
    required this.completedSoft,
    required this.cautionSoft,
    required this.restingShadow,
    required this.floatingShadow,
    required this.isDark,
  });

  final Color overdue;
  final Color completed;

  /// Ambiguities and assumptions the user should notice before saving.
  final Color caution;

  final Color hairline;

  /// Recessed fills: input backgrounds, quiet chips.
  final Color sunken;

  /// The surface grouped content sits on — one step above the page.
  final Color raised;

  /// One step above [raised], for content layered inside a card.
  final Color high;

  final Color muted;

  /// Very low-opacity washes used behind icons and status rows. Kept as solid
  /// colours rather than alpha blends so they composite predictably over both
  /// the page and a raised card.
  final Color accentSoft;
  final Color overdueSoft;
  final Color completedSoft;
  final Color cautionSoft;

  final List<BoxShadow> restingShadow;
  final List<BoxShadow> floatingShadow;

  final bool isDark;

  @override
  RomlerkSemantics copyWith({
    Color? overdue,
    Color? completed,
    Color? caution,
    Color? hairline,
    Color? sunken,
    Color? raised,
    Color? high,
    Color? muted,
    Color? accentSoft,
    Color? overdueSoft,
    Color? completedSoft,
    Color? cautionSoft,
    List<BoxShadow>? restingShadow,
    List<BoxShadow>? floatingShadow,
    bool? isDark,
  }) {
    return RomlerkSemantics(
      overdue: overdue ?? this.overdue,
      completed: completed ?? this.completed,
      caution: caution ?? this.caution,
      hairline: hairline ?? this.hairline,
      sunken: sunken ?? this.sunken,
      raised: raised ?? this.raised,
      high: high ?? this.high,
      muted: muted ?? this.muted,
      accentSoft: accentSoft ?? this.accentSoft,
      overdueSoft: overdueSoft ?? this.overdueSoft,
      completedSoft: completedSoft ?? this.completedSoft,
      cautionSoft: cautionSoft ?? this.cautionSoft,
      restingShadow: restingShadow ?? this.restingShadow,
      floatingShadow: floatingShadow ?? this.floatingShadow,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  RomlerkSemantics lerp(ThemeExtension<RomlerkSemantics>? other, double t) {
    if (other is! RomlerkSemantics) return this;
    return RomlerkSemantics(
      overdue: Color.lerp(overdue, other.overdue, t)!,
      completed: Color.lerp(completed, other.completed, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      high: Color.lerp(high, other.high, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      overdueSoft: Color.lerp(overdueSoft, other.overdueSoft, t)!,
      completedSoft: Color.lerp(completedSoft, other.completedSoft, t)!,
      cautionSoft: Color.lerp(cautionSoft, other.cautionSoft, t)!,
      restingShadow: BoxShadow.lerpList(restingShadow, other.restingShadow, t)!,
      floatingShadow: BoxShadow.lerpList(
        floatingShadow,
        other.floatingShadow,
        t,
      )!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension RomlerkThemeAccess on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;

  RomlerkSemantics get semantics =>
      Theme.of(this).extension<RomlerkSemantics>()!;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? RomlerkColors.blueDark : RomlerkColors.blue,
      onPrimary: isDark ? const Color(0xFF102B57) : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF233F6D)
          : const Color(0xFFDFEAFE),
      onPrimaryContainer: isDark
          ? RomlerkColors.blueDark
          : const Color(0xFF204A98),
      secondary: isDark ? RomlerkColors.completedDark : RomlerkColors.completed,
      onSecondary: isDark ? const Color(0xFF112C55) : Colors.white,
      error: isDark ? RomlerkColors.alertDark : RomlerkColors.alert,
      onError: isDark ? const Color(0xFF3A0B06) : Colors.white,
      surface: isDark ? RomlerkColors.paperDark : RomlerkColors.paper,
      onSurface: isDark ? RomlerkColors.inkDark : RomlerkColors.ink,
      surfaceContainerLowest: isDark
          ? RomlerkColors.paperSunkenDark
          : RomlerkColors.paperSunken,
      surfaceContainerLow: isDark
          ? RomlerkColors.paperSunkenDark
          : RomlerkColors.paperSunken,
      surfaceContainer: isDark
          ? RomlerkColors.paperRaisedDark
          : RomlerkColors.paperRaised,
      surfaceContainerHigh: isDark
          ? RomlerkColors.paperHighDark
          : RomlerkColors.paperHigh,
      surfaceContainerHighest: isDark
          ? RomlerkColors.paperHighDark
          : RomlerkColors.paperHigh,
      onSurfaceVariant: isDark
          ? RomlerkColors.inkMutedDark
          : RomlerkColors.inkMuted,
      outline: isDark ? RomlerkColors.hairlineDark : RomlerkColors.hairline,
      outlineVariant: isDark
          ? RomlerkColors.hairlineDark
          : RomlerkColors.hairline,
      shadow: isDark ? Colors.black : const Color(0xFF1A315A),
    );

    final semantics = RomlerkSemantics(
      overdue: isDark ? RomlerkColors.alertDark : RomlerkColors.alert,
      completed: isDark ? RomlerkColors.completedDark : RomlerkColors.completed,
      caution: isDark ? RomlerkColors.cautionDark : RomlerkColors.caution,
      hairline: isDark ? RomlerkColors.hairlineDark : RomlerkColors.hairline,
      sunken: isDark
          ? RomlerkColors.paperSunkenDark
          : RomlerkColors.paperSunken,
      raised: isDark
          ? RomlerkColors.paperRaisedDark
          : RomlerkColors.paperRaised,
      high: isDark ? RomlerkColors.paperHighDark : RomlerkColors.paperHigh,
      muted: isDark ? RomlerkColors.inkMutedDark : RomlerkColors.inkMuted,
      accentSoft: isDark ? const Color(0xFF233B63) : const Color(0xFFE3EDFF),
      overdueSoft: isDark ? const Color(0xFF422B27) : const Color(0xFFFBE9E5),
      completedSoft: isDark ? const Color(0xFF233B63) : const Color(0xFFE3EDFF),
      cautionSoft: isDark ? const Color(0xFF3B3221) : const Color(0xFFF5ECD9),
      restingShadow: Shadows.resting(isDark),
      floatingShadow: Shadows.floating(isDark),
      isDark: isDark,
    );

    // Ubuntu handles Latin text; its missing Khmer glyphs resolve to the
    // bundled Koh Santepheap family, including mixed-language task titles.
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Ubuntu',
      fontFamilyFallback: const ['Koh Santepheap'],
    );
    final text = _typography(base.textTheme, scheme.onSurface, semantics.muted);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[semantics],
      // InkRipple, not InkSparkle. Sparkle is drawn by a fragment shader, and
      // the first time one is needed the engine has to compile it — which
      // lands as a dropped-frame hitch on the user's first tap, and again
      // after any hot restart. Ripple is drawn with ordinary canvas calls and
      // has no such cliff. The visual difference on a paper-coloured surface
      // at this opacity is not worth a stutter on first touch.
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: romlerkPageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: semantics.hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: semantics.raised,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.card,
          side: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantics.sunken,
        selectedColor: semantics.accentSoft,
        side: BorderSide(color: semantics.hairline),
        labelStyle: text.labelMedium,
        surfaceTintColor: Colors.transparent,
        showCheckmark: false,
        shape: const RoundedRectangleBorder(borderRadius: Corners.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs + 2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantics.raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: Corners.card,
          borderSide: BorderSide(color: semantics.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.card,
          borderSide: BorderSide(color: semantics.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.card,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        hintStyle: text.bodyMedium?.copyWith(color: semantics.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, Insets.minTapTarget + 4),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          shape: const RoundedRectangleBorder(borderRadius: Corners.card),
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, Insets.minTapTarget + 4),
          foregroundColor: scheme.onSurface,
          shape: const RoundedRectangleBorder(borderRadius: Corners.card),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, Insets.minTapTarget + 4),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          side: BorderSide(color: semantics.hairline),
          shape: const RoundedRectangleBorder(borderRadius: Corners.card),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: semantics.muted,
          highlightColor: semantics.accentSoft,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Corners.sheet),
        showDragHandle: true,
        dragHandleColor: semantics.hairline,
        elevation: 0,
        modalBarrierColor: isDark
            ? Colors.black.withValues(alpha: 0.62)
            : const Color(0xFF1A315A).withValues(alpha: 0.32),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: semantics.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Corners.group),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? RomlerkColors.paperHighDark
            : RomlerkColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: isDark ? RomlerkColors.inkDark : RomlerkColors.paper,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Corners.card),
        insetPadding: const EdgeInsets.all(Insets.lg),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: semantics.muted,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: semantics.muted),
        shape: const RoundedRectangleBorder(borderRadius: Corners.card),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Corners.card),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? semantics.accentSoft
                : semantics.raised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : semantics.muted,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: semantics.hairline)),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : semantics.hairline,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: semantics.accentSoft,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: Corners.pill,
        ),
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 20,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : semantics.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                )
              : text.labelSmall?.copyWith(color: semantics.muted),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: semantics.sunken,
        circularTrackColor: semantics.sunken,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: semantics.high,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.card,
          side: BorderSide(color: semantics.hairline),
        ),
        textStyle: text.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? RomlerkColors.paperHighDark : RomlerkColors.ink,
          borderRadius: Corners.chip,
        ),
        textStyle: text.labelSmall?.copyWith(
          color: isDark ? RomlerkColors.inkDark : RomlerkColors.paper,
        ),
      ),
    );
  }

  /// Open line boxes also accommodate Khmer marks without clipping.
  static TextTheme _typography(TextTheme base, Color ink, Color muted) {
    TextStyle style(double size, FontWeight weight, {bool secondary = false}) =>
        TextStyle(
          fontFamily: 'Ubuntu',
          fontFamilyFallback: const ['Koh Santepheap'],
          fontSize: size,
          fontWeight: weight,
          color: secondary ? muted : ink,
          height: 1.5,
          letterSpacing: 0,
        );
    return base.copyWith(
      displaySmall: style(40, FontWeight.w700),
      headlineLarge: style(34, FontWeight.w700),
      headlineMedium: style(30, FontWeight.w700),
      headlineSmall: style(24, FontWeight.w500),
      titleLarge: style(20, FontWeight.w500),
      titleMedium: style(16, FontWeight.w500),
      titleSmall: style(14, FontWeight.w500),
      bodyLarge: style(16, FontWeight.w400),
      bodyMedium: style(14, FontWeight.w400),
      bodySmall: style(12, FontWeight.w400, secondary: true),
      labelLarge: style(14, FontWeight.w500),
      labelMedium: style(12, FontWeight.w500),
      labelSmall: style(11, FontWeight.w500),
    );
  }
}
