import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const primary = Color(0xFF0EA5E9);
  static const primaryDark = Color(0xFF0284C7);
  static const primaryLight = Color(0xFF38BDF8);

  // Secondary
  static const secondary = Color(0xFF14B8A6);
  static const secondaryDark = Color(0xFF0D9488);

  // Accent
  static const accent = Color(0xFFF59E0B);
  static const accentDark = Color(0xFFD97706);

  // Status
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Light theme
  static const backgroundLight = Color(0xFFF8FAFC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE2E8F0);
  static const textPrimaryLight = Color(0xFF0F172A);
  static const textSecondaryLight = Color(0xFF475569);
  static const textMutedLight = Color(0xFF94A3B8);

  // Dark theme
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const cardDark = Color(0xFF1E293B);
  static const borderDark = Color(0xFF334155);
  static const textPrimaryDark = Color(0xFFF8FAFC);
  static const textSecondaryDark = Color(0xFFCBD5E1);
  static const textMutedDark = Color(0xFF64748B);

  // Sidebar
  static const sidebarBg = Color(0xFF1E293B);
  static const sidebarText = Color(0xFFCBD5E1);
  static const sidebarTextMuted = Colors.white38;
  static const sidebarActive = Color(0xFF0EA5E9);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  );

  // Chart colors
  static const chartColors = [
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  // Helpers
  static Color background(bool isDark) => isDark ? backgroundDark : backgroundLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textMuted(bool isDark) => isDark ? textMutedDark : textMutedLight;
}
