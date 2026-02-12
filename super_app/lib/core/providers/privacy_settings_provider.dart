import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PrivacySettingsState {
  final bool locationServices;
  final bool analytics;
  final bool personalizedAds;
  final bool isLoading;

  const PrivacySettingsState({
    this.locationServices = true,
    this.analytics = true,
    this.personalizedAds = false,
    this.isLoading = true,
  });

  PrivacySettingsState copyWith({
    bool? locationServices,
    bool? analytics,
    bool? personalizedAds,
    bool? isLoading,
  }) {
    return PrivacySettingsState(
      locationServices: locationServices ?? this.locationServices,
      analytics: analytics ?? this.analytics,
      personalizedAds: personalizedAds ?? this.personalizedAds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PrivacySettingsNotifier extends StateNotifier<PrivacySettingsState> {
  PrivacySettingsNotifier() : super(const PrivacySettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = PrivacySettingsState(
      locationServices: prefs.getBool('privacy_location') ?? true,
      analytics: prefs.getBool('privacy_analytics') ?? true,
      personalizedAds: prefs.getBool('privacy_ads') ?? false,
      isLoading: false,
    );
  }

  Future<void> setLocationServices(bool value) async {
    if (value) {
      // Kullanıcı açmak istiyor - izin kontrolü
      final status = await Permission.location.status;
      if (status.isDenied) {
        final result = await Permission.location.request();
        if (!result.isGranted) {
          // İzin verilmedi, ayarı açma
          return;
        }
      } else if (status.isPermanentlyDenied) {
        // Ayarlara yönlendir
        await openAppSettings();
        return;
      }
    }

    state = state.copyWith(locationServices: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_location', value);
  }

  Future<void> setAnalytics(bool value) async {
    state = state.copyWith(analytics: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_analytics', value);
  }

  Future<void> setPersonalizedAds(bool value) async {
    state = state.copyWith(personalizedAds: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_ads', value);
  }
}

final privacySettingsProvider =
    StateNotifierProvider<PrivacySettingsNotifier, PrivacySettingsState>(
  (ref) => PrivacySettingsNotifier(),
);

/// Konum kullanılabilir mi kontrolü - uygulama genelinde bu provider'ı kontrol et
final isLocationEnabledProvider = Provider<bool>((ref) {
  return ref.watch(privacySettingsProvider).locationServices;
});
