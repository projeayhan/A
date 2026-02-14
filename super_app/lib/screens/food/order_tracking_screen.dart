import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_dialogs.dart';
import '../../core/theme/app_responsive.dart';
import 'food_home_screen.dart';

// Order tracking provider
final orderTrackingProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, orderId) {
  return SupabaseService.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('id', orderId)
      .map((data) => data.isNotEmpty ? data.first : null);
});

// Courier location provider (simulated real-time)
final courierLocationProvider = StateNotifierProvider.family<CourierLocationNotifier, LatLng?, String>(
  (ref, orderId) => CourierLocationNotifier(),
);

class CourierLocationNotifier extends StateNotifier<LatLng?> {
  CourierLocationNotifier() : super(null);

  void updateLocation(LatLng location) {
    state = location;
  }
}

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  // Google Maps
  GoogleMapController? _mapController;

  // Locations - will be updated from order data
  LatLng _restaurantLocation = const LatLng(41.0821, 29.0108);
  LatLng _deliveryLocation = const LatLng(41.0855, 29.0175);
  LatLng _courierLocation = const LatLng(41.0835, 29.0135);

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _courierTimer;
  Timer? _statusCheckTimer;

  // Real-time subscription
  RealtimeChannel? _orderChannel;

  // Order data
  Map<String, dynamic>? _orderData;
  String _currentStatus = 'pending';
  String? _previousStatus;

  // Unread messages
  int _unreadMessageCount = 0;
  RealtimeChannel? _messagesChannel;

  // Chat modal açık mı?
  bool _isChatOpen = false;

  // Navigation guard - çift navigasyon engelle
  bool _isNavigating = false;

  /// Mesaj gönderilebilir mi? Sipariş iptal/teslim edildiyse 10dk sonra kapanır.
  bool get _canSendMessage {
    if (_currentStatus == 'cancelled') return false;
    if (_currentStatus == 'delivered') {
      final deliveredAt = _orderData?['delivered_at'] as String?;
      if (deliveredAt != null) {
        final deliveredTime = DateTime.tryParse(deliveredAt);
        if (deliveredTime != null) {
          return DateTime.now().difference(deliveredTime).inMinutes < 10;
        }
      }
      // delivered_at yoksa updated_at'e bak
      final updatedAt = _orderData?['updated_at'] as String?;
      if (updatedAt != null) {
        final updatedTime = DateTime.tryParse(updatedAt);
        if (updatedTime != null) {
          return DateTime.now().difference(updatedTime).inMinutes < 10;
        }
      }
      return false;
    }
    return true; // pending, confirmed, preparing, ready, delivering
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _loadOrderData();
    _setupRealtimeSubscription();
    _setupMessagesSubscription();
    _loadUnreadMessageCount();
    _startPolling(); // Fallback polling mechanism
  }

  Future<void> _loadUnreadMessageCount() async {
    try {
      final response = await SupabaseService.client
          .from('order_messages')
          .select('id')
          .eq('order_id', widget.orderId)
          .eq('sender_type', 'merchant')
          .eq('is_read', false);

      if (mounted) {
        setState(() {
          _unreadMessageCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread messages: $e');
    }
  }

  void _setupMessagesSubscription() {
    _messagesChannel = SupabaseService.client
        .channel('customer_new_messages_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (payload) {
            // Yeni mesaj restorandan mı?
            if (payload.newRecord['sender_type'] == 'merchant') {
              if (mounted) {
                setState(() {
                  _unreadMessageCount++;
                });
                // Bildirim göster
                _showNewMessageNotification(payload.newRecord);
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _showLocalNotification(String title, String body) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Mesajlar',
      channelDescription: 'Restoran mesaj bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }

  void _showNewMessageNotification(Map<String, dynamic> message) {
    // Chat açıksa bildirim gösterme
    if (_isChatOpen) return;

    final senderName = message['sender_name'] ?? 'Restoran';
    final messageText = message['message'] ?? '';

    // Sesli local notification göster
    _showLocalNotification('$senderName mesaj gönderdi', messageText);

    // Önce mevcut SnackBar'ı kapat
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$senderName mesaj gönderdi',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    messageText.length > 40 ? '${messageText.substring(0, 40)}...' : messageText,
                    style: TextStyle(fontSize: context.captionSize),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: FoodColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Görüntüle',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _showSupportDialog(Theme.of(context).brightness == Brightness.dark);
          },
        ),
      ),
    );
  }

  // Polling mechanism as fallback if realtime doesn't work
  void _startPolling() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkStatusUpdate();
    });
  }

  Future<void> _checkStatusUpdate() async {
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('status, estimated_delivery_time')
          .eq('id', widget.orderId)
          .single();

      final newStatus = response['status'] as String?;
      if (mounted && newStatus != null && newStatus != _currentStatus) {
        debugPrint('Polling detected status change: $_currentStatus -> $newStatus');
        _previousStatus = _currentStatus;
        setState(() {
          _currentStatus = newStatus;
          if (_orderData != null) {
            _orderData = {..._orderData!, ...response};
          }
        });

        _showStatusChangeNotification(newStatus);

        if (newStatus == 'delivering') {
          _startCourierAnimation();
        }

        _updateMarkers();
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  Future<void> _loadOrderData() async {
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('*, merchants(*)')
          .eq('id', widget.orderId)
          .single();

      if (mounted) {
        setState(() {
          _orderData = response;
          _currentStatus = response['status'] ?? 'pending';

          // Get delivery address coordinates
          if (response['delivery_latitude'] != null && response['delivery_longitude'] != null) {
            _deliveryLocation = LatLng(
              (response['delivery_latitude'] as num).toDouble(),
              (response['delivery_longitude'] as num).toDouble(),
            );
          }

          // Get merchant coordinates
          final merchant = response['merchants'];
          if (merchant != null && merchant['latitude'] != null && merchant['longitude'] != null) {
            _restaurantLocation = LatLng(
              (merchant['latitude'] as num).toDouble(),
              (merchant['longitude'] as num).toDouble(),
            );
          }
        });

        _initializeMap();

        // Start courier animation if order is being delivered
        if (_currentStatus == 'delivering' || _currentStatus == 'ready') {
          _startCourierAnimation();
        }
      }
    } catch (e) {
      debugPrint('Error loading order data: $e');
    }
  }

  void _setupRealtimeSubscription() {
    debugPrint('Setting up realtime subscription for order: ${widget.orderId}');

    _orderChannel = SupabaseService.client
        .channel('order_tracking_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            debugPrint('Order tracking received update: ${payload.newRecord}');
            final newRecord = payload.newRecord;

            // Client-side filter - check if this update is for our order
            final recordId = newRecord['id'] as String?;
            if (recordId != widget.orderId) {
              debugPrint('Ignoring update for different order: $recordId');
              return;
            }

            if (mounted && newRecord.isNotEmpty) {
              final newStatus = newRecord['status'] as String?;
              debugPrint('New status: $newStatus, Current status: $_currentStatus');
              if (newStatus != null && newStatus != _currentStatus) {
                _previousStatus = _currentStatus;
                setState(() {
                  _currentStatus = newStatus;
                  _orderData = {...?_orderData, ...newRecord};
                });

                // Show notification for status change
                _showStatusChangeNotification(newStatus);

                // Start courier animation when delivering
                if (newStatus == 'delivering') {
                  _startCourierAnimation();
                }

                // Update markers
                _updateMarkers();
              }
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Realtime subscription status: $status, error: $error');
        });
  }

  void _showStatusChangeNotification(String newStatus) {
    final statusInfo = _getStatusInfo(newStatus);

    if (mounted) {
      // Önce mevcut SnackBar'ı kapat
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(statusInfo['icon'] as IconData, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusInfo['notification'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: FoodColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'title': 'Sipariş Alındı',
          'subtitle': 'Siparişiniz restorana iletildi',
          'icon': Icons.receipt_long,
          'notification': 'Siparişiniz alındı ve restorana iletildi!',
          'color': const Color(0xFFF59E0B),
        };
      case 'confirmed':
        return {
          'title': 'Onaylandı',
          'subtitle': 'Restoran siparişinizi onayladı',
          'icon': Icons.check_circle,
          'notification': 'Siparişiniz restoran tarafından onaylandı!',
          'color': const Color(0xFF3B82F6),
        };
      case 'preparing':
        return {
          'title': 'Hazırlanıyor',
          'subtitle': 'Siparişiniz hazırlanıyor',
          'icon': Icons.restaurant,
          'notification': 'Siparişiniz hazırlanmaya başlandı!',
          'color': const Color(0xFF8B5CF6),
        };
      case 'ready':
        return {
          'title': 'Hazır',
          'subtitle': 'Siparişiniz kurye bekliyor',
          'icon': Icons.check_box,
          'notification': 'Siparişiniz hazır, kurye yola çıkıyor!',
          'color': const Color(0xFF10B981),
        };
      case 'delivering':
        return {
          'title': 'Yolda',
          'subtitle': 'Kurye siparişinizi teslim alıyor',
          'icon': Icons.delivery_dining,
          'notification': 'Kurye siparişinizi aldı ve yola çıktı!',
          'color': const Color(0xFF06B6D4),
        };
      case 'delivered':
        return {
          'title': 'Teslim Edildi',
          'subtitle': 'Afiyet olsun!',
          'icon': Icons.check_circle,
          'notification': 'Siparişiniz teslim edildi. Afiyet olsun!',
          'color': const Color(0xFF22C55E),
        };
      case 'cancelled':
        return {
          'title': 'İptal Edildi',
          'subtitle': 'Siparişiniz iptal edildi',
          'icon': Icons.cancel,
          'notification': 'Siparişiniz iptal edildi.',
          'color': const Color(0xFFEF4444),
        };
      default:
        return {
          'title': 'Beklemede',
          'subtitle': 'İşlem bekleniyor',
          'icon': Icons.hourglass_empty,
          'notification': 'Sipariş durumu güncellendi',
          'color': Colors.grey,
        };
    }
  }

  int _getStatusStep(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'confirmed':
        return 1;
      case 'preparing':
        return 2;
      case 'ready':
        return 3;
      case 'delivering':
        return 4;
      case 'delivered':
        return 5;
      default:
        return 0;
    }
  }

  void _initializeMap() {
    _updateMarkers();
    _createRoute();
  }

  void _updateMarkers() {
    final currentStep = _getStatusStep(_currentStatus);

    setState(() {
      _markers = {
        // Restoran marker
        Marker(
          markerId: const MarkerId('restaurant'),
          position: _restaurantLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: _orderData?['merchants']?['business_name'] ?? 'Restoran',
            snippet: 'Restoran',
          ),
        ),
        // Teslimat adresi marker
        Marker(
          markerId: const MarkerId('delivery'),
          position: _deliveryLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Teslimat Adresi',
            snippet: _orderData?['delivery_address'] ?? 'Ev',
          ),
        ),
        // Kurye marker (sadece yolda ise)
        if (currentStep >= 4)
          Marker(
            markerId: const MarkerId('courier'),
            position: _courierLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: 'Kurye',
              snippet: _orderData?['courier_name'] ?? 'Kurye',
            ),
          ),
      };
    });
  }

  void _createRoute() {
    // Create route polyline between restaurant and delivery
    final midPoint1 = LatLng(
      (_restaurantLocation.latitude + _deliveryLocation.latitude) / 2,
      _restaurantLocation.longitude,
    );
    final midPoint2 = LatLng(
      (_restaurantLocation.latitude + _deliveryLocation.latitude) / 2,
      _deliveryLocation.longitude,
    );

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            _restaurantLocation,
            midPoint1,
            midPoint2,
            _deliveryLocation,
          ],
          color: FoodColors.primary,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });
  }

  void _startCourierAnimation() {
    _courierTimer?.cancel();

    // Start from restaurant location
    _courierLocation = _restaurantLocation;

    int step = 0;
    final routePoints = [
      _restaurantLocation,
      LatLng(
        _restaurantLocation.latitude + (_deliveryLocation.latitude - _restaurantLocation.latitude) * 0.25,
        _restaurantLocation.longitude + (_deliveryLocation.longitude - _restaurantLocation.longitude) * 0.25,
      ),
      LatLng(
        _restaurantLocation.latitude + (_deliveryLocation.latitude - _restaurantLocation.latitude) * 0.5,
        _restaurantLocation.longitude + (_deliveryLocation.longitude - _restaurantLocation.longitude) * 0.5,
      ),
      LatLng(
        _restaurantLocation.latitude + (_deliveryLocation.latitude - _restaurantLocation.latitude) * 0.75,
        _restaurantLocation.longitude + (_deliveryLocation.longitude - _restaurantLocation.longitude) * 0.75,
      ),
      _deliveryLocation,
    ];

    _courierTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (step < routePoints.length - 1 && mounted) {
        step++;
        setState(() {
          _courierLocation = routePoints[step];
        });
        _updateMarkers();

        // Center camera on courier
        _mapController?.animateCamera(CameraUpdate.newLatLng(_courierLocation));
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void deactivate() {
    _pulseController.stop();
    _courierTimer?.cancel();
    _courierTimer = null;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
    super.deactivate();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    _orderChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FoodColors.backgroundDark : FoodColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _orderData == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.all(context.pagePaddingH),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Map
                        _buildMapSection(isDark),
                        const SizedBox(height: 24),
                        // Order status
                        _buildOrderStatus(isDark),
                        const SizedBox(height: 24),
                        // Progress steps
                        _buildProgressSteps(isDark),
                        const SizedBox(height: 24),
                        // Courier info
                        if (_getStatusStep(_currentStatus) >= 4)
                          _buildCourierInfo(isDark),
                        if (_getStatusStep(_currentStatus) >= 4)
                          const SizedBox(height: 24),
                        // Order details
                        _buildOrderDetails(isDark),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
          ),
          // Bottom actions
          _buildBottomActions(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: context.pagePaddingH,
        right: context.pagePaddingH,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.backgroundDark : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (_isNavigating) return;
              _isNavigating = true;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/food');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
          Column(
            children: [
              Text(
                'Sipariş Takibi',
                style: TextStyle(
                  fontSize: context.heading2Size,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              Text(
                '#${_orderData?['order_number'] ?? widget.orderId.substring(0, 8)}',
                style: TextStyle(
                  fontSize: context.captionSize,
                  color: FoodColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _showHelpDialog(isDark),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(bool isDark) {
    // Check if running on Windows (maps not supported)
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'Harita mobil cihazda görüntülenir',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: context.bodySize,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kurye konumu: ${_getStatusStep(_currentStatus) >= 4 ? "Yolda" : "Restoranda"}',
                style: TextStyle(
                  color: FoodColors.primary,
                  fontSize: context.captionSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _getStatusStep(_currentStatus) >= 4
                    ? _courierLocation
                    : _restaurantLocation,
                zoom: 15,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                if (isDark) {
                  _mapController?.setMapStyle(_darkMapStyle);
                }
              },
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
            // Zoom controls
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                children: [
                  _buildMapButton(Icons.add, () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  }, isDark),
                  const SizedBox(height: 8),
                  _buildMapButton(Icons.remove, () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  }, isDark),
                ],
              ),
            ),
            // Follow courier button
            if (_getStatusStep(_currentStatus) >= 4)
              Positioned(
                left: 12,
                bottom: 12,
                child: _buildMapButton(Icons.my_location, () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(_courierLocation),
                  );
                }, isDark),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  static const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]}
]
''';

  Widget _buildOrderStatus(bool isDark) {
    final statusInfo = _getStatusInfo(_currentStatus);
    final estimatedTime = _getStatusStep(_currentStatus) < 4 ? '25-35 dk' : '15-20 dk';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusInfo['color'] as Color, (statusInfo['color'] as Color).withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (statusInfo['color'] as Color).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.1);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusInfo['icon'] as IconData,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo['title'] as String,
                  style: TextStyle(
                    fontSize: context.heading1Size,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusInfo['subtitle'] as String,
                  style: TextStyle(
                    fontSize: context.bodySize,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (_currentStatus != 'delivered' && _currentStatus != 'cancelled')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    estimatedTime,
                    style: TextStyle(
                      fontSize: context.captionSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps(bool isDark) {
    final steps = [
      {'status': 'pending', 'title': 'Sipariş Alındı', 'subtitle': 'Siparişiniz restorana iletildi'},
      {'status': 'confirmed', 'title': 'Onaylandı', 'subtitle': 'Restoran siparişinizi onayladı'},
      {'status': 'preparing', 'title': 'Hazırlanıyor', 'subtitle': 'Siparişiniz hazırlanıyor'},
      {'status': 'ready', 'title': 'Hazır', 'subtitle': 'Kurye bekliyor'},
      {'status': 'delivering', 'title': 'Yolda', 'subtitle': 'Kurye yola çıktı'},
      {'status': 'delivered', 'title': 'Teslim Edildi', 'subtitle': 'Afiyet olsun!'},
    ];

    final currentStepIndex = _getStatusStep(_currentStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        ),
      ),
      child: Column(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final stepInfo = _getStatusInfo(step['status']!);
          final isCompleted = index < currentStepIndex;
          final isCurrent = index == currentStepIndex;
          final isLast = index == steps.length - 1;

          return Column(
            children: [
              Row(
                children: [
                  // Step indicator
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent
                              ? (isCurrent ? stepInfo['color'] as Color : const Color(0xFF22C55E))
                              : (isDark ? Colors.grey[700] : Colors.grey[200]),
                          shape: BoxShape.circle,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: (stepInfo['color'] as Color).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : stepInfo['icon'] as IconData,
                          color: isCompleted || isCurrent
                              ? Colors.white
                              : (isDark ? Colors.grey[500] : Colors.grey[400]),
                          size: 20,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 32,
                          color: isCompleted
                              ? const Color(0xFF22C55E)
                              : (isDark ? Colors.grey[700] : Colors.grey[200]),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Step content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step['title']!,
                                  style: TextStyle(
                                    fontSize: context.bodySize,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted || isCurrent
                                        ? (isDark ? Colors.white : Colors.grey[800])
                                        : (isDark ? Colors.grey[500] : Colors.grey[400]),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step['subtitle']!,
                                  style: TextStyle(
                                    fontSize: context.captionSize,
                                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCompleted || isCurrent)
                            Icon(
                              isCompleted ? Icons.check_circle : Icons.radio_button_checked,
                              size: 16,
                              color: isCompleted ? const Color(0xFF22C55E) : stepInfo['color'] as Color,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCourierInfo(bool isDark) {
    final courierName = _orderData?['courier_name'] ?? 'Kurye';
    final courierPhone = _orderData?['courier_phone'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: FoodColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delivery_dining,
              size: 32,
              color: FoodColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courierName,
                  style: TextStyle(
                    fontSize: context.heading2Size,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 4),
                    Text(
                      '4.9',
                      style: TextStyle(
                        fontSize: context.captionSize,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• 1.250+ teslimat',
                      style: TextStyle(
                        fontSize: context.captionSize,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildActionButton(
                Icons.chat_bubble_outline,
                isDark,
                onTap: () => _openChatWithCourier(isDark),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                Icons.phone_outlined,
                isDark,
                isPrimary: true,
                onTap: courierPhone != null ? () => _callCourier(courierPhone) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    bool isDark, {
    bool isPrimary = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isPrimary
              ? FoodColors.primary
              : (isDark ? Colors.grey[700] : Colors.grey[100]),
          shape: BoxShape.circle,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: FoodColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isPrimary
              ? Colors.white
              : (isDark ? Colors.grey[300] : Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildOrderDetails(bool isDark) {
    final items = _orderData?['items'] as List<dynamic>? ?? [];
    final subtotal = (_orderData?['subtotal'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (_orderData?['delivery_fee'] as num?)?.toDouble() ?? 0;
    final total = (_orderData?['total'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sipariş Detayları',
            style: TextStyle(
              fontSize: context.heading2Size,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Order items
          ...items.map((item) {
            final name = item['name'] ?? 'Ürün';
            final quantity = item['quantity'] ?? 1;
            final price = (item['price'] as num?)?.toDouble() ?? 0;
            final rawOptions = item['options'];
            final optionsText = rawOptions is String && rawOptions.isNotEmpty ? rawOptions : (rawOptions is List && rawOptions.isNotEmpty ? rawOptions.join(', ') : null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderItem('${quantity}x $name', '₺${(price * quantity).toStringAsFixed(2)}', isDark),
                if (optionsText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      optionsText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            );
          }),

          if (items.isEmpty) ...[
            _buildOrderItem('Ürün bilgisi yükleniyor...', '', isDark),
          ],

          Divider(
            height: 24,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),

          _buildOrderItem('Ara Toplam', '₺${subtotal.toStringAsFixed(2)}', isDark),
          _buildOrderItem('Teslimat Ücreti', '₺${deliveryFee.toStringAsFixed(2)}', isDark),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toplam',
                style: TextStyle(
                  fontSize: context.heading2Size,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              Text(
                '₺${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: context.heading2Size,
                  fontWeight: FontWeight.bold,
                  color: FoodColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(String name, String price, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: context.bodySize,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: context.bodySize,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.pagePaddingH,
        16,
        context.pagePaddingH,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showCancelOrderDialog(isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'İptal Et',
                    style: TextStyle(
                      fontSize: context.heading2Size,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _canSendMessage
                  ? () {
                      setState(() => _unreadMessageCount = 0);
                      _showSupportDialog(isDark);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _canSendMessage
                      ? LinearGradient(
                          colors: [FoodColors.primary, const Color(0xFFEA580C)],
                        )
                      : null,
                  color: _canSendMessage ? null : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _canSendMessage
                      ? [
                          BoxShadow(
                            color: FoodColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store, color: _canSendMessage ? Colors.white : Colors.grey[500], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _canSendMessage ? 'Restorana Yaz' : 'Mesaj süresi doldu',
                          style: TextStyle(
                            fontSize: context.heading2Size,
                            fontWeight: FontWeight.bold,
                            color: _canSendMessage ? Colors.white : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    // Unread badge
                    if (_unreadMessageCount > 0)
                      Positioned(
                        right: -8,
                        top: -20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mail, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '$_unreadMessageCount yeni',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: context.captionSmallSize,
                                  fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  // ============ DIALOG & ACTION FUNCTIONS ============

  void _showHelpDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Yardım ve Destek',
              style: TextStyle(
                fontSize: context.heading1Size,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),
            _buildHelpOption(
              icon: Icons.store,
              title: 'Restorana Mesaj',
              subtitle: 'Sipariş hakkında soru sorun',
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _showSupportDialog(isDark);
              },
            ),
            _buildHelpOption(
              icon: Icons.phone_outlined,
              title: 'Telefon Desteği',
              subtitle: '0850 123 45 67',
              isDark: isDark,
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse('tel:08501234567');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FoodColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: FoodColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: context.heading2Size,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: context.bodySmallSize, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showCancelOrderDialog(bool isDark) {
    // Sadece restoran onaylamadan önce iptal edilebilir
    final canCancel = _currentStatus == 'pending';

    if (!canCancel) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? FoodColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'İptal Edilemez',
            style: TextStyle(color: isDark ? Colors.white : Colors.grey[800]),
          ),
          content: Text(
            'Restoran siparişinizi onayladıktan sonra iptal edemezsiniz. Lütfen restoranla iletişime geçin.',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[600]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSupportDialog(isDark);
              },
              style: ElevatedButton.styleFrom(backgroundColor: FoodColors.primary),
              child: const Text(
                'Restorana Yaz',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? FoodColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Siparişi İptal Et',
          style: TextStyle(color: isDark ? Colors.white : Colors.grey[800]),
        ),
        content: Text(
          'Siparişinizi iptal etmek istediğinizden emin misiniz?',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelOrder();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'İptal Et',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    try {
      await SupabaseService.client
          .from('orders')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': 'Müşteri tarafından iptal edildi',
          })
          .eq('id', widget.orderId);

      if (mounted) {
        await AppDialogs.showSuccess(context, 'Siparişiniz iptal edildi');

        // Go back to food home
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/food');
        }
      }
    } catch (e) {
      if (mounted) {
        await AppDialogs.showError(context, 'İptal işlemi başarısız: $e');
      }
    }
  }

  void _openChatWithCourier(bool isDark) {
    final courierName = _orderData?['courier_name'] ?? 'Kurye';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.5,
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: FoodColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delivery_dining, color: FoodColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courierName,
                          style: TextStyle(
                            fontSize: context.heading2Size,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Kurye ile sohbet',
                          style: TextStyle(fontSize: context.captionSize, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            // Message area placeholder
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Kurye mesajlaşması yakında aktif olacak',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callCourier(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        await AppDialogs.showError(context, 'Arama yapılamıyor');
      }
    }
  }

  void _showSupportDialog(bool isDark) {
    final restaurantName = _orderData?['merchants']?['business_name'] ?? 'Restoran';
    final restaurantPhone = _orderData?['merchants']?['phone'] as String?;
    final merchantId = _orderData?['merchant_id'] as String?;

    // Chat açıldığını işaretle
    setState(() {
      _isChatOpen = true;
      _unreadMessageCount = 0; // Okunmamış mesajları sıfırla
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RestaurantChatSheet(
        orderId: widget.orderId,
        merchantId: merchantId ?? '',
        restaurantName: restaurantName,
        restaurantPhone: restaurantPhone,
        isDark: isDark,
        canSendMessage: _canSendMessage,
      ),
    ).whenComplete(() {
      // Chat kapandığında işaretle
      if (mounted) {
        setState(() {
          _isChatOpen = false;
        });
      }
    });
  }
}

/// Restoran ile mesajlaşma bottom sheet'i
class _RestaurantChatSheet extends StatefulWidget {
  final String orderId;
  final String merchantId;
  final String restaurantName;
  final String? restaurantPhone;
  final bool isDark;
  final bool canSendMessage;

  const _RestaurantChatSheet({
    required this.orderId,
    required this.merchantId,
    required this.restaurantName,
    this.restaurantPhone,
    required this.isDark,
    this.canSendMessage = true,
  });

  @override
  State<_RestaurantChatSheet> createState() => _RestaurantChatSheetState();
}

class _RestaurantChatSheetState extends State<_RestaurantChatSheet> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await SupabaseService.client
          .from('order_messages')
          .select('*')
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(messages);
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      // Restorandan gelen okunmamış mesajları okundu olarak işaretle
      await SupabaseService.client
          .from('order_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('order_id', widget.orderId)
          .eq('sender_type', 'merchant')
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  void _setupRealtimeSubscription() {
    _subscription = SupabaseService.client
        .channel('customer_messages_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (payload) {
            if (mounted) {
              final newMsg = payload.newRecord;
              final newMsgId = newMsg['id'];

              // Aynı mesaj zaten var mı kontrol et (duplicate engelle)
              final alreadyExists = _messages.any((m) => m['id'] == newMsgId);
              if (alreadyExists) return;

              // Müşteri mesajı ise ve temp mesaj varsa, temp'i gerçek mesajla değiştir
              if (newMsg['sender_type'] == 'customer') {
                final tempIndex = _messages.indexWhere((m) =>
                  m['id'].toString().startsWith('temp_') &&
                  m['message'] == newMsg['message']
                );
                if (tempIndex != -1) {
                  setState(() {
                    _messages[tempIndex] = newMsg;
                  });
                  return;
                }
              }

              setState(() {
                _messages.add(newMsg);
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 'Müşteri';

    // Optimistic update
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'order_id': widget.orderId,
      'sender_type': 'customer',
      'sender_id': user?.id,
      'sender_name': userName,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      await SupabaseService.client.from('order_messages').insert({
        'order_id': widget.orderId,
        'merchant_id': widget.merchantId,
        'sender_type': 'customer',
        'sender_id': user?.id,
        'sender_name': userName,
        'message': message,
      });
    } catch (e) {
      if (mounted) {
        await AppDialogs.showError(context, 'Mesaj gönderilemedi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FoodColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.restaurantName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Restoran ile iletişim',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (widget.restaurantPhone != null && widget.restaurantPhone!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.white),
                    onPressed: () async {
                      final uri = Uri.parse('tel:${widget.restaurantPhone}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz mesaj yok',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Siparişiniz hakkında soru sormak için\nmesaj yazabilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isFromCustomer = msg['sender_type'] == 'customer';
                          final time = DateTime.tryParse(msg['created_at'] ?? '');
                          final timeStr = time != null
                              ? '${time.toLocal().hour.toString().padLeft(2, '0')}:${time.toLocal().minute.toString().padLeft(2, '0')}'
                              : '';

                          return Align(
                            alignment: isFromCustomer ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isFromCustomer
                                    ? FoodColors.primary
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isFromCustomer)
                                    Text(
                                      msg['sender_name'] ?? 'Restoran',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: FoodColors.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (!isFromCustomer) const SizedBox(height: 4),
                                  Text(
                                    msg['message'] ?? '',
                                    style: TextStyle(
                                      color: isFromCustomer ? Colors.white : Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isFromCustomer ? Colors.white70 : Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Message input
          if (widget.canSendMessage)
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey[850] : Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: widget.isDark ? Colors.grey[800] : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: FoodColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey[850] : Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Center(
                child: Text(
                  'Mesaj süresi doldu (teslimattan 10 dk sonra)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
