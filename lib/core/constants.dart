/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Core Constants
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';

// ── Brand Colors ─────────────────────────────────────────────────────────────

class RetroColors {
  RetroColors._();

  // Primary palette
  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF242424);
  static const Color accent = Color(0xFFFF6200);
  static const Color accentLight = Color(0xFFFF8A3D);
  static const Color accentDark = Color(0xFFCC4E00);

  // Date stamp yellow (classic disposable cam)
  static const Color dateYellow = Color(0xFFFFD600);
  static const Color dateOrange = Color(0xFFFF9100);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF666666);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB300);

  // Film stock badge colors
  static const Color kodakYellow = Color(0xFFFFD600);
  static const Color fujiGreen = Color(0xFF66BB6A);
  static const Color ilfordWhite = Color(0xFFE0E0E0);
  static const Color polaroidWhite = Color(0xFFF5F5F5);
  static const Color lomoBlue = Color(0xFF42A5F5);
  static const Color expiredPink = Color(0xFFE91E63);

  // Daylight theme
  static const Color lightBackground = Color(0xFFFFF8E1);
  static const Color lightSurface = Color(0xFFFFECB3);
  static const Color lightTextPrimary = Color(0xFF212121);
}

/// Palette for the capture screen. Controls live on their own panels instead of
/// floating over the frame, so the image you are composing is never obscured.
class PrismColors {
  PrismColors._();

  static const Color background = Color(0xFF0A0E13);
  static const Color panel = Color(0xFF11161D);
  static const Color surface = Color(0xFF1A222C);
  static const Color surfaceHigh = Color(0xFF232D39);
  static const Color hairline = Color(0x14FFFFFF);

  /// Primary: active state, shutter, selection.
  static const Color amber = Color(0xFFE9A23B);

  /// Secondary: technical readouts (shutter speed, ISO, counts).
  static const Color cyan = Color(0xFF55C8D8);

  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF78869A);
}

// ── Dimensions ───────────────────────────────────────────────────────────────

class RetroDimens {
  RetroDimens._();

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;

  static const double paddingSm = 8.0;
  static const double paddingMd = 16.0;
  static const double paddingLg = 24.0;
  static const double paddingXl = 32.0;

  static const double shutterButtonSize = 80.0;
  static const double shutterButtonInner = 64.0;

  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
}

class RetroDefaults {
  RetroDefaults._();

  static const double grain = 0.58;
  static const double leakStrength = 0.35;
  static const double dustStrength = 1.0;
  static const double vignette = 1.0;
  static const double scratchLevel = 1.0;
}

// ── Strings ──────────────────────────────────────────────────────────────────

class RetroStrings {
  RetroStrings._();

  static const String appName = 'RetroLab';
  static const String tagline = '按下快门之前，就能看见胶片。';
  static const String watermark = 'RetroLab · 2026';
  static const String developing = '冲洗中…';
  static const String filmFinished = '这卷拍完了';
  static const String loadNewRoll = '装上新卷';
  static const String exposuresRemaining = '张';
  static const String ready = '好了';
  static const String working = '处理中…';

  /// Labels for the real pipeline stages reported by ImageProcessor.
  /// Index matches ProcessingStage.index.
  static const List<String> processingStages = [
    '装入底片…',
    '倒入药液…',
    '显影色彩…',
    '加上颗粒…',
    '定影…',
    '晾干…',
  ];

  // Onboarding
  static const String onboardTitle1 = '取景器里就是成片';
  static const String onboardBody1 =
      '换胶卷时，画面会马上变。不用拍完再猜。';
  static const String onboardTitle2 = '先选一卷胶片';
  static const String onboardBody2 =
      '十九种性格：暖金、肖像、黑白、夜灯、拍立得。每卷只拍这一卷的样子。';
  static const String onboardTitle3 = '拍完还可以再冲洗';
  static const String onboardBody3 =
      '颗粒、漏光和划痕会留在成片上。相册里的照片也能重新冲洗。';
}

// ── Asset Paths ──────────────────────────────────────────────────────────────

class RetroAssets {
  RetroAssets._();

  static const String lightLeakPrefix = 'assets/light_leaks/leak_';
  static const String lottieDeveloping = 'assets/lottie/developing.json';
  static const String lottieFilmReel = 'assets/lottie/film_reel.json';
  static const String soundShutter = 'assets/sounds/shutter.mp3';
  static const String textureScratch = 'assets/textures/scratch.png';
  static const String textureDust = 'assets/textures/dust.png';

  static String lightLeak(int index) => '$lightLeakPrefix$index.jpg';
}

// ── Hive Box Names ───────────────────────────────────────────────────────────

class HiveBoxes {
  HiveBoxes._();

  static const String photos = 'retro_photos';
  static const String videos = 'retro_videos';
  static const String rolls = 'film_rolls';
  static const String settings = 'app_settings';
  static const String stats = 'user_stats';
}

// ── Date Stamp Styles ────────────────────────────────────────────────────────

enum DateStampStyle {
  classic90s('90 年代'),
  handwritten('手写'),
  polaroid('拍立得');

  final String label;
  const DateStampStyle(this.label);
}

enum DateStampPosition {
  bottomRight('右下'),
  bottomLeft('左下'),
  bottomCenter('底部居中');

  final String label;
  const DateStampPosition(this.label);
}

// ── Timer Durations ──────────────────────────────────────────────────────────

enum ShutterTimer {
  off(0, 'OFF'),
  threeSeconds(3, '3s'),
  tenSeconds(10, '10s');

  final int seconds;
  final String label;
  const ShutterTimer(this.seconds, this.label);
}
