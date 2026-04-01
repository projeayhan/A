import 'package:audioplayers/audioplayers.dart';
import 'package:merchant_panel/core/services/log_service.dart';

enum NotificationSoundType {
  order,
  message,
  general,
}

/// Bildirim sesi servisi - audioplayers ile gercek ses calar
class NotificationSoundService {
  static final NotificationSoundService _instance =
      NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  static final AudioPlayer _orderPlayer = AudioPlayer();
  static final AudioPlayer _messagePlayer = AudioPlayer();
  static final AudioPlayer _generalPlayer = AudioPlayer();
  static bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Set sources once (preload)
    try {
      await _orderPlayer.setSource(AssetSource('sounds/order_notification.wav'));
      await _messagePlayer
          .setSource(AssetSource('sounds/message_notification.wav'));
      await _generalPlayer.setSource(AssetSource('sounds/notification.wav'));
      LogService.error('NotificationSoundService initialized with audioplayers', source: 'notification_sound_service:initialize');
    } catch (e, st) {
      LogService.error('NotificationSoundService init error', error: e, stackTrace: st, source: 'notification_sound_service:initialize');
    }
  }

  /// Yeni siparis sesi cal
  void playNewOrderSound() {
    playSound(type: NotificationSoundType.order);
  }

  /// Mesaj sesi cal
  static void playMessageSound() {
    playSound(type: NotificationSoundType.message);
  }

  /// Ses cal - varsayilan genel bildirim sesi
  static void playSound({NotificationSoundType type = NotificationSoundType.general}) {
    try {
      switch (type) {
        case NotificationSoundType.order:
          _orderPlayer.stop();
          _orderPlayer.play(AssetSource('sounds/order_notification.wav'));
        case NotificationSoundType.message:
          _messagePlayer.stop();
          _messagePlayer.play(AssetSource('sounds/message_notification.wav'));
        case NotificationSoundType.general:
          _generalPlayer.stop();
          _generalPlayer.play(AssetSource('sounds/notification.wav'));
      }
    } catch (e, st) {
      LogService.error('Error playing notification sound', error: e, stackTrace: st, source: 'notification_sound_service:playSound');
    }
  }

  /// AudioContext baslatildi mi?
  static bool get isInitialized => _initialized;

  /// Sessizce AudioContext'i baslat (static method)
  static void initializeAudio() {
    if (!_initialized) {
      NotificationSoundService().initialize();
    }
  }
}

/// Global instance
final notificationSoundService = NotificationSoundService();
