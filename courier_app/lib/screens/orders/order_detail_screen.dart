import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/courier_service.dart';
import '../../core/theme/app_theme.dart';
import 'navigation_map_screen.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  final Map<String, dynamic>? initialOrderData;

  const OrderDetailScreen({super.key, required this.orderId, this.initialOrderData});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  bool _isUpdating = false;
  Timer? _locationTimer;
  Position? _currentPosition;
  double? _distanceToDestination;
  RealtimeChannel? _orderChannel;

  @override
  void initState() {
    super.initState();
    // Eğer initialOrderData varsa, onu kullan (RPC'den dönen veri)
    if (widget.initialOrderData != null) {
      _order = widget.initialOrderData;
      _isLoading = false;
    } else {
      _loadOrder();
    }
    _subscribeToOrderUpdates();
    // Location tracking'i ertele - UI donmasını önle
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startLocationTracking();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _orderChannel?.unsubscribe();
    super.dispose();
  }

  /// Sipariş güncellemelerini dinle (realtime)
  void _subscribeToOrderUpdates() {
    final supabase = Supabase.instance.client;

    _orderChannel = supabase
        .channel('order_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (payload) {
            debugPrint('Order updated via realtime: ${payload.newRecord}');
            // Sipariş güncellendi, yeniden yükle
            _loadOrder();
          },
        )
        .subscribe();
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // İlk konum - önce son bilinen konumu dene (hızlı, exception fırlatmaz)
    await _updateCurrentPosition();

    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _updateCurrentPosition();
      if (mounted) setState(() {});
    });
  }

  /// Konumu güncelle - exception fırlatmadan güvenli şekilde
  Future<void> _updateCurrentPosition() async {
    if (!mounted) return;

    try {
      // Önce son bilinen konumu dene (hızlı ve exception fırlatmaz)
      _currentPosition ??= await Geolocator.getLastKnownPosition();

      // Son bilinen konum yoksa güncel konum al
      if (_currentPosition == null) {
        try {
          _currentPosition = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          debugPrint('getCurrentPosition error: $e');
        }
      }

      _calculateDistance();

      if (_currentPosition != null && mounted) {
        // Konum güncellemeyi arka planda yap, beklemeden devam et
        unawaited(CourierService.updateLocation(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ).then((_) {}).catchError((e) {
          debugPrint('Location update to server error: $e');
        }));
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _calculateDistance() {
    if (_currentPosition == null || _order == null) return;

    // Her zaman MÜŞTERİ konumuna mesafe hesapla - ana hedef her zaman müşteri
    final destLat = (_order!['delivery_latitude'] as num?)?.toDouble();
    final destLng = (_order!['delivery_longitude'] as num?)?.toDouble();

    if (destLat != null && destLng != null) {
      _distanceToDestination = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        destLat,
        destLng,
      ) / 1000;
    }
  }

  Future<void> _loadOrder({int retryCount = 0}) async {
    setState(() => _isLoading = true);
    try {
      final order = await CourierService.getOrderDetail(widget.orderId);
      if (order == null && retryCount < 3) {
        // Sipariş henüz görünür değilse, kısa bekle ve tekrar dene
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        if (mounted) {
          return _loadOrder(retryCount: retryCount + 1);
        }
        return;
      }
      setState(() {
        _order = order;
        _isLoading = false;
      });
      _calculateDistance();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final success = await CourierService.updateOrderStatus(widget.orderId, newStatus);
      if (success) {
        await _loadOrder();
        if (mounted && newStatus == 'delivered') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sipariş teslim edildi! Tebrikler!'),
              backgroundColor: AppColors.success,
            ),
          );
          // Pop with result to trigger refresh on home screen
          context.pop(true);
          return;
        }
      }
    } finally {
      // Only call setState if widget is still mounted
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _openMaps({
    required double? lat,
    required double? lng,
    required String address,
    required String name,
    String? phone,
    bool isCustomer = true,
  }) {
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum bilgisi bulunamadı')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NavigationMapScreen(
          destinationLat: lat,
          destinationLng: lng,
          destinationName: name,
          destinationAddress: address,
          destinationPhone: phone,
          isCustomer: isCustomer,
        ),
      ),
    );
  }

  Future<void> _callPhone(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon numarası bulunamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sipariş Detayı')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sipariş Detayı')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Sipariş bulunamadı'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final merchant = _order!['merchants'] as Map<String, dynamic>?;
    final status = _order!['status'] as String? ?? '';
    final deliveryStatus = _order!['delivery_status'] as String? ?? '';
    final courierType = _order!['courier_type'] as String? ?? 'platform';
    final isRestaurantCourier = courierType == 'restaurant';
    final deliveryFee = (_order!['delivery_fee'] as num?)?.toDouble() ?? 0;
    final totalAmount = (_order!['total_amount'] as num?)?.toDouble() ?? 0;
    final customerName = _order!['customer_name'] as String? ?? 'Müşteri';
    final customerPhone = _order!['customer_phone'] as String?;
    final paymentMethod = _order!['payment_method'] as String? ?? 'cash';
    final deliveryInstructions = _order!['delivery_instructions'] as String?;
    final items = _order!['items'] as List<dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_order!['order_number'] ?? 'Sipariş'),
        actions: [
          IconButton(
            onPressed: _loadOrder,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card - Full width
            _buildStatusCard(status, deliveryStatus),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Stepper
                  _buildProgressStepper(status, deliveryStatus),

                  const SizedBox(height: 20),

                  // Distance Info
                  if (_distanceToDestination != null && status != 'delivered')
                    _buildDistanceCard(status, deliveryStatus, isRestaurantCourier: isRestaurantCourier),

                  if (_distanceToDestination != null) const SizedBox(height: 16),

                  // MÜŞTERİ KARTI - Sipariş alındıktan sonra aktif
                  _buildLocationCard(
                    icon: Icons.person_pin_circle,
                    iconColor: AppColors.error,
                    title: 'Müşteri (Teslimat Noktası)',
                    name: customerName,
                    address: _order!['delivery_address'] ?? 'Adres belirtilmemiş',
                    lat: (_order!['delivery_latitude'] as num?)?.toDouble(),
                    lng: (_order!['delivery_longitude'] as num?)?.toDouble(),
                    phone: customerPhone,
                    // Müşteri kartı: sipariş alındıktan sonra aktif (picked_up, delivering)
                    isActive: status == 'picked_up' || status == 'delivering',
                    isCustomer: true,
                  ),

                  const SizedBox(height: 12),

                  // Restoran Kartı - Sipariş alınmadan önce aktif
                  if (!isRestaurantCourier && merchant != null) ...[
                    _buildLocationCard(
                      icon: Icons.store,
                      iconColor: AppColors.primary,
                      title: 'Restoran (Alım Noktası)',
                      name: merchant['business_name'] ?? 'Restoran',
                      address: merchant['address']?.isNotEmpty == true
                          ? merchant['address']
                          : 'Adres belirtilmemiş',
                      lat: (merchant['latitude'] as num?)?.toDouble(),
                      lng: (merchant['longitude'] as num?)?.toDouble(),
                      phone: merchant['phone'],
                      // Restoran kartı: sipariş alınmadan önce aktif (preparing, ready)
                      isActive: status == 'preparing' || status == 'ready',
                      isCustomer: false,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Delivery Instructions
                  if (deliveryInstructions != null && deliveryInstructions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildNotesCard(deliveryInstructions),
                  ],

                  const SizedBox(height: 20),

                  // Order Items Section
                  _buildSectionTitle('Sipariş İçeriği', Icons.receipt_long),
                  const SizedBox(height: 12),
                  _buildOrderItemsCard(items),

                  const SizedBox(height: 20),

                  // Payment & Summary Section
                  _buildSectionTitle('Ödeme Bilgileri', Icons.payment),
                  const SizedBox(height: 12),
                  _buildPaymentCard(
                    paymentMethod: paymentMethod,
                    totalAmount: totalAmount,
                    deliveryFee: deliveryFee,
                    isRestaurantCourier: isRestaurantCourier,
                    courierEarnings: (_order!['courier_earnings'] as num?)?.toDouble(),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (status != 'delivered') _buildActionButtons(status, deliveryStatus),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStepper(String status, String deliveryStatus) {
    // Adımlar: Atandı -> Alındı -> Yolda -> Teslim
    int currentStep = 0;
    if (deliveryStatus == 'assigned' && (status == 'preparing' || status == 'ready')) {
      currentStep = 0;
    } else if (status == 'picked_up') {
      currentStep = 1;
    } else if (status == 'delivering') {
      currentStep = 2;
    } else if (status == 'delivered') {
      currentStep = 3;
    }

    final steps = [
      {'icon': Icons.assignment, 'label': 'Atandı'},
      {'icon': Icons.inventory_2, 'label': 'Alındı'},
      {'icon': Icons.delivery_dining, 'label': 'Yolda'},
      {'icon': Icons.check_circle, 'label': 'Teslim'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          final step = steps[index];

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: isCompleted ? AppColors.success : AppColors.border,
                        ),
                      ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success
                            : isCurrent
                                ? AppColors.primary
                                : AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        size: 18,
                        color: isCompleted || isCurrent ? Colors.white : AppColors.textHint,
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: isCompleted ? AppColors.success : AppColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDistanceCard(String status, String deliveryStatus, {bool isRestaurantCourier = false}) {
    final estimatedMinutes = (_distanceToDestination! * 3).round();
    // Her zaman müşteriye mesafe göster - ana hedef müşteri
    const destination = 'Müşteriye';
    const icon = Icons.person_pin_circle;
    final color = AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$destination ${_distanceToDestination!.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tahmini süre: ~$estimatedMinutes dakika',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.gps_fixed, color: AppColors.success, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status, String deliveryStatus) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    // Durumu belirle
    if (deliveryStatus == 'assigned' && (status == 'preparing' || status == 'ready')) {
      if (status == 'preparing') {
        icon = Icons.hourglass_empty;
        color = AppColors.warning;
        title = 'Sipariş Hazırlanıyor';
        subtitle = 'Restoran siparişi hazırlıyor, bekleyin veya restorana gidin';
      } else {
        icon = Icons.check_circle_outline;
        color = AppColors.success;
        title = 'Sipariş Hazır!';
        subtitle = 'Restorana gidin ve siparişi teslim alın';
      }
    } else if (status == 'picked_up') {
      icon = Icons.inventory_2;
      color = AppColors.info;
      title = 'Sipariş Alındı';
      subtitle = 'Müşteriye doğru yola çıkın';
    } else if (status == 'delivering') {
      icon = Icons.delivery_dining;
      color = AppColors.primary;
      title = 'Teslimat Yolunda';
      subtitle = 'Müşteriye ulaştığınızda teslim edin';
    } else if (status == 'delivered') {
      icon = Icons.verified;
      color = AppColors.success;
      title = 'Teslim Edildi';
      subtitle = 'Sipariş başarıyla tamamlandı';
    } else {
      icon = Icons.pending;
      color = AppColors.textSecondary;
      title = status;
      subtitle = '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.8)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String name,
    required String address,
    double? lat,
    double? lng,
    String? phone,
    bool isActive = false,
    bool isCustomer = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? iconColor.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? iconColor.withValues(alpha: 0.3) : AppColors.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'AKTİF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                // Pasif kart için küçük butonlar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSmallIconButton(
                      icon: Icons.directions,
                      color: AppColors.textHint,
                      onTap: () => _openMaps(
                        lat: lat,
                        lng: lng,
                        address: address,
                        name: name,
                        phone: phone,
                        isCustomer: isCustomer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSmallIconButton(
                      icon: Icons.phone,
                      color: AppColors.textHint,
                      onTap: () => _callPhone(phone),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppColors.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          // Sadece aktif kart için büyük butonlar göster
          if (isActive) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMaps(
                      lat: lat,
                      lng: lng,
                      address: address,
                      name: name,
                      phone: phone,
                      isCustomer: isCustomer,
                    ),
                    icon: const Icon(Icons.directions, size: 20),
                    label: const Text('Yol Tarifi Al'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => _callPhone(phone),
                    icon: Icon(Icons.phone, color: iconColor),
                    tooltip: 'Ara',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teslimat Notu',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text('Sipariş içeriği bulunamadı'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>;

          // JSONB formatından okuma
          final name = item['name'] as String? ?? 'Ürün';
          final quantity = item['quantity'] as int? ?? 1;
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          final total = (item['total'] as num?)?.toDouble() ?? (price * quantity);
          final imageUrl = item['image_url'] as String?;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Ürün resmi veya quantity badge
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildQuantityBadge(quantity),
                        ),
                      )
                    else
                      _buildQuantityBadge(quantity),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          if (imageUrl != null)
                            Text(
                              '$quantity adet × ₺${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '₺${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < items.length - 1)
                Divider(height: 1, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuantityBadge(int quantity) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '${quantity}x',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard({
    required String paymentMethod,
    required double totalAmount,
    required double deliveryFee,
    required bool isRestaurantCourier,
    double? courierEarnings,
  }) {
    final methodIcon = paymentMethod == 'card' ? Icons.credit_card : Icons.money;
    final methodColor = paymentMethod == 'card' ? AppColors.success : AppColors.warning;

    // Ödeme durumu metni
    String methodText;
    if (paymentMethod == 'card') {
      methodText = 'Kredi Kartı (Ödendi)';
    } else if (paymentMethod == 'online') {
      methodText = 'Online Ödeme (Ödendi)';
    } else {
      methodText = 'Kapıda Nakit';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Ödeme yöntemi
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(methodIcon, color: methodColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ödeme Yöntemi',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      methodText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: methodColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Nakit ise tahsil edilecek tutarı vurgula
              if (paymentMethod == 'cash')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Tahsil Et',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.warning,
                        ),
                      ),
                      Text(
                        '₺${totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          // Sipariş detayları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sipariş Tutarı'),
              Text('₺${(totalAmount - deliveryFee).toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Teslimat Ücreti'),
              Text('₺${deliveryFee.toStringAsFixed(2)}'),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Toplam',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '₺${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          // Kurye kazancı - SADECE platform kuryesi için göster
          // Restoran kuryesi maaşlı personeldir, teslimat başına kazanç almaz
          if (!isRestaurantCourier && courierEarnings != null && courierEarnings > 0) ...[
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wallet, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Kazancınız',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    '₺${courierEarnings.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status, String deliveryStatus) {
    if (_isUpdating) {
      return const Center(child: CircularProgressIndicator());
    }

    // Sipariş hazırlanıyorsa buton gösterme
    if (deliveryStatus == 'assigned' && status == 'preparing') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Sipariş hazırlanıyor, lütfen bekleyin...',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Sipariş hazır - Teslim Al butonu
    if (deliveryStatus == 'assigned' && status == 'ready') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateStatus('picked_up'),
          icon: const Icon(Icons.inventory_2, size: 24),
          label: const Text('Siparişi Teslim Aldım', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    // Sipariş alındı - Yola Çık butonu
    if (status == 'picked_up') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateStatus('delivering'),
          icon: const Icon(Icons.delivery_dining, size: 24),
          label: const Text('Yola Çıktım', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    // Yolda - Teslim Et butonu
    if (status == 'delivering') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateStatus('delivered'),
          icon: const Icon(Icons.check_circle, size: 24),
          label: const Text('Teslim Ettim', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
