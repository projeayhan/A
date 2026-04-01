import 'dart:js_interop';
import 'package:arac_satis_panel/core/services/log_service.dart';

@JS('playNotificationSound')
external void _jsPlayNotificationSound();

class NotificationSoundService {
  static bool _audioInitialized = false;

  static void playSound() {
    try {
      _jsPlayNotificationSound();
      _audioInitialized = true;
    } catch (e, st) {
      LogService.error('Notification sound failed', error: e, stackTrace: st, source: 'NotificationSoundService:playSound');
    }
  }

  static bool get isInitialized => _audioInitialized;

  static void initializeAudio() {
    if (!_audioInitialized) {
      playSound();
    }
  }
}
