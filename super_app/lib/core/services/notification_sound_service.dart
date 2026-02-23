import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Bildirim sesi servisi - siparis ve bildirim sesleri calar
class NotificationSoundService {
  static final NotificationSoundService _instance =
      NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  static final AudioPlayer _orderPlayer = AudioPlayer();
  static final AudioPlayer _generalPlayer = AudioPlayer();
  static bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _orderPlayer.setSource(AssetSource('sounds/order_notification.wav'));
      await _generalPlayer.setSource(AssetSource('sounds/notification.wav'));
      debugPrint('NotificationSoundService initialized');
    } catch (e) {
      debugPrint('NotificationSoundService init error: $e');
    }
  }

  /// Siparis durumu degistiginde ses cal
  static void playOrderSound() {
    try {
      _orderPlayer.stop();
      _orderPlayer.play(AssetSource('sounds/order_notification.wav'));
    } catch (e) {
      debugPrint('Error playing order sound: $e');
    }
  }

  /// Genel bildirim sesi cal
  static void playNotificationSound() {
    try {
      _generalPlayer.stop();
      _generalPlayer.play(AssetSource('sounds/notification.wav'));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }
}

/// Global instance
final notificationSoundService = NotificationSoundService();
