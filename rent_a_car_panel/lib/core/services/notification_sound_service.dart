import 'dart:js_interop';

@JS('playNotificationSound')
external void _jsPlayNotificationSound();

class NotificationSoundService {
  static bool _audioInitialized = false;

  static void playSound() {
    try {
      _jsPlayNotificationSound();
      _audioInitialized = true;
    } catch (e) {
      // Ignore errors
    }
  }

  static bool get isInitialized => _audioInitialized;

  static void initializeAudio() {
    if (!_audioInitialized) {
      playSound();
    }
  }
}
