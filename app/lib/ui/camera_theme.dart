import 'package:flutter/material.dart';

class FeatureCamColors {
  const FeatureCamColors._();

  static const background = Color(0xFF050505);
  static const surface = Color(0xDD0A0A0A);
  static const surfaceSoft = Color(0x991A1A1A);
  static const amber = Color(0xFFFFB800);
  static const amberPressed = Color(0xFFFFCC4D);
  static const recordingRed = Color(0xFFFF453A);
  static const white = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xA3FFFFFF);
  static const textDisabled = Color(0x47FFFFFF);
  static const strokeSubtle = Color(0x1FFFFFFF);
}

class FeatureCamTheme {
  const FeatureCamTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FeatureCamColors.background,
      colorScheme: const ColorScheme.dark(
        primary: FeatureCamColors.amber,
        surface: FeatureCamColors.background,
        onSurface: FeatureCamColors.white,
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
    );
  }
}
