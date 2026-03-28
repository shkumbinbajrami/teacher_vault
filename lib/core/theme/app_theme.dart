import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application-wide theme; keep spacing and component styles consistent here.
abstract final class AppTheme {
  /// Corner radius for cards, fields, buttons (keep in sync across UI).
  static const double radius = 12;
  static const double buttonRadius = 8;

  // Premium Dashboard Colors
  static const Color primaryColor = Color(0xFF4F46E5); // Indigo
  static const Color secondaryColor = Color(0xFF6366F1); // Indigo variation
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate-50
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimaryColor = Color(0xFF0F172A); // Slate-900
  static const Color textSecondaryColor = Color(0xFF64748B); // Slate-500
  static const Color outlineColor = Color(0xFFE2E8F0); // Slate-200

  // Semantic Colors
  static const Color successColor = Color(0xFF10B981); // Emerald-500
  static const Color warningColor = Color(0xFFF59E0B); // Amber-500
  static const Color errorColor = Color(0xFFF43F5E); // Rose-500

  // Standard shadow (soft, modern)
  static final List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: surfaceColor,
      error: errorColor,
    );

    // Base theme applying standard inter fonts
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
    );

    // Modern Inter TextTheme
    final interTextTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        color: textPrimaryColor,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.inter(
        color: textSecondaryColor,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.inter(
        color: textSecondaryColor,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: GoogleFonts.inter(
        color: textSecondaryColor,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        color: textSecondaryColor,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );

    return base.copyWith(
      textTheme: interTextTheme,
      primaryTextTheme: interTextTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        backgroundColor: surfaceColor,
        foregroundColor: textPrimaryColor,
        surfaceTintColor: Colors.transparent, // Disable surface tint
        shadowColor: scheme.shadow.withValues(alpha: 0.05),
        iconTheme: const IconThemeData(color: textSecondaryColor, size: 20),
        actionsIconTheme: const IconThemeData(
          color: textSecondaryColor,
          size: 20,
        ),
        titleTextStyle: interTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: interTextTheme.bodyLarge?.copyWith(
          color: textSecondaryColor,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: interTextTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: outlineColor),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: interTextTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: interTextTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: outlineColor),
        ),
        color: surfaceColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        titleTextStyle: interTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: interTextTheme.bodyMedium?.copyWith(
          color: textSecondaryColor,
        ),
      ),
    );
  }
}
