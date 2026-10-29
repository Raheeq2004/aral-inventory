import 'package:flutter/material.dart';

class AppTheme {
  // --- Color Palette ---
  static const Color primaryColor = Color(0xFF1B2A4A); // Deep Navy
  static const Color secondaryColor = Color(0xFF3B82F6); // Accent Blue
  static const Color backgroundColor = Color(
    0xFFF8FAFC,
  ); // Light Off-White/Grey
  static const Color surfaceColor = Colors.white;
  static const Color textColorPrimary = Color(0xFF0F172A);
  static const Color textColorSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  // --- Global Light Theme ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: const Color(0xFFEF4444),
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textColorPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textColorPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Card & Container Theme
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Input Decoration (TextFields) Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textColorSecondary),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textColorPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textColorPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColorPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textColorPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textColorSecondary),
        bodySmall: TextStyle(fontSize: 12, color: textColorSecondary),
      ),
    );
  }
}
