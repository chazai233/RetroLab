/// ─────────────────────────────────────────────────────────────────────────────
/// Neumorphism — Design Tokens (translated from design.md, version: alpha)
///
/// Soft 3D surfaces built from a single light source at the top-left. Every
/// surface is the SAME colour as its background; depth comes only from paired
/// shadows. That is the whole trick — and the whole limitation.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';

// ── Colours ──────────────────────────────────────────────────────────────────

class NeuColors {
  NeuColors._();

  // Palette straight from the front matter.
  static const Color primary = Color(0xFFC8E0F4); // Soft Blue
  static const Color secondary = Color(0xFFF5E0E8); // Soft Pink
  static const Color tertiary = Color(0xFFE8E8E8); // Soft Grey

  /// The base surface. Neumorphism needs one flat ground that every raised or
  /// inset element also uses, so the grey tone becomes the canvas.
  static const Color surfaceLight = tertiary;
  static const Color surfaceDark = Color(0xFF2E3238);

  // Light-source shadows: -5px -5px light, 5px 5px dark (see design.md).
  static const Color lightShadowOnLight = Color(0xFFFFFFFF);
  static const Color darkShadowOnLight = Color(0x33A3B1C6);
  static const Color lightShadowOnDark = Color(0x14FFFFFF);
  static const Color darkShadowOnDark = Color(0x66000000);

  /// design.md lists the pastels as "primary/secondary text colour", but at
  /// ~1.1:1 against the surface they are unreadable. Text is derived instead,
  /// honouring the "no pure black — use off-black or charcoal" rule.
  static const Color textOnLight = Color(0xFF2E3138); // charcoal, ~11:1
  static const Color textMutedOnLight = Color(0xFF6B7280); // ~4.8:1
  static const Color textOnDark = Color(0xFFECEFF3);
  static const Color textMutedOnDark = Color(0xFFA0A8B4);

  /// Accents are the pastels pushed to a usable saturation for interactive
  /// fills. Saturation stays under the 80% cap from the Do's and Don'ts.
  static const Color accent = Color(0xFF5B8FB9);
  static const Color accentPressed = Color(0xFF4A7BA1);
  static const Color error = Color(0xFFC2626B);
  static const Color success = Color(0xFF6B9E78);
}

// ── Shape ────────────────────────────────────────────────────────────────────

class NeuRadius {
  NeuRadius._();

  static const double sm = 14.0;
  static const double md = 28.0;
  static const double lg = 42.0;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
}

// ── Spacing ──────────────────────────────────────────────────────────────────

class NeuSpacing {
  NeuSpacing._();

  /// Base unit: 0.5rem.
  static const double unit = 8.0;

  static const double xs = unit * 0.5; // 4
  static const double sm = unit; // 8
  static const double md = unit * 2; // 16
  static const double lg = unit * 3; // 24
  static const double xl = unit * 4; // 32

  /// Section vertical gap: clamp(4rem, 8vw, 8rem).
  static double section(double width) => (width * 0.08).clamp(64.0, 128.0);

  /// Max-width containment: 1280px centred with 1.5rem side padding.
  static const double maxContentWidth = 1280.0;
  static const double sidePadding = 24.0;

  /// Multi-column layouts collapse below this.
  static const double mobileBreakpoint = 768.0;
}

// ── Motion ───────────────────────────────────────────────────────────────────

class NeuMotion {
  NeuMotion._();

  static const Duration press = Duration(milliseconds: 150);
  static const Duration hover = Duration(milliseconds: 200);
  static const Duration pageTransition = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration entry = Duration(milliseconds: 420);

  /// Delay between staggered list items.
  static const Duration stagger = Duration(milliseconds: 80);

  /// Entry animation travel: translate-Y 16px → 0.
  static const double entryOffsetY = 16.0;

  static const Curve curve = Curves.easeOut;
}

// ── Layering ─────────────────────────────────────────────────────────────────

/// z-index contract from design.md.
class NeuLayer {
  NeuLayer._();

  static const int base = 0;
  static const int stickyNav = 100;
  static const int overlay = 200;
  static const int modal = 300;
  static const int toast = 500;
}

// ── Elevation ────────────────────────────────────────────────────────────────

/// The paired shadows that make a surface read as raised or inset.
/// design.md: `-5px -5px 15px` light, `5px 5px 15px` dark.
class NeuShadows {
  NeuShadows._();

  static const double _offset = 5.0;
  static const double _blur = 15.0;

  static List<BoxShadow> raised(Brightness brightness, {double depth = 1.0}) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? NeuColors.lightShadowOnDark
            : NeuColors.lightShadowOnLight,
        offset: const Offset(-_offset, -_offset) * depth,
        blurRadius: _blur * depth,
      ),
      BoxShadow(
        color:
            isDark ? NeuColors.darkShadowOnDark : NeuColors.darkShadowOnLight,
        offset: const Offset(_offset, _offset) * depth,
        blurRadius: _blur * depth,
      ),
    ];
  }

  /// Same pair, reversed, drawn inside the shape. Flutter's BoxShadow cannot
  /// do inset, so NeuSurface paints these with a clipped painter instead.
  static List<BoxShadow> inset(Brightness brightness, {double depth = 1.0}) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color:
            isDark ? NeuColors.darkShadowOnDark : NeuColors.darkShadowOnLight,
        offset: const Offset(_offset, _offset) * depth,
        blurRadius: _blur * depth,
      ),
      BoxShadow(
        color: isDark
            ? NeuColors.lightShadowOnDark
            : NeuColors.lightShadowOnLight,
        offset: const Offset(-_offset, -_offset) * depth,
        blurRadius: _blur * depth,
      ),
    ];
  }
}

// ── Typography ───────────────────────────────────────────────────────────────

/// System UI stack. On Flutter a null fontFamily resolves to the platform face
/// (SF on iOS, Roboto on Android), which is what `-apple-system, sans-serif`
/// asks for — so no webfont download is needed for the core scale.
class NeuType {
  NeuType._();

  static const String? systemStack = null;
  static const String monoFamily = 'JetBrains Mono';

  /// Hero: clamp(2.5rem, 5vw, 4rem).
  static double heroSize(double width) => (width * 0.05).clamp(40.0, 64.0);

  static const TextStyle h1 = TextStyle(
    fontFamily: systemStack,
    fontSize: 36, // 2.25rem
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5, // tight tracking
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: systemStack,
    fontSize: 24, // 1.5rem
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: systemStack,
    fontSize: 16, // 1rem
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static const TextStyle small = TextStyle(
    fontFamily: systemStack,
    fontSize: 14, // 0.875rem
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// label-caps from the front matter.
  static const TextStyle labelCaps = TextStyle(
    fontFamily: systemStack,
    fontSize: 12, // 0.75rem
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );
}
