import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/taxi_service.dart';
import '../../core/services/supabase_service.dart';
import '../../services/location_service.dart';
import '../../widgets/taxi/animated_map_markers.dart';
import '../../models/taxi/taxi_models.dart';
import 'driver_reviews_screen.dart';

class TaxiDriverScreen extends ConsumerStatefulWidget {
  const TaxiDriverScreen({super.key});

  @override
  ConsumerState<TaxiDriverScreen> createState() => _TaxiDriverScreenState();
}

class _TaxiDriverScreenState extends ConsumerState<TaxiDriverScreen>
    with TickerProviderStateMixin {
  // Controllers
  gmaps.GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();

  // State
  Map<String, dynamic>? _driverProfile;
  Map<String, dynamic>? _activeRide;
  TaxiRide? _currentRide;
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isOnline = false;
  bool _isLoading = true;

  // Location
  double _currentLat = LocationService.defaultLat;
  double _currentLng = LocationService.defaultLng;
  StreamSubscription? _locationSubscription;

  // Markers
  gmaps.BitmapDescriptor? _customerMarker;
  gmaps.BitmapDescriptor? _pickupMarker;
  gmaps.BitmapDescriptor? _dropoffMarker;
  double _customerPulseScale = 1.0;

  // Animation
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Realtime
  dynamic _rideChannel;
  dynamic _newRidesChannel;
  Timer? _locationUpdateTimer;
  Timer? _requestsRefreshTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDriverProfile();
    _initCustomMarkers();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _slideController.forward();

    // Pulse animasyonu dinle
    _pulseController.addListener(() {
      if (mounted) {
        setState(() {
          _customerPulseScale = _pulseAnimation.value;
        });
      }
    });
  }

  Future<void> _initCustomMarkers() async {
    _customerMarker = await AnimatedMapMarkers.createCustomerMarker(
      color: Colors.blue,
      size: 100,
    );
    _pickupMarker = await AnimatedMapMarkers.createPickupMarker(size: 70);
    _dropoffMarker = await AnimatedMapMarkers.createDropoffMarker(size: 70);
    if (mounted) setState(() {});
  }

  Future<void> _loadDriverProfile() async {
    try {
      debugPrint('=== DRIVER PROFILE DEBUG ===');
      debugPrint('Current User ID: ${SupabaseService.currentUser?.id}');

      final profile = await TaxiService.getDriverProfile();
      debugPrint('Profile result: $profile');

      if (profile != null && mounted) {
        setState(() {
          _driverProfile = profile;
          _isOnline = profile['is_online'] as bool? ?? false;
          _isLoading = false;
        });

        if (_isOnline) {
          _startLocationTracking();
          _loadActiveRide();
        }
      } else {
        debugPrint('Profile is null - user may not be a registered driver');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading driver profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActiveRide() async {
    if (_driverProfile == null) return;

    try {
      final ride = await TaxiService.getDriverActiveRide(_driverProfile!['id']);
      if (ride != null && mounted) {
        setState(() {
          _activeRide = ride;
          _currentRide = TaxiRide.fromJson(ride);
        });
        _subscribeToRideUpdates(ride['id']);
        _fitMapToRide();
      } else {
        _loadPendingRequests();
      }
    } catch (e) {
      debugPrint('Error loading active ride: $e');
    }
  }

  void _showDriverRegistrationDialog(ThemeData theme, ColorScheme colorScheme) {
    final fullNameController = TextEditingController();
    final phoneController = TextEditingController();
    final plateController = TextEditingController();
    final modelController = TextEditingController();
    final colorController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sürücü Kaydı',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bilgilerinizi girin, başvurunuz onaylandıktan sonra sürüş kabul edebilirsiniz.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Ad Soyad',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Telefon',
                            prefixIcon: Icon(Icons.phone_outlined),
                            hintText: '5XX XXX XX XX',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: plateController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Plaka',
                            prefixIcon: Icon(Icons.directions_car_outlined),
                            hintText: '34 ABC 123',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: modelController,
                          decoration: const InputDecoration(
                            labelText: 'Araç Modeli',
                            prefixIcon: Icon(Icons.local_taxi_outlined),
                            hintText: 'Toyota Corolla 2020',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: colorController,
                          decoration: const InputDecoration(
                            labelText: 'Araç Rengi',
                            prefixIcon: Icon(Icons.color_lens_outlined),
                            hintText: 'Sarı',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLoading ? null : () async {
                      if (fullNameController.text.isEmpty ||
                          phoneController.text.isEmpty ||
                          plateController.text.isEmpty ||
                          modelController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lütfen zorunlu alanları doldurun'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setModalState(() => isLoading = true);

                      try {
                        await TaxiService.registerAsDriver(
                          fullName: fullNameController.text.trim(),
                          phone: phoneController.text.trim(),
                          vehiclePlate: plateController.text.trim().toUpperCase(),
                          vehicleModel: modelController.text.trim(),
                          vehicleColor: colorController.text.trim().isNotEmpty
                              ? colorController.text.trim()
                              : null,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Başvurunuz alındı! Onay sonrası aktif olacaksınız.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadDriverProfile();
                        }
                      } catch (e) {
                        setModalState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Başvuru Yap'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startLocationTracking() async {
    // İlk konumu al
    final result = await _locationService.getCurrentLocationWithAddress();
    if (result.position != null && mounted) {
      setState(() {
        _currentLat = result.position!.latitude;
        _currentLng = result.position!.longitude;
      });
      _updateDriverLocation();
    }

    // Konum akışını dinle
    _locationSubscription = _locationService.getPositionStream().listen((
      position,
    ) {
      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
        });
      }
    });

    // Periyodik konum güncellemesi
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateDriverLocation();
    });
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _requestsRefreshTimer?.cancel();
  }

  Future<void> _updateDriverLocation() async {
    if (_driverProfile == null || !_isOnline) return;

    try {
      await TaxiService.updateDriverLocation(
        driverId: _driverProfile!['id'],
        latitude: _currentLat,
        longitude: _currentLng,
      );
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_driverProfile == null) return;

    final newStatus = !_isOnline;

    try {
      await TaxiService.updateDriverOnlineStatus(
        driverId: _driverProfile!['id'],
        isOnline: newStatus,
      );

      setState(() => _isOnline = newStatus);

      if (newStatus) {
        _startLocationTracking();
        _loadPendingRequests();
        _subscribeToNewRides();
      } else {
        _stopLocationTracking();
        _pendingRequests.clear();
        if (_newRidesChannel != null) {
          TaxiService.unsubscribe(_newRidesChannel);
        }
      }

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error toggling online status: $e');
    }
  }

  Future<void> _loadPendingRequests() async {
    if (!_isOnline || _activeRide != null) return;

    try {
      final requests = await TaxiService.getPendingRideRequests(
        latitude: _currentLat,
        longitude: _currentLng,
        radiusKm: 10,
      );

      if (mounted) {
        setState(() => _pendingRequests = requests);
      }
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
    }

    // 10 saniyede bir yenile
    _requestsRefreshTimer?.cancel();
    _requestsRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadPendingRequests();
    });
  }

  void _subscribeToNewRides() {
    _newRidesChannel = TaxiService.subscribeToNewRideRequests((rideData) {
      if (mounted && _activeRide == null) {
        _loadPendingRequests();
      }
    });
  }

  void _subscribeToRideUpdates(String rideId) {
    _rideChannel = TaxiService.subscribeToRide(rideId, (data) {
      if (mounted) {
        _loadActiveRide();
      }
    });
  }

  Future<void> _acceptRide(Map<String, dynamic> ride) async {
    if (_driverProfile == null) return;

    try {
      final accepted = await TaxiService.acceptRide(
        rideId: ride['id'],
        driverId: _driverProfile!['id'],
      );

      if (accepted != null && mounted) {
        setState(() {
          _activeRide = accepted;
          _currentRide = TaxiRide.fromJson(accepted);
          _pendingRequests.clear();
        });
        _requestsRefreshTimer?.cancel();
        _subscribeToRideUpdates(ride['id']);
        _fitMapToRide();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sürüş kabul edildi!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu sürüş artık mevcut değil'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadPendingRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _arriveAtPickup() async {
    if (_activeRide == null) return;

    try {
      await TaxiService.arriveAtPickup(_activeRide!['id']);
      _loadActiveRide();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _startRide() async {
    if (_activeRide == null) return;

    try {
      await TaxiService.startRide(_activeRide!['id']);
      _loadActiveRide();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _completeRide() async {
    if (_activeRide == null) return;

    try {
      await TaxiService.completeRide(_activeRide!['id']);

      setState(() {
        _activeRide = null;
        _currentRide = null;
      });

      if (_rideChannel != null) {
        TaxiService.unsubscribe(_rideChannel);
      }

      _loadPendingRequests();
      _subscribeToNewRides();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yolculuk tamamlandı!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _cancelRide() async {
    if (_activeRide == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sürüşü İptal Et'),
        content: const Text('Bu sürüşü iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, İptal Et'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await TaxiService.cancelRide(
          _activeRide!['id'],
          reason: 'driver_cancelled',
        );

        setState(() {
          _activeRide = null;
          _currentRide = null;
        });

        if (_rideChannel != null) {
          TaxiService.unsubscribe(_rideChannel);
        }

        _loadPendingRequests();
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
  }

  void _fitMapToRide() {
    if (_mapController == null || _currentRide == null) return;

    final bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(
        [
          _currentLat,
          _currentRide!.pickup.latitude,
          _currentRide!.dropoff.latitude,
        ].reduce((a, b) => a < b ? a : b),
        [
          _currentLng,
          _currentRide!.pickup.longitude,
          _currentRide!.dropoff.longitude,
        ].reduce((a, b) => a < b ? a : b),
      ),
      northeast: gmaps.LatLng(
        [
          _currentLat,
          _currentRide!.pickup.latitude,
          _currentRide!.dropoff.latitude,
        ].reduce((a, b) => a > b ? a : b),
        [
          _currentLng,
          _currentRide!.pickup.longitude,
          _currentRide!.dropoff.longitude,
        ].reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController!.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  Future<void> _openNavigation() async {
    if (_currentRide == null) return;

    final targetLat = _currentRide!.status == RideStatus.inProgress
        ? _currentRide!.dropoff.latitude
        : _currentRide!.pickup.latitude;
    final targetLng = _currentRide!.status == RideStatus.inProgress
        ? _currentRide!.dropoff.longitude
        : _currentRide!.pickup.longitude;

    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$targetLat,$targetLng&travelmode=driving',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer() async {
    final phone = _activeRide?['customer_phone'] as String?;
    if (phone == null) return;

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openReviewsScreen() {
    if (_driverProfile == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverReviewsScreen(
          driverId: _driverProfile!['id'] as String,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _mapController?.dispose();
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _requestsRefreshTimer?.cancel();
    if (_rideChannel != null) TaxiService.unsubscribe(_rideChannel);
    if (_newRidesChannel != null) TaxiService.unsubscribe(_newRidesChannel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_driverProfile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sürücü Paneli'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_taxi_rounded,
                  size: 80,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Sürücü Olun',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Taksi sürücüsü olarak kayıt olun ve kazanmaya başlayın',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _showDriverRegistrationDialog(theme, colorScheme),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Sürücü Olarak Kayıt Ol'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await SupabaseService.signOut();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  child: const Text('Çıkış Yap'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: gmaps.LatLng(_currentLat, _currentLng),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentRide != null) _fitMapToRide();
            },
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.35,
            ),
          ),

          // Top bar
          _buildTopBar(theme, colorScheme),

          // Online/Offline toggle
          _buildOnlineToggle(theme, colorScheme),

          // Bottom sheet
          _buildBottomSheet(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Back button
            Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              elevation: 4,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Driver info - tıklanınca değerlendirmeler ekranına git
            Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              elevation: 4,
              child: InkWell(
                onTap: () => _openReviewsScreen(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage:
                            _driverProfile?['profile_photo_url'] != null
                            ? NetworkImage(_driverProfile!['profile_photo_url'])
                            : null,
                        child: _driverProfile?['profile_photo_url'] == null
                            ? Icon(
                                Icons.person,
                                size: 18,
                                color: colorScheme.onPrimaryContainer,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _driverProfile?['full_name'] ?? 'Sürücü',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                (_driverProfile?['rating'] as num?)
                                        ?.toStringAsFixed(1) ??
                                    '5.0',
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineToggle(ThemeData theme, ColorScheme colorScheme) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _activeRide == null ? _toggleOnlineStatus : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : colorScheme.error,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: (_isOnline ? Colors.green : colorScheme.error)
                      .withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(ThemeData theme, ColorScheme colorScheme) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
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
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              if (_activeRide != null)
                _buildActiveRideCard(theme, colorScheme)
              else if (_isOnline && _pendingRequests.isNotEmpty)
                _buildPendingRequestsList(theme, colorScheme)
              else
                _buildWaitingState(theme, colorScheme),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            _isOnline
                ? Icons.hourglass_empty_rounded
                : Icons.power_settings_new_rounded,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _isOnline
                ? 'Sürüş talebi bekleniyor...'
                : 'Sürüş almak için çevrimiçi olun',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsList(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${_pendingRequests.length} Yeni Sürüş Talebi',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingRequests.length,
            itemBuilder: (context, index) {
              final request = _pendingRequests[index];
              return _buildRideRequestCard(request, theme, colorScheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRideRequestCard(
    Map<String, dynamic> request,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fare & distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(request['fare'] as num?)?.toStringAsFixed(2) ?? '0.00'} TL',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(request['distance_km'] as num?)?.toStringAsFixed(1) ?? '0'} km',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pickup
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request['pickup_address'] ?? '',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dropoff
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request['dropoff_address'] ?? '',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Accept button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _acceptRide(request),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kabul Et'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideCard(ThemeData theme, ColorScheme colorScheme) {
    if (_currentRide == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _currentRide!.status.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(_currentRide!.status),
                  color: _currentRide!.status.color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _getDriverStatusText(_currentRide!.status),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _currentRide!.status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer info with pulse animation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Animated customer avatar
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _currentRide!.status == RideStatus.accepted
                          ? 0.9 + (_pulseAnimation.value - 1.0) * 0.1
                          : 1.0,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.blue,
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
                        _activeRide?['customer_name'] ?? 'Müşteri',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentRide!.fare.toStringAsFixed(2)} TL',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.route_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentRide!.distanceKm.toStringAsFixed(1)} km',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Call button
                IconButton(
                  onPressed: _callCustomer,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                  ),
                  icon: const Icon(Icons.phone_rounded, color: Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Locations
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildLocationRow(
                  icon: Icons.circle,
                  iconColor: Colors.green,
                  label: 'Alış Noktası',
                  address: _currentRide!.pickup.address,
                  theme: theme,
                  colorScheme: colorScheme,
                  isActive: _currentRide!.status == RideStatus.accepted,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: colorScheme.outlineVariant,
                  ),
                ),
                _buildLocationRow(
                  icon: Icons.flag_rounded,
                  iconColor: Colors.red,
                  label: 'Varış Noktası',
                  address: _currentRide!.dropoff.address,
                  theme: theme,
                  colorScheme: colorScheme,
                  isActive: _currentRide!.status == RideStatus.inProgress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Navigation button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openNavigation,
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Navigasyon'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Main action button
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _getMainAction(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _getMainActionColor(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_getMainActionText()),
                ),
              ),
            ],
          ),

          // Cancel button (only if not in progress)
          if (_currentRide!.status != RideStatus.inProgress)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: _cancelRide,
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                child: const Text('Sürüşü İptal Et'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required ThemeData theme,
    required ColorScheme colorScheme,
    bool isActive = false,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive
                ? iconColor.withValues(alpha: 0.2)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.accepted:
        return Icons.directions_car_rounded;
      case RideStatus.arrived:
        return Icons.place_rounded;
      case RideStatus.inProgress:
        return Icons.navigation_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  String _getDriverStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.accepted:
        return 'Müşteriye Gidiliyor';
      case RideStatus.arrived:
        return 'Müşteri Bekleniyor';
      case RideStatus.inProgress:
        return 'Yolculuk Devam Ediyor';
      default:
        return 'Bilinmeyen Durum';
    }
  }

  VoidCallback? _getMainAction() {
    switch (_currentRide?.status) {
      case RideStatus.accepted:
        return _arriveAtPickup;
      case RideStatus.arrived:
        return _startRide;
      case RideStatus.inProgress:
        return _completeRide;
      default:
        return null;
    }
  }

  String _getMainActionText() {
    switch (_currentRide?.status) {
      case RideStatus.accepted:
        return 'Vardım';
      case RideStatus.arrived:
        return 'Yolculuğu Başlat';
      case RideStatus.inProgress:
        return 'Yolculuğu Tamamla';
      default:
        return '';
    }
  }

  Color _getMainActionColor() {
    switch (_currentRide?.status) {
      case RideStatus.accepted:
        return Colors.blue;
      case RideStatus.arrived:
        return Colors.green;
      case RideStatus.inProgress:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Set<gmaps.Marker> _buildMarkers() {
    final markers = <gmaps.Marker>{};

    if (_currentRide != null) {
      // Pickup marker (müşteri konumu - nabızlı insan ikonu)
      if (_currentRide!.status == RideStatus.accepted ||
          _currentRide!.status == RideStatus.arrived) {
        markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('customer'),
            position: gmaps.LatLng(
              _currentRide!.pickup.latitude,
              _currentRide!.pickup.longitude,
            ),
            icon:
                _customerMarker ??
                gmaps.BitmapDescriptor.defaultMarkerWithHue(
                  gmaps.BitmapDescriptor.hueBlue,
                ),
            anchor: const Offset(0.5, 0.5),
            infoWindow: gmaps.InfoWindow(
              title: 'Müşteri',
              snippet: _currentRide!.pickup.address,
            ),
          ),
        );
      }

      // Yolculuk devam ediyorsa alış noktasını yeşil pin olarak göster
      if (_currentRide!.status == RideStatus.inProgress) {
        markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('pickup'),
            position: gmaps.LatLng(
              _currentRide!.pickup.latitude,
              _currentRide!.pickup.longitude,
            ),
            icon:
                _pickupMarker ??
                gmaps.BitmapDescriptor.defaultMarkerWithHue(
                  gmaps.BitmapDescriptor.hueGreen,
                ),
            anchor: const Offset(0.5, 0.9),
            infoWindow: gmaps.InfoWindow(
              title: 'Alış Noktası',
              snippet: _currentRide!.pickup.address,
            ),
          ),
        );
      }

      // Dropoff marker
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('dropoff'),
          position: gmaps.LatLng(
            _currentRide!.dropoff.latitude,
            _currentRide!.dropoff.longitude,
          ),
          icon:
              _dropoffMarker ??
              gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueRed,
              ),
          anchor: const Offset(0.5, 0.9),
          infoWindow: gmaps.InfoWindow(
            title: 'Varış Noktası',
            snippet: _currentRide!.dropoff.address,
          ),
        ),
      );
    }

    return markers;
  }

  Set<gmaps.Polyline> _buildPolylines() {
    if (_currentRide == null) return {};

    return {
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route'),
        points: [
          gmaps.LatLng(_currentLat, _currentLng),
          if (_currentRide!.status == RideStatus.accepted ||
              _currentRide!.status == RideStatus.arrived)
            gmaps.LatLng(
              _currentRide!.pickup.latitude,
              _currentRide!.pickup.longitude,
            ),
          gmaps.LatLng(
            _currentRide!.dropoff.latitude,
            _currentRide!.dropoff.longitude,
          ),
        ],
        color: Theme.of(context).colorScheme.primary,
        width: 4,
        patterns: [gmaps.PatternItem.dash(15), gmaps.PatternItem.gap(8)],
      ),
    };
  }
}

class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder2({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
