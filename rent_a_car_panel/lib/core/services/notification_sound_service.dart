import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationSoundService {
  static bool _audioInitialized = false;

  static void playSound() {
    if (!kIsWeb) return;
    try {
      _playWebSound();
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

  static void _playWebSound() {
    // Web-only: JS interop handled via conditional import
  }
}
