import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────
class PramaanColors {
  // Professional Enterprise Colors
  static const Color primary = Color(0xFF1976D2); // Standard professional blue
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  
  static const Color accent = Color(0xFF0288D1); 
  static const Color accentLight = Color(0xFF03A9F4);

  // Risk levels
  static const Color riskLow = Color(0xFF2E7D32); // Professional green
  static const Color riskMedium = Color(0xFFF57F17); // Professional orange/amber
  static const Color riskHigh = Color(0xFFE65100); 
  static const Color riskCritical = Color(0xFFC62828); // Professional red

  // Surface colors (Light Mode)
  static const Color surfaceDark = Color(0xFFF5F7FA); // Background
  static const Color surfaceCard = Color(0xFFFFFFFF); // White cards
  static const Color surfaceLight = Color(0xFFE8ECEF); // Light grey elements
  static const Color divider = Color(0xFFE0E0E0); // Clean grey dividers

  // Text
  static const Color textPrimary = Color(0xFF263238); // Dark grey, not pure black
  static const Color textSecondary = Color(0xFF546E7A); 
  static const Color textMuted = Color(0xFF90A4AE);

  // Status
  static const Color pass = Color(0xFF27AE60);
  static const Color fail = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  PramaanColors._();
}

// ─── Risk Level Enum ──────────────────────────────────────────────────────────
enum RiskLevel { low, medium, high, critical }

extension RiskLevelExt on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'LOW RISK';
      case RiskLevel.medium:
        return 'MEDIUM RISK';
      case RiskLevel.high:
        return 'HIGH RISK';
      case RiskLevel.critical:
        return 'CRITICAL';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.low:
        return PramaanColors.riskLow;
      case RiskLevel.medium:
        return PramaanColors.riskMedium;
      case RiskLevel.high:
        return PramaanColors.riskHigh;
      case RiskLevel.critical:
        return PramaanColors.riskCritical;
    }
  }

  IconData get icon {
    switch (this) {
      case RiskLevel.low:
        return Icons.verified_user;
      case RiskLevel.medium:
        return Icons.warning_amber;
      case RiskLevel.high:
        return Icons.gpp_bad;
      case RiskLevel.critical:
        return Icons.dangerous;
    }
  }

  static RiskLevel fromScore(double score) {
    if (score < 20) return RiskLevel.low;
    if (score < 45) return RiskLevel.medium;
    if (score < 70) return RiskLevel.high;
    return RiskLevel.critical;
  }
}

// ─── Theme ────────────────────────────────────────────────────────────────────
class PramaanTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PramaanColors.primary,
        brightness: Brightness.light,
        primary: PramaanColors.primary,
        secondary: PramaanColors.accent,
        surface: PramaanColors.surfaceDark,
        onSurface: PramaanColors.textPrimary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: PramaanColors.surfaceDark,
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: PramaanColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 2.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: PramaanColors.surfaceCard,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PramaanColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PramaanColors.primary,
          side: const BorderSide(color: PramaanColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PramaanColors.surfaceCard,
        labelStyle: GoogleFonts.roboto(color: PramaanColors.textSecondary),
        hintStyle: GoogleFonts.roboto(color: PramaanColors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PramaanColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PramaanColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PramaanColors.riskCritical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PramaanColors.riskCritical, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: PramaanColors.divider,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PramaanColors.surfaceLight,
        labelStyle: GoogleFonts.roboto(color: PramaanColors.textPrimary, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: GoogleFonts.rajdhani(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: PramaanColors.textPrimary,
        letterSpacing: -0.25,
      ),
      displayMedium: GoogleFonts.rajdhani(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: PramaanColors.textPrimary,
      ),
      displaySmall: GoogleFonts.rajdhani(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: PramaanColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.rajdhani(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: PramaanColors.textPrimary,
        letterSpacing: 1.0,
      ),
      headlineMedium: GoogleFonts.rajdhani(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: PramaanColors.textPrimary,
        letterSpacing: 0.5,
      ),
      headlineSmall: GoogleFonts.rajdhani(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: PramaanColors.textPrimary,
      ),
      titleLarge: GoogleFonts.rajdhani(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: PramaanColors.textPrimary,
        letterSpacing: 0.5,
      ),
      titleMedium: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: PramaanColors.textPrimary,
      ),
      titleSmall: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: PramaanColors.textSecondary,
      ),
      bodyLarge: GoogleFonts.roboto(
        fontSize: 16,
        color: PramaanColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.roboto(
        fontSize: 14,
        color: PramaanColors.textSecondary,
      ),
      bodySmall: GoogleFonts.roboto(
        fontSize: 12,
        color: PramaanColors.textMuted,
      ),
      labelLarge: GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: PramaanColors.textPrimary,
      ),
      labelMedium: GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: PramaanColors.textSecondary,
      ),
      labelSmall: GoogleFonts.roboto(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: PramaanColors.textMuted,
      ),
    );
  }
}
