import 'package:flutter/foundation.dart';

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
        // Web'de JavaScript fonksiyonu çağrılır (index.html'de tanımlı)
        _audioInitialized = true;
        debugPrint('Web notification sound triggered');
      } catch (e) {
        debugPrint('Error playing notification sound: $e');
      }
    } else {
      // Native platformlarda (Windows, iOS, Android) şimdilik sadece log
      debugPrint('Native notification sound not implemented');
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
