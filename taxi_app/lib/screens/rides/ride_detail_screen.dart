import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/taxi_service.dart';
import '../../core/services/directions_service.dart';
import '../../core/services/communication_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ride_models.dart';
import '../../widgets/animated_map_markers.dart';
import '../../widgets/secure_communication_widgets.dart';

class RideDetailScreen extends ConsumerStatefulWidget {
  final String rideId;

  const RideDetailScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends ConsumerState<RideDetailScreen>
    with TickerProviderStateMixin {
  Ride? _ride;
  bool _isLoading = true;
  bool _isUpdating = false;
  List<gmaps.LatLng> _routePoints = [];

  gmaps.GoogleMapController? _mapController;
  RealtimeChannel? _rideChannel;
  Timer? _pollingTimer;
  bool _isDisposed = false;

  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;

  // Custom Markers & Style
  gmaps.BitmapDescriptor? _pickupMarker;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadRide();
    _subscribeToRide();
    _startPolling();
    _loadMapStyle();
    _initCustomMarkers();
  }

  void _loadMapStyle() {
    _mapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#212121"}]
      },
      {
        "elementType": "labels.icon",
        "stylers": [{"visibility": "off"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#212121"}]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "administrative.country",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#9e9e9e"}]
      },
      {
        "featureType": "administrative.land_parcel",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#bdbdbd"}]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [{"color": "#181818"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#1b1b1b"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [{"color": "#2c2c2c"}]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#8a8a8a"}]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry",
        "stylers": [{"color": "#373737"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [{"color": "#3c3c3c"}]
      },
      {
        "featureType": "road.highway.controlled_access",
        "elementType": "geometry",
        "stylers": [{"color": "#4e4e4e"}]
      },
      {
        "featureType": "road.local",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "featureType": "transit",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#000000"}]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#3d3d3d"}]
      }
    ]
    ''';
  }

  Future<void> _initCustomMarkers() async {
    _pickupMarker = await AnimatedMapMarkers.createPickupMarker(size: 80);
    if (mounted) setState(() {});
  }

  void _initAnimations() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _loadRide() async {
    setState(() => _isLoading = true);
    try {
      // 10 saniye timeout ekle
      final rideData = await TaxiService.getRide(widget.rideId)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (rideData != null && mounted && !_isDisposed) {
        setState(() {
          _ride = Ride.fromJson(rideData);
          _isLoading = false;
        });
        _slideController.forward();
        if (!_isDisposed) _updateMapView();
        if (!_isDisposed) _loadRoute();
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          // Yolculuk bulunamadıysa geri dön
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yolculuk bulunamadı veya zaman aşımına uğradı'),
              backgroundColor: Colors.orange,
            ),
          );
          // 2 saniye sonra geri dön
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.pop();
          });
        }
      }
    } catch (e) {
      debugPrint('Load ride error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _subscribeToRide() {
    _rideChannel = TaxiService.subscribeToRide(widget.rideId, (rideData) {
      if (mounted && !_isDisposed) {
        setState(() => _ride = Ride.fromJson(rideData));
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isDisposed || !mounted) return;
      final rideData = await TaxiService.getRide(widget.rideId);
      if (rideData != null && mounted && !_isDisposed) {
        final newRide = Ride.fromJson(rideData);
        if (_ride?.status != newRide.status) {
          setState(() => _ride = newRide);
        }
      }
    });
  }

  Future<void> _loadRoute() async {
    if (_ride == null || _isDisposed) return;
    try {
      final result = await DirectionsService.getDirections(
        originLat: _ride!.pickup.latitude,
        originLng: _ride!.pickup.longitude,
        destLat: _ride!.dropoff.latitude,
        destLng: _ride!.dropoff.longitude,
      );
      if (result != null && mounted && !_isDisposed) {
        setState(() {
          _routePoints = result.routePoints
              .map((p) => gmaps.LatLng(p.latitude, p.longitude))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading route: $e');
    }
  }

  Set<gmaps.Polyline> _buildPolylines() {
    if (_ride == null) return {};

    // Gerçek rota noktaları varsa kullan
    if (_routePoints.isNotEmpty) {
      return {
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          points: _routePoints,
          color: AppColors.primary,
          width: 5,
        ),
      };
    }

    // Fallback: düz çizgi (kesikli)
    return {
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route'),
        points: [
          gmaps.LatLng(_ride!.pickup.latitude, _ride!.pickup.longitude),
          gmaps.LatLng(_ride!.dropoff.latitude, _ride!.dropoff.longitude),
        ],
        color: AppColors.primary,
        width: 4,
        patterns: [gmaps.PatternItem.dash(20), gmaps.PatternItem.gap(10)],
      ),
    };
  }

  void _updateMapView() {
    if (_isDisposed || !mounted || _mapController == null || _ride == null) return;

    try {
      final bounds = gmaps.LatLngBounds(
        southwest: gmaps.LatLng(
          _ride!.pickup.latitude < _ride!.dropoff.latitude
              ? _ride!.pickup.latitude
              : _ride!.dropoff.latitude,
          _ride!.pickup.longitude < _ride!.dropoff.longitude
              ? _ride!.pickup.longitude
              : _ride!.dropoff.longitude,
        ),
        northeast: gmaps.LatLng(
          _ride!.pickup.latitude > _ride!.dropoff.latitude
              ? _ride!.pickup.latitude
              : _ride!.dropoff.latitude,
          _ride!.pickup.longitude > _ride!.dropoff.longitude
              ? _ride!.pickup.longitude
              : _ride!.dropoff.longitude,
        ),
      );

      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } catch (e) {
      // Map controller disposed olmuş olabilir, hata sessizce yoksay
      debugPrint('Map update skipped: controller disposed');
    }
  }

  Future<void> _updateStatus() async {
    if (_ride == null || _ride!.nextStatus == null) return;

    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();

    bool success = false;
    switch (_ride!.nextStatus) {
      case RideStatus.arrived:
        success = await TaxiService.arriveAtPickup(widget.rideId);
        break;
      case RideStatus.inProgress:
        success = await TaxiService.startRide(widget.rideId);
        break;
      case RideStatus.completed:
        success = await TaxiService.completeRide(widget.rideId);
        break;
      default:
        break;
    }

    if (success && mounted) {
      await _loadRide();

      if (_ride?.status == RideStatus.completed) {
        _showCompletionDialog();
      }
    }

    setState(() => _isUpdating = false);
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Yolculugu Iptal Et'),
        content: const Text(
          'Bu yolculugu iptal etmek istediginizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Iptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isUpdating = true);
      final success = await TaxiService.cancelRide(widget.rideId);
      setState(() => _isUpdating = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Yolculuk iptal edildi'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.pop();
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CompletionDialog(
        ride: _ride!,
        onDone: () {
          Navigator.pop(context);
          context.pop();
        },
      ),
    );
  }

  Future<void> _openNavigation() async {
    if (_ride == null) return;

    final destination =
        _ride!.status == RideStatus.accepted ||
            _ride!.status == RideStatus.arrived
        ? _ride!.pickup
        : _ride!.dropoff;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Güvenli arama artık CommunicationService üzerinden yapılıyor
  // _callCustomer metodu SecureCustomerCard widget'ında yönetiliyor

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _rideChannel?.unsubscribe();
    _rideChannel = null;
    _slideController.dispose();
    _pulseController.dispose();
    // MapController'ı null yap, dispose'u Google Maps widget'ına bırak
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Yolculuk yukleniyor...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_ride == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Yolculuk'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Yolculuk bulunamadi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Geri Don'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map
          Positioned.fill(
            bottom: MediaQuery.of(context).size.height * 0.45,
            child: _buildMap(),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: _buildBackButton(),
          ),

          // Navigation button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: _buildNavigationButton(),
          ),

          // Emergency button
          if (_ride!.isActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              child: EmergencyButton(
                rideId: widget.rideId,
                latitude: _ride!.pickup.latitude,
                longitude: _ride!.pickup.longitude,
              ),
            ),

          // Bottom Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildBottomSheet(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(_ride!.pickup.latitude, _ride!.pickup.longitude),
        zoom: 14,
      ),
      onMapCreated: (controller) {
        if (_isDisposed) return;
        _mapController = controller;
        _updateMapView();
      },
      markers: {
        gmaps.Marker(
          markerId: const gmaps.MarkerId('pickup'),
          position: gmaps.LatLng(
            _ride!.pickup.latitude,
            _ride!.pickup.longitude,
          ),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueGreen,
          ),
          infoWindow: gmaps.InfoWindow(
            title: 'Alis Noktasi',
            snippet: _ride!.pickup.address,
          ),
        ),
        gmaps.Marker(
          markerId: const gmaps.MarkerId('dropoff'),
          position: gmaps.LatLng(
            _ride!.dropoff.latitude,
            _ride!.dropoff.longitude,
          ),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueRed,
          ),
          infoWindow: gmaps.InfoWindow(
            title: 'Varis Noktasi',
            snippet: _ride!.dropoff.address,
          ),
        ),
      },
      polylines: _buildPolylines(),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildBackButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
        ],
      ),
      child: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }

  Widget _buildNavigationButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info,
            Color(0xFF2563EB), // Manually darker shade of blue/info
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.info.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openNavigation,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.navigation, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Navigasyon',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Status Header
          _buildStatusHeader(),

          // Customer Info
          _buildCustomerInfo(),

          // Route Info
          _buildRouteInfo(),

          // Fare
          _buildFareInfo(),

          // Action Buttons
          _buildActionButtons(),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _ride!.status.color,
            _ride!.status.color.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.2 + (_pulseController.value * 0.1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_ride!.status.icon, color: Colors.white, size: 24),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ride!.status.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getStatusSubtitle(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_ride!.rideNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _ride!.rideNumber!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusSubtitle() {
    switch (_ride!.status) {
      case RideStatus.accepted:
        return 'Musteri bekliyor, alis noktasina gidin';
      case RideStatus.arrived:
        return 'Musteriyi alin ve yolculugu baslatin';
      case RideStatus.inProgress:
        return 'Varis noktasina dogru ilerleyin';
      case RideStatus.completed:
        return 'Yolculuk basariyla tamamlandi';
      default:
        return '';
    }
  }

  Widget _buildCustomerInfo() {
    // Güvenli müşteri bilgisi widget'ı kullan
    return SecureCustomerCard(
      rideId: widget.rideId,
      onMessagePressed: () => _openSecureChat(),
    );
  }

  void _openSecureChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RideChatSheet(rideId: widget.rideId),
    );
  }

  Widget _buildRouteInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Pickup
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alis Noktasi',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                    Text(
                      _ride!.pickup.address,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Line
          Container(
            margin: const EdgeInsets.only(left: 5),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.success, AppColors.error],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dropoff
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Varis Noktasi',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                    Text(
                      _ride!.dropoff.address,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yolculuk Ucreti',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _ride!.formattedDistance,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                      Text(' - ', style: TextStyle(color: AppColors.textHint)),
                      Text(
                        _ride!.formattedDuration,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Text(
            _ride!.formattedFare,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Cancel button
          if (_ride!.isActive)
            Expanded(
              child: OutlinedButton(
                onPressed: _isUpdating ? null : _cancelRide,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Iptal'),
              ),
            ),

          if (_ride!.isActive) const SizedBox(width: 12),

          // Main action button
          if (_ride!.nextActionLabel != null)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ride!.status == RideStatus.inProgress
                      ? AppColors.success
                      : AppColors.primary,
                  foregroundColor: _ride!.status == RideStatus.inProgress
                      ? Colors.white
                      : AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isUpdating
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _ride!.status == RideStatus.inProgress
                              ? Colors.white
                              : AppColors.secondary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getActionIcon(), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _ride!.nextActionLabel!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getActionIcon() {
    switch (_ride!.status) {
      case RideStatus.accepted:
        return Icons.place;
      case RideStatus.arrived:
        return Icons.local_taxi;
      case RideStatus.inProgress:
        return Icons.check_circle;
      default:
        return Icons.arrow_forward;
    }
  }
}

// ==================== COMPLETION DIALOG ====================

class _CompletionDialog extends StatefulWidget {
  final Ride ride;
  final VoidCallback onDone;

  const _CompletionDialog({required this.ride, required this.onDone});

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Yolculuk Tamamlandi!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Harika is cikardınız!',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // Earnings
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Kazanc',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.ride.formattedFare,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onDone,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tamam',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
