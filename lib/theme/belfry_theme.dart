import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens ported from the Belfry.html prototype. The prototype uses
/// oklch values; these are the resolved sRGB equivalents.
class BelfryColors {
  const BelfryColors._();

  static const bg = Color(0xFFFAF8F5);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14110D);
  static const ink2 = Color(0xFF514C47);
  static const ink3 = Color(0xFF8A8580);
  static const line = Color(0xFFE4E1DB);
  static const line2 = Color(0xFFD4D0CA);
  static const accent = Color(0xFFE78B30);
  static const accentInk = Color(0xFF5F1600);
  static const accentSoft = Color(0xFFFFEFD5);
  static const danger = Color(0xFFDE4E4B);
  static const primary = Color(0xFFC66A3F);
  static const primarySoft = Color(0xFFFFECD8);

  /// Near-white used for text/icons on [primary] / [accent] fills.
  static const onPrimary = Color(0xFFFDFBF8);

  static const railBg = Color(0xFFF9F4EE);
  static const dayHover = Color(0xFFEFEBE4);
  static const navHover = Color(0xFFF0EEEB);
  static const tagBg = Color(0xFFF0EEEB);
  static const dtpSummary = Color(0xFFFCF8F1);
  static const success = Color(0xFF31AA40);
  static const alarmNotes = Color(0xFFF7F5F1);
  static const dayMuted = Color(0xFFBCB6B1);
  static const offHover = Color(0xFFF3F1EE);

  /// Modal scrim — oklch(0.2 0.01 70 / 0.45).
  static const scrim = Color(0x73191511);

  /// Alarm scrim — oklch(0.2 0.02 60 / 0.6).
  static const alarmScrim = Color(0x991D140D);

  /// Card hover shadow.
  static const cardShadow = Color(0x14282318);
}

/// Shared text styles. The prototype pairs a system sans for UI text with
/// JetBrains Mono for clocks, times and numeric displays.
class BelfryText {
  const BelfryText._();

  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = BelfryColors.ink,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle sans({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = BelfryColors.ink,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _sansFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Uppercase label style used for section headers and field labels.
  static TextStyle label({
    double size = 12,
    Color color = BelfryColors.ink2,
    FontWeight weight = FontWeight.w500,
  }) {
    return sans(
      size: size,
      weight: weight,
      color: color,
      letterSpacing: size <= 11 ? 1.0 : 0.5,
    );
  }

  // The prototype's stack is "Helvetica Neue, Helvetica, Arial, sans-serif".
  // Helvetica Neue is the default on macOS; Android falls back to Roboto.
  static const String? _sansFamily = null;
}

ThemeData buildBelfryTheme() {
  const scheme = ColorScheme.light(
    primary: BelfryColors.primary,
    onPrimary: BelfryColors.onPrimary,
    secondary: BelfryColors.accent,
    onSecondary: BelfryColors.onPrimary,
    surface: BelfryColors.panel,
    onSurface: BelfryColors.ink,
    error: BelfryColors.danger,
    onError: BelfryColors.onPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BelfryColors.bg,
    splashFactory: InkRipple.splashFactory,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: BelfryColors.ink,
      displayColor: BelfryColors.ink,
    ),
    visualDensity: VisualDensity.standard,
  );
}
