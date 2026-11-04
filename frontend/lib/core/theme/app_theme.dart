import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentCyan = Color(0xFF0284C7);
  static const Color tukkaViolet = Color(0xFF7C3AED);
  static const Color bgGrey = Color(0xFFF3F4F6);

  // GATE Question Palette Colors
  static const Color answeredGreen = Color(0xFF22C55E);
  static const Color notAnsweredRed = Color(0xFFEF4444);
  static const Color markedReviewPurple = Color(0xFF9333EA);
  static const Color notVisitedGrey = Color(0xFFE5E7EB);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: bgGrey,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      fontFamily: 'Segoe UI',
    );
  }
}
