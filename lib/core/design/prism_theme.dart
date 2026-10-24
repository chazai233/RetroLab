/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Prism design system
///
/// One palette for the whole app, resolved per brightness. Screens read it via
/// `context.prism` instead of hardcoding colours, which is what makes the
/// light theme actually work rather than just being declared.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';

@immutable
class PrismPalette extends ThemeExtension<PrismPalette> {
  /// App ground.
  final Color background;

  /// Secondary ground: nav bars, grouped panels.
  final Color panel;

  /// Cards, chips, inputs.
  final Color surface;

  /// Raised or selected surfaces.
  final Color surfaceHigh;

  /// 1px separators and outlines.
  final Color hairline;

  /// Primary accent: active state, shutter, selection.
  final Color amber;

  /// Secondary accent: technical readouts and counts.
  final Color cyan;

  final Color textPrimary;
  final Color textMuted;
  final Color error;
  final Color success;

  /// Date-stamp yellow is part of the film look, not the UI theme, so it is
  /// deliberately identical in both brightnesses.
  final Color dateYellow;

  const PrismPalette({
    required this.background,
    required this.panel,
    required this.surface,
    required this.surfaceHigh,
    required this.hairline,
    required this.amber,
    required this.cyan,
    required this.textPrimary,
    required this.textMuted,
    required this.error,
    required this.success,
    required this.dateYellow,
  });

  static const PrismPalette dark = PrismPalette(
    background: Color(0xFF0C0B09),
    panel: Color(0xFF161310),
    surface: Color(0xFF211C17),
    surfaceHigh: Color(0xFF2E2720),
    hairline: Color(0x18FFFFFF),
    amber: Color(0xFFD7A15A),
    cyan: Color(0xFFC8B49A),
    textPrimary: Color(0xFFF3EBDF),
    textMuted: Color(0xFF9A8B78),
    error: Color(0xFFE06A5C),
    success: Color(0xFF7DAB78),
    dateYellow: Color(0xFFFFD600),
  );

  /// Accents are darkened for the light theme so they still clear 4.5:1 on a
  /// pale ground — the same hue family, not a different brand.
  static const PrismPalette light = PrismPalette(
    background: Color(0xFFF1F3F7),
    panel: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE4E9F0),
    hairline: Color(0x1A0B1220),
    amber: Color(0xFFB4700C),
    cyan: Color(0xFF0E6F7D),
    textPrimary: Color(0xFF11161F),
    textMuted: Color(0xFF5B6675),
    error: Color(0xFFC0392B),
    success: Color(0xFF2E7D50),
    // Readable gold for UI chips. The film date stamp itself is drawn on
    // media and uses the fixed bright yellow below.
    dateYellow: Color(0xFF8A6A00),
  );

  /// The literal date-stamp yellow, for anything drawn over an image.
  static const Color filmDateYellow = Color(0xFFFFD600);

  bool get isDark => background.computeLuminance() < 0.5;

  // ── On-media ──────────────────────────────────────────────────────────
  // Chrome drawn over the camera feed or a photo sits on its own dark glass,
  // so it must NOT follow the app theme — otherwise the light theme renders
  // dark text on a dark scrim.
  static const Color onMedia = Color(0xFFF2F5F8);
  static const Color onMediaMuted = Color(0xFFB4BFCC);
  static const Color mediaGlass = Color(0x8C000000);

  /// Film-stock badge colours are tuned for a dark ground. Drawn as text or a
  /// bar on a light surface they wash out, so darken until they read.
  Color stockInk(Color stockColor) {
    if (isDark) return stockColor;
    final hsl = HSLColor.fromColor(stockColor);
    return hsl
        .withLightness((hsl.lightness * 0.55).clamp(0.16, 0.40))
        .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
        .toColor();
  }

  /// Readable ink on top of an amber fill.
  Color get onAmber => isDark ? const Color(0xFF0A0E13) : Colors.white;

  @override
  PrismPalette copyWith({
    Color? background,
    Color? panel,
    Color? surface,
    Color? surfaceHigh,
    Color? hairline,
    Color? amber,
    Color? cyan,
    Color? textPrimary,
    Color? textMuted,
    Color? error,
    Color? success,
    Color? dateYellow,
  }) {
    return PrismPalette(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      hairline: hairline ?? this.hairline,
      amber: amber ?? this.amber,
      cyan: cyan ?? this.cyan,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      error: error ?? this.error,
      success: success ?? this.success,
      dateYellow: dateYellow ?? this.dateYellow,
    );
  }

  @override
  PrismPalette lerp(ThemeExtension<PrismPalette>? other, double t) {
    if (other is! PrismPalette) return this;
    return PrismPalette(
      background: Color.lerp(background, other.background, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      dateYellow: Color.lerp(dateYellow, other.dateYellow, t)!,
    );
  }
}

