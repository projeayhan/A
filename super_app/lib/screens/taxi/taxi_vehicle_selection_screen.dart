import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/taxi/taxi_models.dart';
import '../../services/google_places_service.dart';
import '../../core/services/taxi_service.dart';
import 'taxi_searching_screen.dart';

class TaxiVehicleSelectionScreen extends ConsumerStatefulWidget {
  final TaxiLocation pickup;
  final TaxiLocation dropoff;
  final bool isScheduleMode;

  const TaxiVehicleSelectionScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.isScheduleMode = false,
  });

  @override
  ConsumerState<TaxiVehicleSelectionScreen> createState() => _TaxiVehicleSelectionScreenState();
}

class _TaxiVehicleSelectionScreenState extends ConsumerState<TaxiVehicleSelectionScreen>
    with TickerProviderStateMixin {
  gmaps.GoogleMapController? _mapController;

  // Route info
  double? _distanceKm;
  int? _durationMinutes;
  List<gmaps.LatLng> _routePoints = [];

  // Selected vehicle
  int _selectedVehicleIndex = 0;

  // Animations
  late AnimationController _slideController;
  late AnimationController _cardController;
  late Animation<Offset> _slideAnimation;

  // Vehicle types - veritabanından yüklenecek
  List<VehicleType> _vehicleTypes = [];
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
    _cardController.forward();

    _loadVehicleTypes();
    _loadRouteInfo();
  }

  Future<void> _loadVehicleTypes() async {
    if (!mounted) return;

    try {
      final vehicleTypesData = await TaxiService.getVehicleTypes()
          .timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]);

      if (!mounted) return;

      if (vehicleTypesData.isEmpty) {
        setState(() => _isLoadingVehicles = false);
        _showErrorSnackBar('Araç tipleri yüklenemedi');
        return;
      }

      setState(() {
        _vehicleTypes = vehicleTypesData
            .map((data) => VehicleType.fromJson(data))
            .toList();
        _isLoadingVehicles = false;
      });
      // Kartları yeniden animasyonla göster
      _cardController.reset();
      _cardController.forward();
    } catch (e) {
      debugPrint('Error loading vehicle types: $e');
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
        _showErrorSnackBar('Araç tipleri yüklenemedi: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _cardController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadRouteInfo() async {
    if (!mounted) return;

    try {
      final result = await GooglePlacesService.getDirections(
        originLat: widget.pickup.latitude,
        originLng: widget.pickup.longitude,
        destLat: widget.dropoff.latitude,
        destLng: widget.dropoff.longitude,
      ).timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (result != null && mounted) {
        setState(() {
          _distanceKm = result.distanceKm;
          _durationMinutes = result.durationMinutes;
          _routePoints = result.routePoints
              .map((p) => gmaps.LatLng(p.latitude, p.longitude))
              .toList();
        });

        // Map controller hazırsa bounds'u ayarla
        if (_mapController != null) {
          _fitMapToBounds();
        }
      } else if (mounted) {
        // Timeout veya null sonuç - fallback kullan
        _useFallbackDistance();
      }
    } catch (e) {
      // Fallback to straight line distance
      debugPrint('Error loading route info: $e');
      _useFallbackDistance();
    }
  }

  void _useFallbackDistance() {
    if (!mounted) return;
    setState(() {
      _distanceKm = _calculateStraightLineDistance();
      _durationMinutes = (_distanceKm! * 2).round(); // ~30 km/h average
    });
  }

  double _calculateStraightLineDistance() {
    // Haversine formula approximation
    const double earthRadius = 6371; // km
    final dLat = _toRadians(widget.dropoff.latitude - widget.pickup.latitude);
    final dLng = _toRadians(widget.dropoff.longitude - widget.pickup.longitude);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(widget.pickup.latitude)) *
        _cos(_toRadians(widget.dropoff.latitude)) *
        _sin(dLng / 2) * _sin(dLng / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * 3.14159265359 / 180;
  double _sin(double x) => _sinApprox(x);
  double _cos(double x) => _sinApprox(x + 1.5707963268);
  double _sqrt(double x) => x > 0 ? _newtonSqrt(x) : 0;
  double _atan2(double y, double x) => _atan2Approx(y, x);

  double _sinApprox(double x) {
    x = x % (2 * 3.14159265359);
    if (x < 0) x += 2 * 3.14159265359;
    if (x > 3.14159265359) {
      x -= 3.14159265359;
      return -_sinApproxPositive(x);
    }
    return _sinApproxPositive(x);
  }

  double _sinApproxPositive(double x) {
    if (x > 1.5707963268) x = 3.14159265359 - x;
    final x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }

  double _newtonSqrt(double x) {
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2Approx(double y, double x) {
    if (x > 0) return _atanApprox(y / x);
    if (x < 0 && y >= 0) return _atanApprox(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atanApprox(y / x) - 3.14159265359;
    if (y > 0) return 1.5707963268;
    if (y < 0) return -1.5707963268;
    return 0;
  }

  double _atanApprox(double x) {
    if (x > 1) return 1.5707963268 - _atanApprox(1 / x);
    if (x < -1) return -1.5707963268 - _atanApprox(1 / x);
    final x2 = x * x;
    return x * (1 - x2 / 3 * (1 - x2 / 5 * (1 - x2 / 7)));
  }

  void _fitMapToBounds() {
    if (_mapController == null) return;

    final bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(
        widget.pickup.latitude < widget.dropoff.latitude
            ? widget.pickup.latitude : widget.dropoff.latitude,
        widget.pickup.longitude < widget.dropoff.longitude
            ? widget.pickup.longitude : widget.dropoff.longitude,
      ),
      northeast: gmaps.LatLng(
        widget.pickup.latitude > widget.dropoff.latitude
            ? widget.pickup.latitude : widget.dropoff.latitude,
        widget.pickup.longitude > widget.dropoff.longitude
            ? widget.pickup.longitude : widget.dropoff.longitude,
      ),
    );

    _mapController!.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  double _calculateFare(VehicleType vehicle) {
    if (_distanceKm == null || _durationMinutes == null) return 0;
    return vehicle.calculateFare(_distanceKm!, _durationMinutes!);
  }

  void _proceedToSearch() {
    if (_vehicleTypes.isEmpty) return;

    final selectedVehicle = _vehicleTypes[_selectedVehicleIndex];
    final fare = _calculateFare(selectedVehicle);

    // Schedule mode ise araç bilgilerini döndür
    if (widget.isScheduleMode) {
      Navigator.of(context).pop({
        'vehicleTypeId': selectedVehicle.id,
        'vehicleTypeName': selectedVehicle.displayName,
        'estimatedFare': fare,
        'estimatedDistanceKm': _distanceKm ?? 0.0,
        'estimatedDurationMinutes': _durationMinutes ?? 0,
      });
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TaxiSearchingScreen(
          pickup: widget.pickup,
          dropoff: widget.dropoff,
          vehicleType: selectedVehicle,
          fare: fare,
          distanceKm: _distanceKm ?? 0,
          durationMinutes: _durationMinutes ?? 0,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Map
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.45,
            child: gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: gmaps.LatLng(
                  (widget.pickup.latitude + widget.dropoff.latitude) / 2,
                  (widget.pickup.longitude + widget.dropoff.longitude) / 2,
                ),
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Flutter Web'de map hazır olana kadar bekle
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && _mapController != null) {
                    _fitMapToBounds();
                  }
                });
              },
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
          ),

          // Route info badge
          if (_distanceKm != null && _durationMinutes != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.route_rounded,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_distanceKm!.toStringAsFixed(1)} km',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Icon(
                      Icons.access_time_rounded,
                      color: colorScheme.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_durationMinutes dk',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom sheet
          Positioned(
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

                    // Title
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Text(
                            'Araç Seçin',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_distanceKm != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_vehicleTypes.length} seçenek',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Vehicle list
                    SizedBox(
                      height: 180,
                      child: _isLoadingVehicles
                          ? Center(
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
                              ),
                            )
                          : _vehicleTypes.isEmpty
                              ? Center(
                                  child: Text(
                                    'Araç tipi bulunamadı',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _vehicleTypes.length,
                                  itemBuilder: (context, index) {
                                    return _buildVehicleCard(index);
                                  },
                                ),
                    ),

                    const SizedBox(height: 16),

                    // Confirm button
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        MediaQuery.of(context).padding.bottom + 20,
                      ),
                      child: _buildConfirmButton(),
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

  Widget _buildVehicleCard(int index) {
    final vehicle = _vehicleTypes[index];
    final isSelected = _selectedVehicleIndex == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fare = _calculateFare(vehicle);

    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, child) {
        final delay = index * 0.15;
        final progress = ((_cardController.value - delay) / (1 - delay)).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, 30 * (1 - progress)),
          child: Opacity(
            opacity: progress,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => setState(() => _selectedVehicleIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? vehicle.color.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? vehicle.color : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: vehicle.color.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: vehicle.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      vehicle.icon,
                      color: vehicle.color,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: vehicle.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                vehicle.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? vehicle.color : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${vehicle.capacity} kişi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (fare > 0)
                Text(
                  '₺${fare.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? vehicle.color : colorScheme.primary,
                  ),
                )
              else
                SizedBox(
                  height: 16,
                  width: 60,
                  child: LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_vehicleTypes.isEmpty || _isLoadingVehicles) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    final selectedVehicle = _vehicleTypes[_selectedVehicleIndex];
    final fare = _calculateFare(selectedVehicle);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            selectedVehicle.color,
            selectedVehicle.color.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: selectedVehicle.color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _distanceKm != null ? _proceedToSearch : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedVehicle.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (fare > 0)
                      Text(
                        widget.isScheduleMode ? 'Bu aracı seç' : 'Tahmini ücret',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (fare > 0)
                  Text(
                    '₺${fare.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Set<gmaps.Marker> _buildMarkers() {
    return {
      gmaps.Marker(
        markerId: const gmaps.MarkerId('pickup'),
        position: gmaps.LatLng(widget.pickup.latitude, widget.pickup.longitude),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
        infoWindow: gmaps.InfoWindow(title: 'Alış', snippet: widget.pickup.address),
      ),
      gmaps.Marker(
        markerId: const gmaps.MarkerId('dropoff'),
        position: gmaps.LatLng(widget.dropoff.latitude, widget.dropoff.longitude),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
        infoWindow: gmaps.InfoWindow(title: 'Varış', snippet: widget.dropoff.address),
      ),
    };
  }

  Set<gmaps.Polyline> _buildPolylines() {
    final polylineColor = _vehicleTypes.isNotEmpty
        ? _vehicleTypes[_selectedVehicleIndex].color
        : Theme.of(context).colorScheme.primary;

    if (_routePoints.isEmpty) {
      // Fallback to straight line
      return {
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          points: [
            gmaps.LatLng(widget.pickup.latitude, widget.pickup.longitude),
            gmaps.LatLng(widget.dropoff.latitude, widget.dropoff.longitude),
          ],
          color: polylineColor,
          width: 4,
          patterns: [gmaps.PatternItem.dash(20), gmaps.PatternItem.gap(10)],
        ),
      };
    }

    return {
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route'),
        points: _routePoints,
        color: polylineColor,
        width: 5,
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
