import 'package:flutter/material.dart';
import '../../models/emlak_models.dart';

/// Emlakçı Panel Tema Ayarları
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: EmlakColors.primary,
      scaffoldBackgroundColor: EmlakColors.backgroundLight,
      colorScheme: ColorScheme.light(
        primary: EmlakColors.primary,
        secondary: EmlakColors.secondary,
        surface: EmlakColors.surfaceLight,
        error: EmlakColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: EmlakColors.backgroundLight,
        foregroundColor: EmlakColors.textPrimaryLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: EmlakColors.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: EmlakColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EmlakColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EmlakColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EmlakColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EmlakColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EmlakColors.error),
        ),
        labelStyle: const TextStyle(color: EmlakColors.textSecondaryLight),
        hintStyle: const TextStyle(color: EmlakColors.textTertiaryLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EmlakColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EmlakColors.primary,
          side: const BorderSide(color: EmlakColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EmlakColors.primary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: EmlakColors.dividerLight,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: EmlakColors.cardLight,
        selectedItemColor: EmlakColors.primary,
        unselectedItemColor: EmlakColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: EmlakColors.primary,
      scaffoldBackgroundColor: EmlakColors.backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: EmlakColors.primary,
        secondary: EmlakColors.secondary,
        surface: EmlakColors.surfaceDark,
        error: EmlakColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: EmlakColors.backgroundDark,
        foregroundColor: EmlakColors.textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: EmlakColors.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: EmlakColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EmlakColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EmlakColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EmlakColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EmlakColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EmlakColors.error),
        ),
        labelStyle: const TextStyle(color: EmlakColors.textSecondaryDark),
        hintStyle: const TextStyle(color: EmlakColors.textTertiaryDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EmlakColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EmlakColors.primary,
          side: const BorderSide(color: EmlakColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EmlakColors.primary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: EmlakColors.dividerDark,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: EmlakColors.cardDark,
        selectedItemColor: EmlakColors.primary,
        unselectedItemColor: EmlakColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
