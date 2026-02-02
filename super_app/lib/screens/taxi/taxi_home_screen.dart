import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../../core/theme/app_responsive.dart';

import '../../core/services/taxi_service.dart';
import '../../services/location_service.dart';
import '../../services/google_places_service.dart';
import 'taxi_destination_screen.dart';
import '../../models/taxi/taxi_models.dart';
import '../../core/services/supabase_service.dart';
import 'taxi_ride_screen.dart' hide AnimatedBuilder;
import 'taxi_searching_screen.dart' hide AnimatedBuilder;
import 'taxi_driver_screen.dart' hide AnimatedBuilder, AnimatedBuilder2;

class TaxiHomeScreen extends ConsumerStatefulWidget {
  const TaxiHomeScreen({super.key});

  @override
  ConsumerState<TaxiHomeScreen> createState() => _TaxiHomeScreenState();
}

class _TaxiHomeScreenState extends ConsumerState<TaxiHomeScreen>
    with TickerProviderStateMixin {
  // Controllers
  gmaps.GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Location
  final LocationService _locationService = LocationService();
  double _currentLat = LocationService.defaultLat;
  double _currentLng = LocationService.defaultLng;
  String _currentAddress = 'Konum alınıyor...';
  bool _isLoadingLocation = true;

  // Drivers
  final Set<gmaps.Marker> _markers = {};
  int _nearbyDriverCount = 0;
  int? _nearestDriverETA;

  // Locations
  List<Map<String, dynamic>> _recentLocations = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getCurrentLocation();
    _loadSavedLocations();
    _checkActiveRide();
  }

  Future<void> _checkActiveRide() async {
    if (!SupabaseService.isLoggedIn) return;

    try {
      final rideData = await TaxiService.getActiveRide();
      if (rideData != null && mounted) {
        final ride = TaxiRide.fromJson(rideData);

        if (ride.status == RideStatus.pending && ride.vehicleTypeId != null) {
          // Fetch vehicle types to find the correct one
          try {
            final vehicleTypes = await TaxiService.getVehicleTypes();
            final vehicleTypeData = vehicleTypes.firstWhere(
              (v) => v['id'] == ride.vehicleTypeId,
              orElse: () => vehicleTypes.first,
            );
            final vehicleType = VehicleType.fromJson(vehicleTypeData);

            if (mounted) {
              Navigator.pushReplacement(
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
            }
          } catch (e) {
            debugPrint('Error restoring search screen: $e');
          }
        } else if (ride.status != RideStatus.completed &&
            ride.status != RideStatus.cancelled) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TaxiRideScreen(ride: ride)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking active ride: $e');
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final result = await _locationService.getCurrentLocationWithAddress();

      if (mounted && result.position != null) {
        setState(() {
          _currentLat = result.position!.latitude;
          _currentLng = result.position!.longitude;
          _currentAddress = result.address ?? 'Konum bulundu';
          _isLoadingLocation = false;
        });

        _animateToLocation();
        _loadNearbyDrivers();
      } else if (mounted) {
        setState(() {
          _currentAddress = LocationService.defaultAddress;
          _isLoadingLocation = false;
        });
        _loadNearbyDrivers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = LocationService.defaultAddress;
          _isLoadingLocation = false;
        });
        _loadNearbyDrivers();
      }
    }
  }

  void _animateToLocation() {
    _mapController?.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: gmaps.LatLng(_currentLat, _currentLng),
          zoom: 15,
        ),
      ),
    );
  }

  Future<void> _loadNearbyDrivers() async {
    try {
      final drivers = await TaxiService.getNearbyDrivers(
        latitude: _currentLat,
        longitude: _currentLng,
        radiusKm: 5,
      );

      if (!mounted) return;

      _markers.clear();
      final random = math.Random();

      double? nearestLat, nearestLng;
      double minDistance = double.infinity;

      for (final driver in drivers.take(15)) {
        final lat =
            (driver['current_latitude'] as num?)?.toDouble() ??
            _currentLat + (random.nextDouble() - 0.5) * 0.02;
        final lng =
            (driver['current_longitude'] as num?)?.toDouble() ??
            _currentLng + (random.nextDouble() - 0.5) * 0.02;

        final distance = _calculateDistance(_currentLat, _currentLng, lat, lng);
        if (distance < minDistance) {
          minDistance = distance;
          nearestLat = lat;
          nearestLng = lng;
        }

        _markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId('driver_${driver['id']}'),
            position: gmaps.LatLng(lat, lng),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueOrange,
            ),
            rotation: random.nextDouble() * 360,
          ),
        );
      }

      _nearbyDriverCount = drivers.length;

      if (nearestLat != null && nearestLng != null) {
        await _fetchNearestDriverETA(nearestLat, nearestLng);
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    }
  }

  Future<void> _fetchNearestDriverETA(
    double driverLat,
    double driverLng,
  ) async {
    try {
      final directions = await GooglePlacesService.getDirections(
        originLat: driverLat,
        originLng: driverLng,
        destLat: _currentLat,
        destLng: _currentLng,
      );

      if (directions != null && mounted) {
        setState(() {
          _nearestDriverETA = directions.durationMinutes.clamp(1, 30);
        });
      } else if (mounted) {
        final distance = _calculateDistance(
          driverLat,
          driverLng,
          _currentLat,
          _currentLng,
        );
        setState(() {
          _nearestDriverETA = (distance * 2.5).ceil().clamp(1, 30);
        });
      }
    } catch (e) {
      debugPrint('Error fetching ETA: $e');
    }
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  Future<void> _loadSavedLocations() async {
    try {
      final recent = await TaxiService.getRecentLocations();
      if (mounted) {
        setState(() {
          _recentLocations = recent;
        });
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
    }
  }

  void _openDestinationScreen() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TaxiDestinationScreen(
              pickupLat: _currentLat,
              pickupLng: _currentLng,
              pickupAddress: _currentAddress,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _sheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Map
            _buildMap(isDark),

            // Top bar
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildTopBar(isDark),
            ),

            // ETA badge
            if (_nearestDriverETA != null && !_isLoadingLocation)
              _buildETABadge(isDark),

            // Recenter button
            Positioned(
              right: 16,
              bottom: size.height * 0.48 + 20,
              child: _buildRecenterButton(isDark),
            ),

            // Bottom sheet
            _buildBottomSheet(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(_currentLat, _currentLng),
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      style: isDark ? _darkMapStyle : null,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.45,
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH, vertical: 8),
        child: Row(
          children: [
            _buildCircleButton(
              icon: Icons.arrow_back,
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            // Sürücü modu butonu
            _buildCircleButton(
              icon: Icons.local_taxi_outlined,
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TaxiDriverScreen(),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildCircleButton(
              icon: Icons.person_outline,
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: isDark ? Colors.white : Colors.black87,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildETABadge(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDark ? const Color(0xFF2A2A3E) : Colors.white,
                isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F8F8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value * 0.1 + 0.9,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_taxi,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_nearestDriverETA dk içinde',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_nearbyDriverCount sürücü yakınınızda',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecenterButton(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Material(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        elevation: 6,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _animateToLocation();
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            child: const Icon(Icons.my_location, color: Colors.blue, size: 26),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.48,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      controller: _sheetController,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SlideTransition(
            position: _slideAnimation,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Location inputs
                _buildLocationInputs(isDark),

                const SizedBox(height: 24),

                // Quick actions
                _buildQuickActions(isDark),

                const SizedBox(height: 28),

                // Saved locations
                _buildSavedLocations(isDark),

                const SizedBox(height: 24),

                // Recent locations
                _buildRecentLocations(isDark),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationInputs(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH),
      child: GestureDetector(
        onTap: _openDestinationScreen,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252538) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              // Pickup location
              _buildLocationRow(
                iconColor: Colors.green,
                title: 'Bulunduğunuz Konum',
                subtitle: _isLoadingLocation
                    ? 'Konum alınıyor...'
                    : _currentAddress,
                isDark: isDark,
                isLoading: _isLoadingLocation,
              ),

              // Divider
              Row(
                children: [
                  const SizedBox(width: 26),
                  Column(
                    children: List.generate(
                      3,
                      (index) => Container(
                        width: 2,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[400],
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 14, right: 20),
                      color: isDark ? Colors.white10 : Colors.grey[200],
                    ),
                  ),
                ],
              ),

              // Destination
              _buildLocationRow(
                iconColor: Colors.red,
                title: '',
                subtitle: 'Nereye gitmek istiyorsunuz?',
                isDark: isDark,
                isDestination: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    bool isLoading = false,
    bool isDestination = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isDestination ? 16 : 15,
                    fontWeight: isDestination
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isDestination
                        ? (isDark ? Colors.white70 : Colors.grey[700])
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isDestination)
            Icon(
              Icons.search,
              color: isDark ? Colors.white38 : Colors.grey[400],
              size: 22,
            )
          else
            const Icon(Icons.my_location, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH),
      child: _buildPrimaryActionCard(
        icon: Icons.bolt,
        label: 'Şimdi Git',
        sublabel: _nearestDriverETA != null
            ? '$_nearestDriverETA dk'
            : 'Hemen',
        isDark: isDark,
        onTap: _openDestinationScreen,
      ),
    );
  }

  Widget _buildPrimaryActionCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sublabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedLocations(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Kayıtlı Konumlar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildSavedLocationCard(
                icon: Icons.home_rounded,
                label: 'Ev',
                color: Colors.blue,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildSavedLocationCard(
                icon: Icons.work_rounded,
                label: 'İş',
                color: Colors.orange,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildAddLocationCard(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedLocationCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252538) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddLocationCard(bool isDark) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252538) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.add, color: Colors.blue, size: 24),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ekle',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLocations(bool isDark) {
    if (_recentLocations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Son Gidilen Yerler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._recentLocations
            .take(5)
            .map((location) => _buildRecentLocationItem(location, isDark)),
      ],
    );
  }

  Widget _buildRecentLocationItem(Map<String, dynamic> location, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TaxiDestinationScreen(
                pickupLat: _currentLat,
                pickupLng: _currentLng,
                pickupAddress: _currentAddress,
                dropoffLat: (location['latitude'] as num?)?.toDouble(),
                dropoffLng: (location['longitude'] as num?)?.toDouble(),
                dropoffAddress: location['address'] as String?,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.history,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location['name'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location['address'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isDark ? Colors.white24 : Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _darkMapStyle = '''
    [
      {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
      {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
      {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
      {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
      {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c6675"}]},
      {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]}
    ]
  ''';
}
