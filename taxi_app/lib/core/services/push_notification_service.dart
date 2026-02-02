import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}

/// Push Notification Service for Taxi Driver App
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  StreamController<Map<String, dynamic>>? _notificationController;
  String? _fcmToken;

  /// Stream of notification data when user taps on notification
  Stream<Map<String, dynamic>> get onNotificationTap {
    _notificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _notificationController!.stream;
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize the push notification service
  Future<void> initialize() async {
    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request permission
      await _requestPermission();

      // Initialize local notifications for foreground
      await _initializeLocalNotifications();

      // Get FCM token and save it
      await _getAndSaveToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveTokenToSupabase);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      debugPrint('Push notification service initialized');
    } catch (e) {
      debugPrint('Error initializing push notifications: $e');
    }
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true, // Critical for driver app (ride requests)
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _notificationController?.add(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // High priority channel for ride requests
      const rideChannel = AndroidNotificationChannel(
        'taxi_ride_requests',
        'Yolculuk Talepleri',
        description: 'Yeni yolculuk talepleri',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        // Uses default system notification sound
      );

      // Normal channel for messages
      const messageChannel = AndroidNotificationChannel(
        'taxi_messages',
        'Mesajlar',
        description: 'Musteri mesajlari',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // General channel
      const generalChannel = AndroidNotificationChannel(
        'taxi_general',
        'Genel Bildirimler',
        description: 'Diger bildirimler',
        importance: Importance.defaultImportance,
      );

      await androidPlugin?.createNotificationChannel(rideChannel);
      await androidPlugin?.createNotificationChannel(messageChannel);
      await androidPlugin?.createNotificationChannel(generalChannel);
    }
  }

  /// Get FCM token and save to Supabase
  Future<void> _getAndSaveToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        await _saveTokenToSupabase(_fcmToken!);
        debugPrint('FCM Token: $_fcmToken');
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Save FCM token to Supabase (driver tokens table)
  Future<void> _saveTokenToSupabase(String token) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      // Get driver ID for current user
      final driverResult = await SupabaseService.client
          .from('taxi_drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (driverResult != null) {
        final driverId = driverResult['id'] as String;

        // Save to driver_fcm_tokens table
        await SupabaseService.client.from('driver_fcm_tokens').upsert({
          'driver_id': driverId,
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'driver_id');

        debugPrint('Driver FCM token saved to Supabase');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Handle foreground message - show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // Get notification type for channel selection
    final type = message.data['type'] as String? ?? 'general';
    final channelId = _getChannelId(type);
    final iconColor = _getNotificationColor(type);
    final priority = type == 'new_ride' ? Priority.max : Priority.high;
    final importance = type == 'new_ride' ? Importance.max : Importance.high;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _getChannelName(type),
          channelDescription: 'Taksi surucu bildirimleri',
          importance: importance,
          priority: priority,
          color: iconColor,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          fullScreenIntent: type == 'new_ride', // Full screen for ride requests
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: type == 'new_ride'
              ? InterruptionLevel.critical
              : InterruptionLevel.active,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    _notificationController?.add(message.data);
  }

  /// Get channel ID based on notification type
  String _getChannelId(String type) {
    switch (type) {
      case 'new_ride':
      case 'ride_cancelled':
        return 'taxi_ride_requests';
      case 'message':
      case 'new_message':
        return 'taxi_messages';
      default:
        return 'taxi_general';
    }
  }

  /// Get channel name based on notification type
  String _getChannelName(String type) {
    switch (type) {
      case 'new_ride':
      case 'ride_cancelled':
        return 'Yolculuk Talepleri';
      case 'message':
      case 'new_message':
        return 'Mesajlar';
      default:
        return 'Genel Bildirimler';
    }
  }

  /// Get notification color based on type
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_ride':
        return const Color(0xFFFFC107); // Amber - new ride
      case 'ride_cancelled':
        return const Color(0xFFEF4444); // Red - cancelled
      case 'message':
      case 'new_message':
        return const Color(0xFF3B82F6); // Blue - message
      case 'rating':
        return const Color(0xFF10B981); // Green - rating
      default:
        return const Color(0xFF6B7280); // Gray - default
    }
  }

  /// Delete FCM token (on logout)
  Future<void> deleteToken() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      // Get driver ID
      final driverResult = await SupabaseService.client
          .from('taxi_drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (driverResult != null) {
        final driverId = driverResult['id'] as String;

        await SupabaseService.client
            .from('driver_fcm_tokens')
            .delete()
            .eq('driver_id', driverId);
      }

      await _messaging.deleteToken();
      _fcmToken = null;

      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  /// Dispose
  void dispose() {
    _notificationController?.close();
    _notificationController = null;
  }
}

/// Global instance
final pushNotificationService = PushNotificationService();
