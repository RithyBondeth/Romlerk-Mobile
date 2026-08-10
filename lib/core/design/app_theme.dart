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
    required this.muted,
  });

  final Color overdue;
  final Color completed;

  /// Ambiguities and assumptions the user should notice before saving.
  final Color caution;

  final Color hairline;
  final Color sunken;
  final Color muted;

  @override
  RomlerkSemantics copyWith({
    Color? overdue,
    Color? completed,
    Color? caution,
    Color? hairline,
    Color? sunken,
    Color? muted,
  }) {
    return RomlerkSemantics(
      overdue: overdue ?? this.overdue,
      completed: completed ?? this.completed,
      caution: caution ?? this.caution,
      hairline: hairline ?? this.hairline,
      sunken: sunken ?? this.sunken,
      muted: muted ?? this.muted,
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
      muted: Color.lerp(muted, other.muted, t)!,
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
      secondary: isDark ? RomlerkColors.mossDark : RomlerkColors.moss,
      onSecondary: isDark ? const Color(0xFF0F2413) : Colors.white,
      error: isDark ? RomlerkColors.alertDark : RomlerkColors.alert,
      onError: isDark ? const Color(0xFF3A0B06) : Colors.white,
      surface: isDark ? RomlerkColors.paperDark : RomlerkColors.paper,
      onSurface: isDark ? RomlerkColors.inkDark : RomlerkColors.ink,
      surfaceContainerLowest: isDark
          ? RomlerkColors.paperSunkenDark
          : RomlerkColors.paperSunken,
      surfaceContainer: isDark
          ? RomlerkColors.paperRaisedDark
          : RomlerkColors.paperRaised,
      surfaceContainerHighest: isDark
          ? RomlerkColors.paperRaisedDark
          : RomlerkColors.paperRaised,
      onSurfaceVariant: isDark
          ? RomlerkColors.inkMutedDark
          : RomlerkColors.inkMuted,
      outline: isDark ? RomlerkColors.hairlineDark : RomlerkColors.hairline,
      outlineVariant: isDark
          ? RomlerkColors.hairlineDark
          : RomlerkColors.hairline,
    );

    final semantics = RomlerkSemantics(
      overdue: isDark ? RomlerkColors.alertDark : RomlerkColors.alert,
      completed: isDark ? RomlerkColors.mossDark : RomlerkColors.moss,
      caution: isDark ? RomlerkColors.cautionDark : RomlerkColors.caution,
      hairline: isDark ? RomlerkColors.hairlineDark : RomlerkColors.hairline,
      sunken: isDark
          ? RomlerkColors.paperSunkenDark
          : RomlerkColors.paperSunken,
      muted: isDark ? RomlerkColors.inkMutedDark : RomlerkColors.inkMuted,
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
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.card,
          side: BorderSide(color: semantics.hairline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantics.sunken,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: semantics.hairline),
        labelStyle: text.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: Corners.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantics.sunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
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
          shape: const RoundedRectangleBorder(borderRadius: Corners.card),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, Insets.minTapTarget),
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, Insets.minTapTarget),
          side: BorderSide(color: semantics.hairline),
          shape: const RoundedRectangleBorder(borderRadius: Corners.card),
          textStyle: text.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Corners.sheet),
        showDragHandle: true,
        dragHandleColor: semantics.hairline,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? RomlerkColors.paperRaisedDark
            : RomlerkColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: isDark ? RomlerkColors.inkDark : RomlerkColors.paper,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Corners.card),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: semantics.muted,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: semantics.muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                )
              : text.labelSmall?.copyWith(color: semantics.muted),
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
      headlineMedium: base.headlineMedium?.copyWith(
        color: ink,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
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
