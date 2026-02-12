import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

class NotificationPreferencesState {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final bool orderUpdates;
  final bool campaigns;
  final bool newFeatures;
  final bool isLoading;

  const NotificationPreferencesState({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.smsEnabled = false,
    this.orderUpdates = true,
    this.campaigns = true,
    this.newFeatures = false,
    this.isLoading = true,
  });

  NotificationPreferencesState copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    bool? orderUpdates,
    bool? campaigns,
    bool? newFeatures,
    bool? isLoading,
  }) {
    return NotificationPreferencesState(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      orderUpdates: orderUpdates ?? this.orderUpdates,
      campaigns: campaigns ?? this.campaigns,
      newFeatures: newFeatures ?? this.newFeatures,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Belirli bir bildirim tipinin gösterilip gösterilmeyeceğini kontrol eder
  bool shouldShowNotification(String type) {
    if (!pushEnabled) return false;
    switch (type) {
      case 'order_update':
      case 'store_order':
        return orderUpdates;
      case 'campaign':
      case 'promotion':
        return campaigns;
      case 'new_feature':
      case 'update':
        return newFeatures;
      default:
        return true; // Bilinmeyen tipler her zaman gösterilir
    }
  }
}

class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferencesState> {
  NotificationPreferencesNotifier()
      : super(const NotificationPreferencesState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadFromLocal();
    await _loadFromSupabase();
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      pushEnabled: prefs.getBool('notif_push') ?? true,
      emailEnabled: prefs.getBool('notif_email') ?? true,
      smsEnabled: prefs.getBool('notif_sms') ?? false,
      orderUpdates: prefs.getBool('notif_order_updates') ?? true,
      campaigns: prefs.getBool('notif_campaigns') ?? true,
      newFeatures: prefs.getBool('notif_new_features') ?? false,
    );
  }

  Future<void> _loadFromSupabase() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        state = state.copyWith(
          pushEnabled: response['push_enabled'] as bool? ?? true,
          emailEnabled: response['email_enabled'] as bool? ?? true,
          smsEnabled: response['sms_enabled'] as bool? ?? false,
          orderUpdates: response['order_updates'] as bool? ?? true,
          campaigns: response['campaigns'] as bool? ?? true,
          newFeatures: response['new_features'] as bool? ?? false,
          isLoading: false,
        );
        // Supabase'den gelen değerleri local'e de kaydet
        await _saveAllToLocal();
      } else {
        // Henüz kayıt yok, mevcut local değerlerle oluştur
        await _saveToSupabase();
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading notification preferences: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveAllToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_push', state.pushEnabled);
    await prefs.setBool('notif_email', state.emailEnabled);
    await prefs.setBool('notif_sms', state.smsEnabled);
    await prefs.setBool('notif_order_updates', state.orderUpdates);
    await prefs.setBool('notif_campaigns', state.campaigns);
    await prefs.setBool('notif_new_features', state.newFeatures);
  }

  Future<void> _saveToSupabase() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.client.from('notification_preferences').upsert({
        'user_id': userId,
        'push_enabled': state.pushEnabled,
        'email_enabled': state.emailEnabled,
        'sms_enabled': state.smsEnabled,
        'order_updates': state.orderUpdates,
        'campaigns': state.campaigns,
        'new_features': state.newFeatures,
      }, onConflict: 'user_id');
    } catch (e) {
      if (kDebugMode) print('Error saving notification preferences: $e');
    }
  }

  Future<void> _updateField(String localKey, bool value,
      NotificationPreferencesState Function() newState) async {
    state = newState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(localKey, value);
    await _saveToSupabase();
  }

  Future<void> setPushEnabled(bool v) => _updateField(
      'notif_push', v, () => state.copyWith(pushEnabled: v));

  Future<void> setEmailEnabled(bool v) => _updateField(
      'notif_email', v, () => state.copyWith(emailEnabled: v));

  Future<void> setSmsEnabled(bool v) => _updateField(
      'notif_sms', v, () => state.copyWith(smsEnabled: v));

  Future<void> setOrderUpdates(bool v) => _updateField(
      'notif_order_updates', v, () => state.copyWith(orderUpdates: v));

  Future<void> setCampaigns(bool v) => _updateField(
      'notif_campaigns', v, () => state.copyWith(campaigns: v));

  Future<void> setNewFeatures(bool v) => _updateField(
      'notif_new_features', v, () => state.copyWith(newFeatures: v));
}

final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferencesState>(
  (ref) => NotificationPreferencesNotifier(),
);
