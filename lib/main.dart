/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Main Entry Point
///
/// Next-generation disposable camera simulator with premium analog feel.
/// "Analog Magic. Digital Soul."
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/hive_boxes.dart';
import 'core/design/prism_theme.dart';
import 'screens/camera_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation for camera experience
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Set system UI style for a premium edge-to-edge experience
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Enable edge-to-edge mode
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Hive local storage
  await HiveService.init();

  runApp(const RetroLabApp());
}

class RetroLabApp extends StatelessWidget {
  const RetroLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSeenOnboarding = HiveService.hasCompletedOnboarding;

    // Rebuild the app when the theme setting changes, so the Settings toggle
    // takes effect immediately instead of on the next cold start.
    return ValueListenableBuilder(
      valueListenable: HiveService.settingsBox.listenable(keys: ['dark_mode']),
      builder: (context, _, __) {
        return MaterialApp(
          title: 'RetroLab',
          debugShowCheckedModeBanner: false,
          theme:
              HiveService.isDarkMode
                  ? PrismAppTheme.dark
                  : PrismAppTheme.light,
          home:
              hasSeenOnboarding
                  ? const CameraScreen()
                  : const OnboardingScreen(),
        );
      },
    );
  }
}
