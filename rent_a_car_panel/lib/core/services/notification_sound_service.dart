import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rent_a_car_panel/core/services/log_service.dart';

class NotificationSoundService {
  static bool _audioInitialized = false;

  static void playSound() {
    if (!kIsWeb) return;
    try {
      _playWebSound();
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

  static void _playWebSound() {
    // Web-only: JS interop handled via conditional import
  }
}
