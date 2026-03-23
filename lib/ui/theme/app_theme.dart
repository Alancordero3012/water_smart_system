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
      // Typography — Usando textTheme del sistema con ajustes
      // Para habilitar Google Fonts, descomenta la dependencia y las líneas:
      // textTheme: GoogleFonts.interTextTheme(base.textTheme),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: const TextStyle(fontSize: 16, color: Colors.white70),
        bodyMedium: const TextStyle(fontSize: 14, color: Colors.white60),
      ),
      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
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
      // Dividers
      dividerTheme: const DividerThemeData(
        color: Colors.white12,
        thickness: 1,
      ),
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
