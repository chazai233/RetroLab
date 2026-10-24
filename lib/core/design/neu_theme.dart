/// ─────────────────────────────────────────────────────────────────────────────
/// Neumorphism — ThemeData
///
/// Maps the design.md tokens onto Material so stock widgets (AppBar, Switch,
/// Dialog, SnackBar…) inherit the soft-UI look without being rewritten.
/// design.md declares Light/Dark as "✓ Full / ◐ Partial" — dark is supported
/// but the effect is weaker, since soft shadows need luminance headroom.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'neu_tokens.dart';

class NeuTheme {
  NeuTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface =
        isDark ? NeuColors.surfaceDark : NeuColors.surfaceLight;
    final onSurface = isDark ? NeuColors.textOnDark : NeuColors.textOnLight;
    final muted =
        isDark ? NeuColors.textMutedOnDark : NeuColors.textMutedOnLight;

    return ThemeData(
      brightness: brightness,
      // The ground and every surface share one colour — that is what lets the
      // paired shadows read as extruded rather than as floating cards.
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      primaryColor: NeuColors.accent,

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: NeuColors.accent,
        onPrimary: Colors.white,
        secondary: NeuColors.secondary,
        onSecondary: NeuColors.textOnLight,
        surface: surface,
        onSurface: onSurface,
        error: NeuColors.error,
        onError: Colors.white,
      ),

      textTheme: _textTheme(onSurface, muted),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: NeuType.h2.copyWith(fontSize: 18, color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
      ),

      iconTheme: IconThemeData(color: muted, size: 24),

      // Material buttons keep the radius + weight contract. Tactile press and
      // the extruded look come from NeuButton in widgets/neu.dart.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NeuColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: NeuSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: NeuRadius.smAll),
          textStyle: NeuType.small.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NeuColors.accent,
          side: BorderSide(
            color: NeuColors.accent.withValues(alpha: 0.55),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: NeuRadius.smAll),
          textStyle: NeuType.small.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NeuColors.accent,
          textStyle: NeuType.small.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Label above the field, 1px stroke, 2px focus ring offset 2px.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NeuSpacing.md,
          vertical: NeuSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: NeuRadius.smAll,
          borderSide: BorderSide(color: muted.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: NeuRadius.smAll,
          borderSide: BorderSide(color: muted.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NeuRadius.smAll,
          borderSide: const BorderSide(color: NeuColors.accent, width: 2),
          gapPadding: 2,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: NeuRadius.smAll,
          borderSide: const BorderSide(color: NeuColors.error),
        ),
        labelStyle: NeuType.labelCaps.copyWith(color: muted),
        errorStyle: NeuType.labelCaps.copyWith(color: NeuColors.error),
        // "No floating labels" — keep the label pinned above the field.
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: NeuRadius.smAll),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: NeuRadius.mdAll),
        titleTextStyle: NeuType.h2.copyWith(fontSize: 20, color: onSurface),
        contentTextStyle: NeuType.bodyMd.copyWith(color: muted),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF3A3F46) : onSurface,
        contentTextStyle: NeuType.small.copyWith(color: surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: NeuRadius.smAll),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? NeuColors.accent : surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NeuColors.accent.withValues(alpha: 0.3)
              : muted.withValues(alpha: 0.2),
        ),
        trackOutlineColor:
            WidgetStateProperty.all(muted.withValues(alpha: 0.25)),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: NeuColors.accent,
        inactiveTrackColor: muted.withValues(alpha: 0.25),
        thumbColor: surface,
        overlayColor: NeuColors.accent.withValues(alpha: 0.12),
        trackHeight: 6,
      ),

      dividerTheme: DividerThemeData(
        color: muted.withValues(alpha: 0.18),
        thickness: 1,
        space: NeuSpacing.lg,
      ),

      // Page transitions: fade only, 200ms.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeTransitionBuilder(),
          TargetPlatform.iOS: _FadeTransitionBuilder(),
        },
      ),

      splashFactory: InkRipple.splashFactory,
      useMaterial3: true,
    );
  }

  static TextTheme _textTheme(Color onSurface, Color muted) {
    return TextTheme(
      displayLarge: NeuType.h1.copyWith(fontSize: 64, color: onSurface),
      headlineLarge: NeuType.h1.copyWith(color: onSurface),
      headlineMedium: NeuType.h2.copyWith(color: onSurface),
      titleLarge: NeuType.h2.copyWith(fontSize: 20, color: onSurface),
      titleMedium: NeuType.small.copyWith(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: NeuType.bodyMd.copyWith(color: onSurface),
      bodyMedium: NeuType.bodyMd.copyWith(color: muted),
      bodySmall: NeuType.small.copyWith(color: muted),
      labelLarge: NeuType.small.copyWith(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelMedium: NeuType.labelCaps.copyWith(color: muted),
      // Monospace slot for code, metadata and technical values.
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    );
  }
}

class _FadeTransitionBuilder extends PageTransitionsBuilder {
  const _FadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: NeuMotion.curve),
      child: child,
    );
  }
}
