import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:merchant_panel/core/services/log_service.dart';

/// Sesli çıkış servisi (OpenAI TTS via Edge Function)
class VoiceOutputService {
  static final VoiceOutputService _instance = VoiceOutputService._internal();
  factory VoiceOutputService() => _instance;
  VoiceOutputService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isEnabled = false;
  VoidCallback? _onComplete;

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isEnabled => _isEnabled;

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Ses seviyesini maksimuma ayarla
      await _player.setVolume(1.0);

      _player.onPlayerComplete.listen((_) {
        _isSpeaking = false;
        _onComplete?.call();
        _onComplete = null;
      });

      _player.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.playing) {
          _isSpeaking = true;
        } else if (state == PlayerState.stopped ||
            state == PlayerState.completed) {
          _isSpeaking = false;
        }
      });

      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('tts_enabled') ?? false;

      _isInitialized = true;
      LogService.error('OpenAI TTS initialized, enabled: $_isEnabled', source: 'voice_output_service:initialize');
    } catch (e, st) {
      LogService.error('TTS initialization error', error: e, stackTrace: st, source: 'voice_output_service:initialize');
    }
  }

  /// Get a valid access token
  Future<String?> _getValidAccessToken() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (DateTime.now().isAfter(
        expiryTime.subtract(const Duration(seconds: 30)),
      )) {
        try {
          final refreshed = await client.auth.refreshSession();
          return refreshed.session?.accessToken;
        } catch (_) {
          return null;
        }
      }
    }

    return session.accessToken;
  }

  /// Metni OpenAI TTS ile seslendir
  Future<void> speak(String text, {VoidCallback? onComplete}) async {
    if (!_isInitialized || !_isEnabled) {
      onComplete?.call();
      return;
    }
    if (text.isEmpty) {
      onComplete?.call();
      return;
    }

    _onComplete = onComplete;

    try {
      if (_isSpeaking) {
        await _player.stop();
      }

      final token = await _getValidAccessToken();
      if (token == null) {
        LogService.error('TTS: No valid token', source: 'voice_output_service:speak');
        _onComplete?.call();
        _onComplete = null;
        return;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'ai-tts',
        body: {'text': text, 'voice': 'nova'},
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.status != 200) {
        LogService.error('TTS edge function error: ${response.status}', source: 'voice_output_service:speak');
        _onComplete?.call();
        _onComplete = null;
        return;
      }

      final data = response.data;
      if (data == null || data['success'] != true || data['audio'] == null) {
        LogService.error('TTS: No audio in response', source: 'voice_output_service:speak');
        _onComplete?.call();
        _onComplete = null;
        return;
      }

      final audioBase64 = data['audio'] as String;
      final Uint8List audioBytes = base64Decode(audioBase64);

      _isSpeaking = true;
      await _player.play(BytesSource(audioBytes));
    } catch (e, st) {
      LogService.error('OpenAI TTS error', error: e, stackTrace: st, source: 'voice_output_service:speak');
      _isSpeaking = false;
      _onComplete?.call();
      _onComplete = null;
    }
  }

  /// Base64 encoded audio'yu doğrudan çal (inline TTS için)
  Future<void> playBase64Audio(
    String audioBase64, {
    VoidCallback? onComplete,
  }) async {
    if (!_isInitialized) {
      onComplete?.call();
      return;
    }

    _onComplete = onComplete;

    try {
      if (_isSpeaking) {
        await _player.stop();
      }

      final Uint8List audioBytes = base64Decode(audioBase64);
      _isSpeaking = true;
      await _player.play(BytesSource(audioBytes));
    } catch (e, st) {
      LogService.error('Play base64 audio error', error: e, stackTrace: st, source: 'voice_output_service:playBase64Audio');
      _isSpeaking = false;
      _onComplete?.call();
      _onComplete = null;
    }
  }

  /// Konuşmayı durdur
  Future<void> stop() async {
    try {
      await _player.stop();
      _isSpeaking = false;
      _onComplete = null;
    } catch (e, st) {
      LogService.error('TTS stop error', error: e, stackTrace: st, source: 'voice_output_service:stop');
    }
  }

  /// Ses açma/kapama
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!enabled) await stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_enabled', enabled);
  }
}

/// Global instance
final voiceOutputService = VoiceOutputService();
