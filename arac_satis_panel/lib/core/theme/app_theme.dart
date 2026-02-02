import 'package:flutter/material.dart';
import '../../models/car_models.dart';

/// Araç Satış Panel Tema Ayarları
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: CarSalesColors.primary,
      scaffoldBackgroundColor: CarSalesColors.backgroundLight,
      colorScheme: ColorScheme.light(
        primary: CarSalesColors.primary,
        secondary: CarSalesColors.secondary,
        surface: CarSalesColors.surfaceLight,
        error: CarSalesColors.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CarSalesColors.backgroundLight,
        foregroundColor: CarSalesColors.textPrimaryLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: CarSalesColors.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: CarSalesColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CarSalesColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CarSalesColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CarSalesColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CarSalesColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CarSalesColors.accent),
        ),
        labelStyle: const TextStyle(color: CarSalesColors.textSecondaryLight),
        hintStyle: const TextStyle(color: CarSalesColors.textTertiaryLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CarSalesColors.primary,
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
          foregroundColor: CarSalesColors.primary,
          side: const BorderSide(color: CarSalesColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CarSalesColors.primary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CarSalesColors.dividerLight,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: CarSalesColors.cardLight,
        selectedItemColor: CarSalesColors.primary,
        unselectedItemColor: CarSalesColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: CarSalesColors.primary,
      scaffoldBackgroundColor: CarSalesColors.backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: CarSalesColors.primary,
        secondary: CarSalesColors.secondary,
        surface: CarSalesColors.surfaceDark,
        error: CarSalesColors.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CarSalesColors.backgroundDark,
        foregroundColor: CarSalesColors.textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: CarSalesColors.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: CarSalesColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CarSalesColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CarSalesColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CarSalesColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CarSalesColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CarSalesColors.accent),
        ),
        labelStyle: const TextStyle(color: CarSalesColors.textSecondaryDark),
        hintStyle: const TextStyle(color: CarSalesColors.textTertiaryDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CarSalesColors.primary,
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
          foregroundColor: CarSalesColors.primary,
          side: const BorderSide(color: CarSalesColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CarSalesColors.primary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CarSalesColors.dividerDark,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: CarSalesColors.cardDark,
        selectedItemColor: CarSalesColors.primary,
        unselectedItemColor: CarSalesColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
