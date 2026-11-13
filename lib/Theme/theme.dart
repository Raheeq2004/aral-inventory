 
import 'package:flutter/material.dart';
 
/// `class AppTheme` only groups things together.
/// Everything inside is `static` → it belongs to the CLASS itself,
/// so we use it WITHOUT creating an object:  AppTheme.primaryColor
class AppTheme {
  // -------------------------------------------------------------------
  // 1) COLOR PALETTE
  // `static const` = one fixed value, created before the app runs,
  // shared by the whole app.
  // Color(0xFF1F3A5F): 0xFF = fully opaque, 1F3A5F = the hex color.
  // -------------------------------------------------------------------
 
  // --- Main (navy) ---
  static const Color primaryColor = Color(0xFF1F3A5F); // navy (matches Figma)
  static const Color primaryContainer = Color(0xFFD6E3F7); // light blue tint
  static const Color onPrimaryContainer = Color(0xFF0B1F3A); // text on light blue
 
  // --- Accent (burnt orange) ---
  static const Color secondaryColor = Color(0xFFC2531C); // burnt orange
  static const Color secondaryContainer = Color(0xFFFCE1D0); // light peach
  static const Color onSecondaryContainer = Color(0xFF7A2E0E); // text on peach
 
  // --- Backgrounds & text (unchanged) ---
  static const Color backgroundColor = Color(0xFFF8FAFC); // light off-white/grey
  static const Color surfaceColor = Colors.white;
  static const Color textColorPrimary = Color(0xFF0F172A);
  static const Color textColorSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
 
  // --- Status colors (meaning, not decoration) ---
  static const Color successColor = Color(0xFF1E7A3C); // IN, synced, online
  static const Color errorColor = Color(0xFFBA1A1A); // OUT, errors, offline
  
    // Dark amber → text + icons on yellow backgrounds (readable, not bright).
  static const Color warningColor = Color(0xFF7A6000);
  // Soft cream background (was #FFF0B8, too bright next to the red card).
  static const Color warningContainer = Color(0xFFFFF8E6);
  // NEW: a thin border around the cream box so it's still visible
  // on the light page background (#F8FAFC) without being loud.
  static const Color warningBorder = Color(0xFFF2DFA6);
 
  // -------------------------------------------------------------------
  // 2) THE THEME
  // `static ThemeData get lightTheme` is a GETTER: it looks like a
  // variable (AppTheme.lightTheme) but runs this code and RETURNS a
  // ThemeData object. main.dart passes it to MaterialApp(theme: ...).
  // -------------------------------------------------------------------
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor, // every Scaffold's background
 
      // ColorScheme = the named color ROLES Material widgets use
      // automatically (buttons use `primary`, chips use `secondaryContainer`…).
      // fromSeed builds a full matching palette from one color, then we
      // OVERRIDE the roles we care about so they match Figma exactly.
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        surface: surfaceColor,
        error: errorColor,
      ),
 
      // --- AppBar: white, navy-dark text, no shadow ---
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
 
      // --- Cards: white with a thin border, no shadow ---
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
 
      // --- Main buttons: NAVY (orange is only for small accents) ---
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
 
      // --- Floating action button (e.g. Export Excel): soft peach ---
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryContainer,
        foregroundColor: onSecondaryContainer,
        elevation: 2,
      ),
 
      // --- Chips (filters): selected = peach, like Figma ---
      chipTheme: ChipThemeData(
        selectedColor: secondaryContainer,
        checkmarkColor: onSecondaryContainer,
        side: const BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
 
      // --- Bottom navigation bar (admin): orange = active tab ---
      // Before, these colors were hard-coded inside admin_routing.dart.
      // Now they live HERE, so the bar follows the theme automatically.
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF1F5F9), // light grey bar
        selectedItemColor: secondaryColor, // active tab = burnt orange
        unselectedItemColor: Color(0xFF475569), // slate grey
        selectedIconTheme: IconThemeData(size: 26),
        unselectedIconTheme: IconThemeData(size: 24),
        type: BottomNavigationBarType.fixed,
      ),
 
      // --- Loading spinners: navy ---
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
 
      // --- Text fields: thin border, ORANGE border when focused ---
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
 
      // --- Text styles (unchanged) ---
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