import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryDark,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        error: AppColors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1),
          displayMedium: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.2),
          displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.2),
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          bodyLarge: TextStyle(fontSize: 18, color: AppColors.textSecondary, height: 1.6),
          bodyMedium: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
          bodySmall: TextStyle(fontSize: 14, color: AppColors.textMuted),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
