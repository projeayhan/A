import 'dart:js_interop';
import 'package:flutter/foundation.dart';

/// JavaScript fonksiyonu çağırma
@JS('playNotificationSound')
external void _jsPlayNotificationSound();

/// Bildirim sesi servisi
class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  static bool _audioInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    debugPrint('NotificationSoundService initialized');
  }

  /// Yeni sipariş sesi çal
  void playNewOrderSound() {
    playSound();
  }

  /// AudioContext'i başlat ve ses çal
  static void playSound() {
    if (kIsWeb) {
      try {
        _jsPlayNotificationSound();
        _audioInitialized = true;
      } catch (e) {
        debugPrint('Error playing notification sound: $e');
      }
    }
  }

  /// AudioContext başlatıldı mı?
  static bool get isInitialized => _audioInitialized;

  /// Sessizce AudioContext'i başlat (static method)
  static void initializeAudio() {
    if (!_audioInitialized && kIsWeb) {
      playSound();
    }
  }
}

/// Global instance
final notificationSoundService = NotificationSoundService();
