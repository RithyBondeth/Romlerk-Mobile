import 'package:flutter/material.dart';

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
      restingShadow:
          BoxShadow.lerpList(restingShadow, other.restingShadow, t)!,
      floatingShadow:
          BoxShadow.lerpList(floatingShadow, other.floatingShadow, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension RomlerkThemeAccess on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;

  RomlerkSemantics get semantics => Theme.of(this).extension<RomlerkSemantics>()!;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? RomlerkColors.emberDark : RomlerkColors.ember,
      onPrimary: isDark ? const Color(0xFF2A1509) : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF3A2113)
          : const Color(0xFFF7E4D9),
      onPrimaryContainer: isDark
          ? RomlerkColors.emberDark
          : const Color(0xFF6E2C11),
      secondary: isDark ? RomlerkColors.mossDark : RomlerkColors.moss,
      onSecondary: isDark ? const Color(0xFF0F2413) : Colors.white,
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
      shadow: isDark ? Colors.black : const Color(0xFF3A2E1F),
    );

    final semantics = RomlerkSemantics(
      overdue: isDark ? RomlerkColors.alertDark : RomlerkColors.alert,
      completed: isDark ? RomlerkColors.mossDark : RomlerkColors.moss,
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
      accentSoft: isDark ? const Color(0xFF2C1B10) : const Color(0xFFF7E7DC),
      overdueSoft: isDark ? const Color(0xFF2E1512) : const Color(0xFFF9E3E0),
      completedSoft: isDark ? const Color(0xFF16251A) : const Color(0xFFE4EFE5),
      cautionSoft: isDark ? const Color(0xFF2A2110) : const Color(0xFFF7EDD8),
      restingShadow: Shadows.resting(isDark),
      floatingShadow: Shadows.floating(isDark),
      isDark: isDark,
    );

    // The platform's own font is used deliberately: a downloaded webfont would
    // put a network request in an app whose entire promise is that it does not
    // need one.
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = _typography(base.textTheme, scheme.onSurface, semantics.muted);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[semantics],
      splashFactory: InkSparkle.splashFactory,
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
          side: BorderSide(color: semantics.hairline),
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
        fillColor: semantics.sunken,
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
          minimumSize: const Size(0, Insets.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          shape: const RoundedRectangleBorder(borderRadius: Corners.pill),
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, Insets.minTapTarget),
          foregroundColor: scheme.onSurface,
          shape: const RoundedRectangleBorder(borderRadius: Corners.pill),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, Insets.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          side: BorderSide(color: semantics.hairline),
          shape: const RoundedRectangleBorder(borderRadius: Corners.pill),
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
            : const Color(0xFF3A2E1F).withValues(alpha: 0.32),
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
        height: 62,
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

  /// Tight, slightly condensed headings over a comfortable reading size for
  /// task text. Sizes stay in logical pixels so system text scaling applies.
  static TextTheme _typography(TextTheme base, Color ink, Color muted) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        color: ink,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: ink,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.1,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: ink,
        fontSize: 27,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        height: 1.15,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: ink,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: ink,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: ink,
        fontSize: 16,
        height: 1.35,
        letterSpacing: -0.1,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: ink,
        fontSize: 14.5,
        height: 1.4,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: muted,
        fontSize: 13,
        height: 1.35,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    );
  }
}
