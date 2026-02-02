import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Colors - Rent a Car Theme (Coral/Orange)
  static const primary = Color(0xFFFF6B6B);
  static const primaryLight = Color(0xFFFF8E8E);
  static const primaryDark = Color(0xFFE85555);

  // Secondary Colors
  static const secondary = Color(0xFF4ECDC4);
  static const secondaryLight = Color(0xFF7EDDD6);
  static const secondaryDark = Color(0xFF3DBDB5);

  // Background Colors
  static const background = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceLight = Color(0xFF252542);
  static const card = Color(0xFF16213E);

  // Text Colors
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0C0);
  static const textMuted = Color(0xFF6C6C80);

  // Status Colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFB74D);
  static const error = Color(0xFFEF5350);
  static const info = Color(0xFF42A5F5);

  // Booking Status Colors
  static const statusPending = Color(0xFFFFB74D);
  static const statusConfirmed = Color(0xFF42A5F5);
  static const statusActive = Color(0xFF4CAF50);
  static const statusCompleted = Color(0xFF66BB6A);
  static const statusCancelled = Color(0xFFEF5350);

  // Gradient
  static const gradientStart = Color(0xFFFF6B6B);
  static const gradientEnd = Color(0xFF4ECDC4);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),

      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceLight,
        thickness: 1,
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        dividerThickness: 1,
      ),
    );
  }
}
