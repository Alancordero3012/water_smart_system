import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark Backgrounds
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);

  // Accents (Neon/Electric)
  static const Color primaryCyan = Color(0xFF00E5FF); // Electric Cyan
  static const Color secondaryEmerald = Color(0xFF00E676); // Neon Green
  static const Color alertOrange = Color(0xFFFF9100); // Amber Neon
  static const Color alertRed = Color(0xFFFF1744); // Red Neon

  static ThemeData get darkTheme {
    final base = ThemeData.dark();

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: secondaryEmerald,
        surface: surface,
        error: alertRed,
        onSurface: Colors.white,
      ),
      // Modern Typography (Fallback to standard if GoogleFonts fails)
      /*
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
            fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: Colors.white70),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: Colors.white60),
      ),
      */
      // Removed CardTheme to avoid type conflicts in this environment
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
    );
  }
}
