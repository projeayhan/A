import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import 'core/theme/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'core/services/order_notification_service.dart';
import 'core/services/review_notification_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'widgets/notification_overlays.dart';
import 'models/taxi/taxi_models.dart';
import 'core/services/taxi_service.dart';
import 'screens/taxi/taxi_ride_screen.dart';
import 'screens/taxi/taxi_searching_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize date formatting for Turkish locale
  await initializeDateFormatting('tr', null);

  // Initialize Firebase (skip on web if no options configured)
  try {
    if (kIsWeb) {
      // Web için firebase_options.dart gerekli - yoksa atla
      debugPrint('Firebase web initialization skipped - run "flutterfire configure" to enable');
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: SuperApp()));
}

class SuperApp extends ConsumerStatefulWidget {
  const SuperApp({super.key});

  @override
  ConsumerState<SuperApp> createState() => _SuperAppState();
}

class _SuperAppState extends ConsumerState<SuperApp> with WidgetsBindingObserver {
  StreamSubscription<OrderStatusUpdate>? _orderNotificationSubscription;
  StreamSubscription<ReviewReplyUpdate>? _reviewNotificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _pushNotificationTapSubscription;

  bool _isLocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize after first frame to ensure widget tree is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
      _checkActiveRide();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (ref.read(settingsProvider).biometricLogin) {
        setState(() => _isLocked = true);
      }
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      _authenticateBiometric();
    }
  }

  Future<void> _authenticateBiometric() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      final auth = LocalAuthentication();
      final authenticated = await auth.authenticate(
        localizedReason: 'Uygulamaya erişmek için kimliğinizi doğrulayın',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (authenticated && mounted) {
        setState(() => _isLocked = false);
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> _checkActiveRide() async {
    if (!SupabaseService.isLoggedIn) return;

    try {
      final rideData = await TaxiService.getActiveRide();
      if (rideData != null) {
        final ride = TaxiRide.fromJson(rideData);
        final context = rootNavigatorKey.currentContext;

        if (context != null && mounted) {
          if (ride.status == RideStatus.pending && ride.vehicleTypeId != null) {
            // Fetch vehicle types to find the correct one
            try {
              final vehicleTypes = await TaxiService.getVehicleTypes();
              final vehicleTypeData = vehicleTypes.firstWhere(
                (v) => v['id'] == ride.vehicleTypeId,
                orElse: () => vehicleTypes.first,
              );
              final vehicleType = VehicleType.fromJson(vehicleTypeData);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaxiSearchingScreen(
                    pickup: ride.pickup,
                    dropoff: ride.dropoff,
                    vehicleType: vehicleType,
                    fare: ride.fare,
                    distanceKm: ride.distanceKm,
                    durationMinutes: ride.durationMinutes,
                    existingRide: ride,
                  ),
                ),
              );
            } catch (e) {
              debugPrint('Error restoring search screen: $e');
            }
          } else if (ride.status != RideStatus.completed &&
              ride.status != RideStatus.cancelled) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TaxiRideScreen(ride: ride)),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking active ride: $e');
    }
  }

  void _initializeNotifications() {
    if (SupabaseService.currentUser != null) {
      // Initialize push notifications (Firebase)
      _initializePushNotifications();

      // Initialize order notifications
      orderNotificationService.initialize();
      _orderNotificationSubscription = orderNotificationService.statusUpdates
          .listen(_showOrderNotification);

      // Initialize review reply notifications
      reviewNotificationService.initialize();
      _reviewNotificationSubscription = reviewNotificationService.replyUpdates
          .listen(_showReviewReplyNotification);
    }
  }

  Future<void> _initializePushNotifications() async {
    try {
      await pushNotificationService.initialize();

      // Listen for notification taps and navigate
      _pushNotificationTapSubscription = pushNotificationService.onNotificationTap.listen((data) {
        _handlePushNotificationTap(data);
      });
    } catch (e) {
      debugPrint('Error initializing push notifications: $e');
    }
  }

  void _handlePushNotificationTap(Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final type = data['type'] as String?;

    switch (type) {
      case 'order_update':
      case 'store_order':
        final orderId = data['order_id'] as String?;
        if (orderId != null) {
          router.push('/food/order-tracking/$orderId');
        }
        break;
      case 'taxi_ride':
        router.push('/taxi');
        break;
      case 'job_application':
      case 'job_application_status':
        final jobId = data['job_id'] as String?;
        if (jobId != null) {
          router.push('/jobs/detail/$jobId');
        }
        break;
      case 'car_message':
      case 'car_favorite':
        final listingId = data['listing_id'] as String?;
        if (listingId != null) {
          router.push('/car-sales/detail/$listingId');
        }
        break;
      case 'property_message':
      case 'property_favorite':
      case 'property_appointment':
        final propertyId = data['property_id'] as String?;
        if (propertyId != null) {
          router.push('/emlak/property/$propertyId');
        }
        break;
      case 'rental_reservation':
        router.push('/rental/my-bookings');
        break;
      case 'ride_message':
        // Sürücüden mesaj geldiğinde taksi ekranına git
        router.push('/taxi');
        break;
      default:
        // Open notifications screen
        router.push('/notifications');
    }
  }

  void _showOrderNotification(OrderStatusUpdate update) {
    // Show in-app notification
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      _showOrderNotificationOverlay(context, update);
    }
  }

  void _showReviewReplyNotification(ReviewReplyUpdate update) {
    // Show in-app notification for merchant reply
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      _showReviewReplyOverlay(context, update);
    }
  }

  void _showOrderNotificationOverlay(
    BuildContext context,
    OrderStatusUpdate update,
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => OrderNotificationWidget(
        update: update,
        onDismiss: () => entry.remove(),
        onTap: () {
          entry.remove();
          // Navigate to order tracking
          final router = ref.read(routerProvider);
          router.push('/food/order-tracking/${update.orderId}');
        },
      ),
    );

    overlay.insert(entry);

    // Auto dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  void _showReviewReplyOverlay(BuildContext context, ReviewReplyUpdate update) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => ReviewReplyNotificationWidget(
        update: update,
        onDismiss: () => entry.remove(),
        onTap: () {
          entry.remove();
          // Navigate to orders screen to see reviews
          final router = ref.read(routerProvider);
          router.push('/orders-main');
        },
      ),
    );

    overlay.insert(entry);

    // Auto dismiss after 6 seconds (slightly longer for review replies)
    Future.delayed(const Duration(seconds: 6), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orderNotificationSubscription?.cancel();
    _reviewNotificationSubscription?.cancel();
    _pushNotificationTapSubscription?.cancel();
    pushNotificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'SuperCyp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      locale: settings.locale,
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (_isLocked) _buildLockScreen(context),
          ],
        );
      },
    );
  }

  Widget _buildLockScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Material(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF60A5FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 32),
              Text(
                'Uygulama Kilitli',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Devam etmek için kimliğinizi doğrulayın',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _authenticateBiometric,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Kilidi Aç',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

