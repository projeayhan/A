import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}

/// Push Notification Service using Firebase Cloud Messaging
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  StreamController<Map<String, dynamic>>? _notificationController;
  String? _fcmToken;
  StreamSubscription? _tokenRefreshSubscription;
  StreamSubscription? _foregroundMessageSubscription;
  StreamSubscription? _messageOpenedSubscription;

  /// Stream of notification data when user taps on notification
  Stream<Map<String, dynamic>> get onNotificationTap {
    _notificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _notificationController!.stream;
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize the push notification service
  Future<void> initialize() async {
    // Web platformunda push notification desteklenmiyor
    if (kIsWeb) {
      debugPrint('Push notifications skipped on web platform');
      return;
    }

    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission
      await _requestPermission();

      // Initialize local notifications for foreground
      await _initializeLocalNotifications();

      // Get FCM token and save it
      await _getAndSaveToken();

      // Listen for token refresh
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(_saveTokenToSupabase);

      // Handle foreground messages
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background/terminated
      _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

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
      criticalAlert: false,
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

    // Create Android notification channel
    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        'super_app_notifications',
        'SuperCyp Bildirimleri',
        description: 'SuperCyp bildirim kanalı',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
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

  /// Save FCM token to Supabase
  Future<void> _saveTokenToSupabase(String token) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.client.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint('FCM token saved to Supabase');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Check if a notification type should be shown based on user preferences
  Future<bool> _shouldShowNotification(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final pushEnabled = prefs.getBool('notif_push') ?? true;
    if (!pushEnabled) return false;

    switch (type) {
      case 'order_update':
      case 'store_order':
        return prefs.getBool('notif_order_updates') ?? true;
      case 'campaign':
      case 'promotion':
        return prefs.getBool('notif_campaigns') ?? true;
      case 'new_feature':
      case 'update':
        return prefs.getBool('notif_new_features') ?? false;
      default:
        return true;
    }
  }

  /// Handle foreground message - show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // Get notification type for icon/color
    final type = message.data['type'] as String? ?? 'default';

    // Check user preferences before showing
    if (!await _shouldShowNotification(type)) {
      debugPrint('Notification suppressed by user preferences: $type');
      return;
    }

    final iconColor = _getNotificationColor(type);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'super_app_notifications',
          'SuperCyp Bildirimleri',
          channelDescription: 'SuperCyp bildirim kanalı',
          importance: Importance.high,
          priority: Priority.high,
          color: iconColor,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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

  /// Get notification color based on type
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'order_update':
        return const Color(0xFFFF6B35);
      case 'store_order':
        return const Color(0xFF10B981);
      case 'taxi_ride':
        return const Color(0xFFFFC107);
      case 'rental_reservation':
        return const Color(0xFF3B82F6);
      case 'job_application':
      case 'job_application_status':
        return const Color(0xFF8B5CF6);
      case 'car_message':
      case 'car_favorite':
        return const Color(0xFF06B6D4);
      case 'property_message':
      case 'property_favorite':
      case 'property_appointment':
        return const Color(0xFFEC4899);
      case 'welcome':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Delete FCM token (on logout)
  Future<void> deleteToken() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.client
          .from('fcm_tokens')
          .delete()
          .eq('user_id', userId);

      await _messaging.deleteToken();
      _fcmToken = null;

      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  /// Dispose
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _notificationController?.close();
    _notificationController = null;
  }
}

/// Global instance
final pushNotificationService = PushNotificationService();
