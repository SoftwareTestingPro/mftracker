import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color bgPrimary = Color(0xFF0F172A);
  static const Color bgSecondary = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  
  static const Color brandPrimary = Color(0xFF3B82F6);
  static const Color brandSecondary = Color(0xFF8B5CF6);
  
  static const Color successColor = Color(0xFF10B981);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);

  // Spacing & Sizes
  static const double screenPadding = 24.0;
  static const double cardPadding = 20.0;
  static const double cardRadius = 24.0;

  // Glassmorphism Decoration
  static BoxDecoration glassDecoration({Color? color, Color? borderColor}) {
    return BoxDecoration(
      color: (color ?? bgSecondary).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: (borderColor ?? Colors.white).withValues(alpha: 0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      canvasColor: bgPrimary,
      primaryColor: brandPrimary,
      colorScheme: const ColorScheme.dark(
        primary: brandPrimary,
        secondary: brandSecondary,
        surface: bgPrimary, // Unified with scaffold
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        error: dangerColor,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 36),
        displayMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 32),
        displaySmall: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 28),
        headlineLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 26),
        headlineMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 24),
        headlineSmall: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
        titleLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        titleSmall: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 18),
        bodyMedium: GoogleFonts.inter(color: textPrimary, fontSize: 16),
        bodySmall: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: bgSecondary.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
