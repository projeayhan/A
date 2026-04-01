import 'package:audioplayers/audioplayers.dart';
import 'log_service.dart';

/// Bildirim sesi servisi - yeni siparis ve bildirim sesleri calar
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
      LogService.info('NotificationSoundService initialized', source: 'NotificationSoundService:initialize');
    } catch (e, st) {
      LogService.error('NotificationSoundService init error', error: e, stackTrace: st, source: 'NotificationSoundService:initialize');
    }
  }

  /// Yeni siparis sesi cal
  static void playOrderSound() {
    try {
      _orderPlayer.stop();
      _orderPlayer.play(AssetSource('sounds/order_notification.wav'));
    } catch (e, st) {
      LogService.error('Error playing order sound', error: e, stackTrace: st, source: 'NotificationSoundService:playOrderSound');
    }
  }

  /// Genel bildirim sesi cal
  static void playNotificationSound() {
    try {
      _generalPlayer.stop();
      _generalPlayer.play(AssetSource('sounds/notification.wav'));
    } catch (e, st) {
      LogService.error('Error playing notification sound', error: e, stackTrace: st, source: 'NotificationSoundService:playNotificationSound');
    }
  }
}

/// Global instance
final notificationSoundService = NotificationSoundService();
