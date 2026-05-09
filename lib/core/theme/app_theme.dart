import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';

abstract final class AppTheme {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0C0C0E);
  static const Color surfaceVariant = Color(0xFF141418);
  static const Color outline = Color(0xFF2A2A30);
  static const Color accent = Color(0xFF21D4C8);
  static const Color accentDim = Color(0xFF148A82);
  static const Color emergency = Color(0xFFE53935);
  static const Color onSurfaceMuted = Color(0xFF8E8E93);

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        surface: surface,
        primary: accent,
        onPrimary: Colors.black,
        secondary: accentDim,
        error: emergency,
        onSurface: Colors.white,
        outline: outline,
      ),
    );

    final outfit = GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: outfit.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          side: const BorderSide(color: outline, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: onSurfaceMuted),
        hintStyle: const TextStyle(color: onSurfaceMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceVariant,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
      ),
    );
  }
}
