import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/google_places_service.dart';
import '../../models/taxi/taxi_models.dart';
import '../../core/utils/app_dialogs.dart';
import 'taxi_vehicle_selection_screen.dart';

class TaxiDestinationScreen extends ConsumerStatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? dropoffAddress;
  final bool isScheduleMode;

  const TaxiDestinationScreen({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.dropoffAddress,
    this.isScheduleMode = false,
  });

  @override
  ConsumerState<TaxiDestinationScreen> createState() => _TaxiDestinationScreenState();
}

class _TaxiDestinationScreenState extends ConsumerState<TaxiDestinationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _dropoffFocus = FocusNode();

  gmaps.GoogleMapController? _mapController;

  late TaxiLocation _pickup;
  TaxiLocation? _dropoff;

  bool _isSearchingPickup = false;
  bool _isSearchingDropoff = true;
  List<TaxiLocation> _searchResults = [];
  bool _isLoading = false;
  List<gmaps.LatLng> _routePoints = [];

  // Animations
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Saved locations
  final List<TaxiLocation> _savedLocations = [
    const TaxiLocation(
      id: 'home',
      name: 'Ev',
      address: 'Kayıtlı ev adresiniz',
      latitude: 41.0082,
      longitude: 28.9784,
      type: 'home',
      icon: Icons.home_rounded,
    ),
    const TaxiLocation(
      id: 'work',
      name: 'İş',
      address: 'Kayıtlı iş adresiniz',
      latitude: 41.0422,
      longitude: 29.0083,
      type: 'work',
      icon: Icons.work_rounded,
    ),
  ];

  // Recent locations
  final List<TaxiLocation> _recentLocations = [
    const TaxiLocation(
      name: 'İstanbul Havalimanı',
      address: 'Tayakadın, Terminal Caddesi No:1',
      latitude: 41.2608,
      longitude: 28.7418,
      type: 'recent',
    ),
    const TaxiLocation(
      name: 'Taksim Meydanı',
      address: 'Beyoğlu, İstanbul',
      latitude: 41.0370,
      longitude: 28.9850,
      type: 'recent',
    ),
    const TaxiLocation(
      name: 'Kadıköy İskelesi',
      address: 'Caferağa, Kadıköy',
      latitude: 40.9906,
      longitude: 29.0237,
      type: 'recent',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pickup = TaxiLocation(
      name: 'Mevcut Konum',
      address: widget.pickupAddress,
      latitude: widget.pickupLat,
      longitude: widget.pickupLng,
    );

    _pickupController.text = widget.pickupAddress;

    if (widget.dropoffLat != null && widget.dropoffAddress != null) {
      _dropoff = TaxiLocation(
        name: widget.dropoffAddress!,
        address: widget.dropoffAddress!,
        latitude: widget.dropoffLat!,
        longitude: widget.dropoffLng!,
      );
      _dropoffController.text = widget.dropoffAddress!;
      _isSearchingDropoff = false;
    }

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _fadeController.forward();

    // Auto focus dropoff
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dropoff == null) {
        _dropoffFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final predictions = await GooglePlacesService.getAutocompletePredictions(
        input: query,
        location: '${widget.pickupLat},${widget.pickupLng}',
      );

      final results = <TaxiLocation>[];
      for (final prediction in predictions.take(5)) {
        // Nominatim sonuçları koordinat içerir
        if (prediction.hasCoordinates) {
          results.add(TaxiLocation(
            id: prediction.placeId,
            name: prediction.mainText,
            address: prediction.description,
            latitude: prediction.latitude!,
            longitude: prediction.longitude!,
            type: 'search',
          ));
        } else {
          // Google Places için detay çek
          final details = await GooglePlacesService.getPlaceDetails(
            placeId: prediction.placeId,
          );
          if (details != null) {
            results.add(TaxiLocation(
              id: prediction.placeId,
              name: prediction.mainText,
              address: prediction.description,
              latitude: details.latitude,
              longitude: details.longitude,
              type: 'search',
            ));
          }
        }
      }

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  void _selectLocation(TaxiLocation location) {
    if (_isSearchingPickup) {
      setState(() {
        _pickup = location;
        _pickupController.text = location.address;
        _isSearchingPickup = false;
        _searchResults = [];
      });
    } else {
      setState(() {
        _dropoff = location;
        _dropoffController.text = location.address;
        _isSearchingDropoff = false;
        _searchResults = [];
      });
    }

    _updateMapCamera();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    if (_dropoff == null || !mounted) return;

    try {
      final result = await GooglePlacesService.getDirections(
        originLat: _pickup.latitude,
        originLng: _pickup.longitude,
        destLat: _dropoff!.latitude,
        destLng: _dropoff!.longitude,
      ).timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (result != null && mounted) {
        setState(() {
          _routePoints = result.routePoints
              .map((p) => gmaps.LatLng(p.latitude, p.longitude))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading route: $e');
      // Hata durumunda düz çizgi kullanılacak (polylines metodunda fallback var)
    }
  }

  void _updateMapCamera() {
    if (_mapController == null) return;

    if (_dropoff != null) {
      // Show both markers
      final bounds = gmaps.LatLngBounds(
        southwest: gmaps.LatLng(
          _pickup.latitude < _dropoff!.latitude ? _pickup.latitude : _dropoff!.latitude,
          _pickup.longitude < _dropoff!.longitude ? _pickup.longitude : _dropoff!.longitude,
        ),
        northeast: gmaps.LatLng(
          _pickup.latitude > _dropoff!.latitude ? _pickup.latitude : _dropoff!.latitude,
          _pickup.longitude > _dropoff!.longitude ? _pickup.longitude : _dropoff!.longitude,
        ),
      );
      _mapController!.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 80));
    } else {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(_pickup.latitude, _pickup.longitude),
          15,
        ),
      );
    }
  }

  void _swapLocations() {
    if (_dropoff == null) return;

    setState(() {
      final temp = _pickup;
      _pickup = _dropoff!;
      _dropoff = temp;
      _pickupController.text = _pickup.address;
      _dropoffController.text = _dropoff!.address;
    });

    _updateMapCamera();
  }

  Future<void> _proceedToVehicleSelection() async {
    if (_dropoff == null) {
      await AppDialogs.showWarning(context, 'Lütfen varış noktası seçin');
      return;
    }

    // Schedule mode ise araç seçimi ekranına git ve sonucu döndür
    if (widget.isScheduleMode) {
      if (!mounted) return;

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => TaxiVehicleSelectionScreen(
            pickup: _pickup,
            dropoff: _dropoff!,
            isScheduleMode: true,
          ),
        ),
      );

      if (!mounted) return;

      // Sonuç varsa schedule ekranına döndür
      if (result != null) {
        Navigator.of(context).pop({
          'lat': _dropoff!.latitude,
          'lng': _dropoff!.longitude,
          'address': _dropoff!.address,
          'name': _dropoff!.name,
          'vehicleTypeId': result['vehicleTypeId'],
          'vehicleTypeName': result['vehicleTypeName'],
          'estimatedFare': result['estimatedFare'],
          'estimatedDistanceKm': result['estimatedDistanceKm'],
          'estimatedDurationMinutes': result['estimatedDurationMinutes'],
        });
      }
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TaxiVehicleSelectionScreen(
          pickup: _pickup,
          dropoff: _dropoff!,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
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
          Positioned.fill(
            child: gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: gmaps.LatLng(widget.pickupLat, widget.pickupLng),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Flutter Web'de map hazır olana kadar bekle
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && _mapController != null) {
                    _updateMapCamera();
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

          // Top UI
          SafeArea(
            child: Column(
              children: [
                // Search Card
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      color: colorScheme.onSurface,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Nereye gidiyorsunuz?',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_dropoff != null)
                                  GestureDetector(
                                    onTap: _swapLocations,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.swap_vert_rounded,
                                        color: colorScheme.onPrimaryContainer,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Location inputs
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Icons column
                                Column(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    Container(
                                      width: 2,
                                      height: 30,
                                      color: colorScheme.outlineVariant,
                                    ),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Inputs column
                                Expanded(
                                  child: Column(
                                    children: [
                                      // Pickup input
                                      TextField(
                                        controller: _pickupController,
                                        focusNode: _pickupFocus,
                                        onTap: () {
                                          setState(() {
                                            _isSearchingPickup = true;
                                            _isSearchingDropoff = false;
                                          });
                                        },
                                        onChanged: _searchLocation,
                                        decoration: InputDecoration(
                                          hintText: 'Nereden?',
                                          hintStyle: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      Divider(
                                        color: colorScheme.outlineVariant,
                                        height: 16,
                                      ),
                                      // Dropoff input
                                      TextField(
                                        controller: _dropoffController,
                                        focusNode: _dropoffFocus,
                                        onTap: () {
                                          setState(() {
                                            _isSearchingPickup = false;
                                            _isSearchingDropoff = true;
                                          });
                                        },
                                        onChanged: _searchLocation,
                                        decoration: InputDecoration(
                                          hintText: 'Nereye?',
                                          hintStyle: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Search results or suggestions
                if (_isSearchingPickup || _isSearchingDropoff)
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _searchResults.isNotEmpty
                                ? _buildSearchResults()
                                : _buildSuggestions(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom button
          if (_dropoff != null && !_isSearchingPickup && !_isSearchingDropoff)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _proceedToVehicleSelection,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_taxi_rounded,
                              color: colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Araç Seç',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Set<gmaps.Marker> _buildMarkers() {
    final markers = <gmaps.Marker>{};

    markers.add(gmaps.Marker(
      markerId: const gmaps.MarkerId('pickup'),
      position: gmaps.LatLng(_pickup.latitude, _pickup.longitude),
      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
      infoWindow: gmaps.InfoWindow(title: 'Alış', snippet: _pickup.address),
    ));

    if (_dropoff != null) {
      markers.add(gmaps.Marker(
        markerId: const gmaps.MarkerId('dropoff'),
        position: gmaps.LatLng(_dropoff!.latitude, _dropoff!.longitude),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
        infoWindow: gmaps.InfoWindow(title: 'Varış', snippet: _dropoff!.address),
      ));
    }

    return markers;
  }

  Set<gmaps.Polyline> _buildPolylines() {
    if (_dropoff == null) return {};

    // Gerçek rota varsa onu kullan
    if (_routePoints.isNotEmpty) {
      return {
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          points: _routePoints,
          color: Theme.of(context).colorScheme.primary,
          width: 5,
        ),
      };
    }

    // Fallback: düz çizgi (kesikli)
    return {
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route'),
        points: [
          gmaps.LatLng(_pickup.latitude, _pickup.longitude),
          gmaps.LatLng(_dropoff!.latitude, _dropoff!.longitude),
        ],
        color: Theme.of(context).colorScheme.primary,
        width: 4,
        patterns: [gmaps.PatternItem.dash(20), gmaps.PatternItem.gap(10)],
      ),
    };
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final location = _searchResults[index];
        return _buildLocationItem(
          location: location,
          icon: Icons.location_on_rounded,
          iconColor: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }

  Widget _buildSuggestions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Saved locations
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Kayıtlı Konumlar',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ..._savedLocations.map((location) => _buildLocationItem(
          location: location,
          icon: location.icon ?? Icons.place_rounded,
          iconColor: colorScheme.primary,
        )),

        const Divider(height: 24),

        // Recent locations
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Son Aramalar',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ..._recentLocations.map((location) => _buildLocationItem(
          location: location,
          icon: Icons.history_rounded,
          iconColor: colorScheme.onSurfaceVariant,
        )),
      ],
    );
  }

  Widget _buildLocationItem({
    required TaxiLocation location,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectLocation(location),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location.address,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
