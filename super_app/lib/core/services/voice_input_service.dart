import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:super_app/core/services/log_service.dart';

/// Sesli giriş servisi (Speech-to-Text)
class VoiceInputService {
  static final VoiceInputService _instance = VoiceInputService._internal();
  factory VoiceInputService() => _instance;
  VoiceInputService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastError = '';

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastError => _lastError;

  /// Servisi başlat
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          LogService.error('STT Error: ${error.errorMsg}', source: 'VoiceInputService:initialize');
          _lastError = error.errorMsg;
          _isListening = false;
        },
        onStatus: (status) {
          LogService.info('STT Status: $status', source: 'VoiceInputService:initialize');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );
      LogService.info('STT initialized: $_isInitialized', source: 'VoiceInputService:initialize');
      if (!_isInitialized) {
        _lastError = 'Ses tanıma desteklenmiyor veya izin verilmedi';
      }
      return _isInitialized;
    } catch (e, st) {
      LogService.error('STT initialization error', error: e, stackTrace: st, source: 'VoiceInputService:initialize');
      _lastError = e.toString();
      return false;
    }
  }

  /// Dinlemeye başla
  Future<bool> startListening({
    required Function(String text, bool isFinal) onResult,
    VoidCallback? onDone,
    String locale = 'tr_TR',
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        LogService.error('STT: Failed to initialize, cannot listen', source: 'VoiceInputService:startListening');
        return false;
      }
    }

    // Önceki oturum hala aktifse önce durdur (Web'de race condition önlemi)
    if (_isListening || _speech.isListening) {
      try {
        await _speech.stop();
        _isListening = false;
        // Tarayıcının durmasını bekle
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e, st) {
        LogService.error('Error stopping previous listen', error: e, stackTrace: st, source: 'VoiceInputService:startListening');
      }
    }

    _isListening = true;
    _lastError = '';

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          LogService.info('STT Result: "${result.recognizedWords}" final=${result.finalResult}', source: 'VoiceInputService:startListening');
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            _isListening = false;
            onDone?.call();
          }
        },
        localeId: locale,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 30),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
      LogService.info('STT: Listening started', source: 'VoiceInputService:startListening');
      return true;
    } catch (e, st) {
      LogService.error('STT listen error', error: e, stackTrace: st, source: 'VoiceInputService:startListening');
      _lastError = e.toString();
      _isListening = false;
      return false;
    }
  }

  /// Dinlemeyi durdur
  Future<void> stopListening() async {
    if (!_isListening && !_speech.isListening) return;
    try {
      await _speech.stop();
    } catch (e, st) {
      LogService.error('STT stop error', error: e, stackTrace: st, source: 'VoiceInputService:stopListening');
    }
    _isListening = false;
  }

  /// Mevcut locale'leri getir
  Future<List<stt.LocaleName>> getLocales() async {
    if (!_isInitialized) await initialize();
    return _speech.locales();
  }
}

/// Global instance
final voiceInputService = VoiceInputService();
