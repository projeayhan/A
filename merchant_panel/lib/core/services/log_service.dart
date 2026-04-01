import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LogService {
  static const String appName = 'merchant_panel';
  static final _queue = Queue<Map<String, dynamic>>();
  static Timer? _flushTimer;
  static bool _flushing = false;

  static Future<void> error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    final detail = StringBuffer();
    if (error != null) detail.writeln(error.toString());
    if (stackTrace != null) detail.writeln(stackTrace.toString());
    _enqueue('error', message,
        source: source,
        errorDetail: detail.isNotEmpty ? detail.toString() : null,
        metadata: metadata);
  }

  static Future<void> warn(
    String message, {
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    _enqueue('warn', message, source: source, metadata: metadata);
  }

  static Future<void> info(
    String message, {
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    _enqueue('info', message, source: source, metadata: metadata);
  }

  static Future<void> debug(
    String message, {
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    if (kReleaseMode) return;
    _enqueue('debug', message, source: source, metadata: metadata);
  }

  static void _enqueue(
    String level,
    String message, {
    String? source,
    String? errorDetail,
    Map<String, dynamic>? metadata,
  }) {
    debugPrint('[$appName][$level] ${source ?? ''}: $message');
    if (errorDetail != null && !kReleaseMode) {
      debugPrint(errorDetail);
    }

    if (kReleaseMode && level != 'error' && level != 'warn') return;

    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}

    _queue.add({
      'app_name': appName,
      'level': level,
      'message': message.length > 2000 ? message.substring(0, 2000) : message,
      'source': source,
      'error_detail': errorDetail != null && errorDetail.length > 5000
          ? errorDetail.substring(0, 5000)
          : errorDetail,
      'user_id': userId,
      'metadata': metadata,
    });

    if (_queue.length >= 10) {
      _flush();
    } else {
      _flushTimer?.cancel();
      _flushTimer = Timer(const Duration(seconds: 5), _flush);
    }
  }

  static Future<void> _flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    _flushTimer?.cancel();

    final batch = <Map<String, dynamic>>[];
    while (_queue.isNotEmpty && batch.length < 50) {
      batch.add(_queue.removeFirst());
    }

    try {
      await Supabase.instance.client.from('app_logs').insert(batch);
    } catch (e) {
      debugPrint('[LogService] Failed to flush logs: $e');
    }
    _flushing = false;

    if (_queue.isNotEmpty) {
      _flushTimer = Timer(const Duration(seconds: 2), _flush);
    }
  }

  static Future<void> dispose() async {
    _flushTimer?.cancel();
    await _flush();
  }
}
