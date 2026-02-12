import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences
const _themeModeKey = 'theme_mode';
const _localeKey = 'locale';
const _biometricKey = 'biometric_login';
const _autoUpdateKey = 'auto_update';
const _currencyKey = 'currency';

// Settings state class
class AppSettings {
  final ThemeMode themeMode;
  final Locale locale;
  final bool biometricLogin;
  final bool autoUpdate;
  final String currency;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('tr', 'TR'),
    this.biometricLogin = false,
    this.autoUpdate = true,
    this.currency = 'TRY (₺)',
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? biometricLogin,
    bool? autoUpdate,
    String? currency,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      biometricLogin: biometricLogin ?? this.biometricLogin,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      currency: currency ?? this.currency,
    );
  }
}

// Settings notifier
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeIndex = prefs.getInt(_themeModeKey) ?? 0;
    final themeMode = ThemeMode.values[themeModeIndex];
    final localeCode = prefs.getString(_localeKey) ?? 'tr';
    final locale = _getLocaleFromCode(localeCode);

    state = AppSettings(
      themeMode: themeMode,
      locale: locale,
      biometricLogin: prefs.getBool(_biometricKey) ?? false,
      autoUpdate: prefs.getBool(_autoUpdateKey) ?? true,
      currency: prefs.getString(_currencyKey) ?? 'TRY (₺)',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    state = state.copyWith(locale: locale);
  }

  Future<void> setBiometricLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
    state = state.copyWith(biometricLogin: value);
  }

  Future<void> setAutoUpdate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUpdateKey, value);
    state = state.copyWith(autoUpdate: value);
  }

  Future<void> setCurrency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, value);
    state = state.copyWith(currency: value);
  }

  Future<void> toggleDarkMode() async {
    final newMode = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  Locale _getLocaleFromCode(String code) {
    switch (code) {
      case 'en':
        return const Locale('en', 'US');
      case 'de':
        return const Locale('de', 'DE');
      case 'fr':
        return const Locale('fr', 'FR');
      case 'es':
        return const Locale('es', 'ES');
      case 'ar':
        return const Locale('ar', 'SA');
      case 'tr':
      default:
        return const Locale('tr', 'TR');
    }
  }
}

// Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

// Convenience providers
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

final localeProvider = Provider<Locale>((ref) {
  return ref.watch(settingsProvider).locale;
});

// Helper to get language name from locale
String getLanguageName(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return 'English';
    case 'de':
      return 'Deutsch';
    case 'fr':
      return 'Français';
    case 'es':
      return 'Español';
    case 'ar':
      return 'العربية';
    case 'tr':
    default:
      return 'Türkçe';
  }
}

// Supported locales
const supportedLocales = [
  Locale('tr', 'TR'),
  Locale('en', 'US'),
  Locale('de', 'DE'),
  Locale('fr', 'FR'),
  Locale('es', 'ES'),
  Locale('ar', 'SA'),
];
