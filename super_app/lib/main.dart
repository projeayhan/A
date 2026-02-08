import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/theme/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'core/services/order_notification_service.dart';
import 'core/services/review_notification_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/providers/settings_provider.dart';
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

class _SuperAppState extends ConsumerState<SuperApp> {
  StreamSubscription<OrderStatusUpdate>? _orderNotificationSubscription;
  StreamSubscription<ReviewReplyUpdate>? _reviewNotificationSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize notification services after a short delay
    // to ensure user is logged in
    Future.delayed(const Duration(seconds: 2), () {
      _initializeNotifications();
      _checkActiveRide();
    });
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
      pushNotificationService.onNotificationTap.listen((data) {
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
      builder: (context) => _OrderNotificationWidget(
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
      builder: (context) => _ReviewReplyNotificationWidget(
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
    _orderNotificationSubscription?.cancel();
    _reviewNotificationSubscription?.cancel();
    pushNotificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Super App',
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
    );
  }
}

class _OrderNotificationWidget extends StatefulWidget {
  final OrderStatusUpdate update;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _OrderNotificationWidget({
    required this.update,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_OrderNotificationWidget> createState() =>
      _OrderNotificationWidgetState();
}

class _OrderNotificationWidgetState extends State<_OrderNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity!.abs() > 100) {
                widget.onDismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.update.statusColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.update.statusColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Status Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.update.statusColor,
                            widget.update.statusColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.update.statusIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.update.notificationTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.update.notificationBody,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Close button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Review Reply Notification Widget
class _ReviewReplyNotificationWidget extends StatefulWidget {
  final ReviewReplyUpdate update;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _ReviewReplyNotificationWidget({
    required this.update,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_ReviewReplyNotificationWidget> createState() =>
      _ReviewReplyNotificationWidgetState();
}

class _ReviewReplyNotificationWidgetState
    extends State<_ReviewReplyNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity!.abs() > 100) {
                widget.onDismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.update.color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.update.color.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.update.color,
                            widget.update.color.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.update.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.update.notificationTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.update.notificationBody,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Close button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

