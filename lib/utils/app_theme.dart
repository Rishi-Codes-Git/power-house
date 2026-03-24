import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary green colors
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color accentGreen = Color(0xFF66BB6A);

  // Background colors
  static const Color backgroundColor = Color(0xFFF1F8E9);
  static const Color cardColor = Colors.white;
  static const Color surfaceColor = Color(0xFFE8F5E9);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color darkCard = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF1A1A1A);

  // Text colors
  static const Color textPrimary = Color(0xFF1B5E20);
  static const Color textSecondary = Color(0xFF558B2F);
  static const Color textLight = Color(0xFF81C784);

  // Status colors
  static const Color statusSafe = Color(0xFF22C55E);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFEF4444);
  static const Color statusCritical = Color(0xFFDC2626);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: accentGreen,
        surface: surfaceColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightGreen.withAlpha(128)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightGreen.withAlpha(128)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: textSecondary),
        hintStyle: GoogleFonts.poppins(color: textLight),
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: accentGreen,
        surface: darkSurface,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkCard,
        indicatorColor: primaryGreen.withAlpha(77),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