extension PrismContext on BuildContext {
  /// The active palette. Falls back to dark if the extension is missing, so a
  /// widget used outside the app shell still renders.
  PrismPalette get prism =>
      Theme.of(this).extension<PrismPalette>() ?? PrismPalette.dark;
}

TextStyle _sans({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'sans-serif',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing == null ? null : 0.2,
  );
}

class PrismAppTheme {
  PrismAppTheme._();

  static ThemeData get dark => _build(PrismPalette.dark, Brightness.dark);
  static ThemeData get light => _build(PrismPalette.light, Brightness.light);

  static ThemeData _build(PrismPalette p, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      primaryColor: p.amber,
      extensions: [p],

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.amber,
        onPrimary: p.onAmber,
        secondary: p.cyan,
        onSecondary: p.onAmber,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: p.error,
        onError: Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _sans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
          letterSpacing: 1.6,
        ),
        iconTheme: IconThemeData(color: p.amber),
      ),

      iconTheme: IconThemeData(color: p.textMuted, size: 24),

      textTheme: _textTheme(p),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.amber,
          foregroundColor: p.onAmber,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _sans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.amber,
          textStyle: _sans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.amber,
          side: BorderSide(color: p.amber.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _sans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: _sans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: p.amber,
        ),
        contentTextStyle: _sans(
          fontSize: 14,
          height: 1.5,
          color: p.textMuted,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: _sans(fontSize: 13, color: p.textPrimary),
        actionTextColor: p.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.panel,
        surfaceTintColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.amber : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected)
                  ? p.amber.withValues(alpha: 0.28)
                  : p.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.hairline),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: p.amber,
        inactiveTrackColor: p.surfaceHigh,
        thumbColor: p.amber,
        overlayColor: p.amber.withValues(alpha: 0.12),
        trackHeight: 3,
      ),

      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1),

      tabBarTheme: TabBarThemeData(
        labelColor: p.amber,
        unselectedLabelColor: p.textMuted,
        indicatorColor: p.amber,
        labelStyle: _sans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        unselectedLabelStyle: _sans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.amber,
        linearTrackColor: p.surfaceHigh,
        circularTrackColor: p.surfaceHigh,
      ),

      useMaterial3: true,
    );
  }

  static TextTheme _textTheme(PrismPalette p) {
    return TextTheme(
      headlineLarge: _sans(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      ),
      headlineMedium: _sans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      ),
      titleLarge: _sans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      ),
      titleMedium: _sans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      ),
      bodyLarge: _sans(
        fontSize: 15,
        height: 1.5,
        color: p.textPrimary,
      ),
      bodyMedium: _sans(
        fontSize: 13,
        height: 1.5,
        color: p.textMuted,
      ),
      bodySmall: _sans(fontSize: 12, color: p.textMuted),
      labelLarge: _sans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      ),
      labelMedium: _sans(fontSize: 10, color: p.textMuted),
      labelSmall: _sans(fontSize: 9, color: p.textMuted),
    );
  }
}
