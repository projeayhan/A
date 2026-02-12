import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/taxi/taxi_models.dart';
import '../../core/services/taxi_service.dart';
import '../../core/services/communication_service.dart';
import '../../core/utils/app_dialogs.dart';
import '../../services/google_places_service.dart';
import '../../widgets/taxi/animated_map_markers.dart';
import '../../widgets/secure_driver_card.dart';
import 'taxi_rating_screen.dart';

class TaxiRideScreen extends ConsumerStatefulWidget {
  final TaxiRide ride;

  const TaxiRideScreen({super.key, required this.ride});

  @override
  ConsumerState<TaxiRideScreen> createState() => _TaxiRideScreenState();
}

class _TaxiRideScreenState extends ConsumerState<TaxiRideScreen>
    with TickerProviderStateMixin {
  gmaps.GoogleMapController? _mapController;

  late TaxiRide _ride;
  double? _driverLat;
  double? _driverLng;
  List<gmaps.LatLng> _routePoints = [];

  // Realtime channels
  dynamic _rideChannel;
  dynamic _driverLocationChannel;

  // Animations
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _markerPulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _markerPulseAnimation;

  // Custom markers
  gmaps.BitmapDescriptor? _taxiMarker;
  gmaps.BitmapDescriptor? _pickupMarker;
  gmaps.BitmapDescriptor? _dropoffMarker;
  gmaps.BitmapDescriptor? _customerMarker;

  // Gelişmiş realtime taksi takip sistemi
  RealtimeTaxiTracker? _taxiTracker;
  double _driverRotation = 0;
  double _animatedDriverLat = 0;
  double _animatedDriverLng = 0;

  // Progress tracking
  double _routeProgressPercent = 0;

  // ETA tracking
  int? _estimatedArrivalMinutes;
  Timer? _etaUpdateTimer;

  // Kamera takip modu
  bool _followDriver = true;
  bool _isProgrammaticCameraMove = false;
  int _routeRefreshCounter = 0;

  @override
  void initState() {
    super.initState();

    _ride = widget.ride;

    if (_ride.driver != null) {
      _driverLat = _ride.driver!.currentLatitude;
      _driverLng = _ride.driver!.currentLongitude;
      _animatedDriverLat = _driverLat ?? _ride.pickup.latitude;
      _animatedDriverLng = _driverLng ?? _ride.pickup.longitude;
    } else if (_ride.driverId != null) {
      // Sürücü bilgisi yoksa ama ID varsa, bilgileri yükle
      _loadDriverInfo();
    }

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _markerPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _markerPulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _markerPulseController, curve: Curves.easeInOut),
    );

    _slideController.forward();

    _initCustomMarkers();
    _initTaxiTracker();
    _subscribeToUpdates();
    _loadRoute();
    _startEtaUpdates();
  }

  /// Sürücü bilgilerini yükle (driver objesi null ama driverId varsa)
  Future<void> _loadDriverInfo() async {
    if (_ride.driverId == null) return;

    try {
      final driverData = await TaxiService.getDriverById(_ride.driverId!);
      if (driverData != null && mounted) {
        setState(() {
          _ride = _ride.copyWith(driver: TaxiDriver.fromJson(driverData));
          if (_ride.driver != null) {
            _driverLat = _ride.driver!.currentLatitude;
            _driverLng = _ride.driver!.currentLongitude;
            _animatedDriverLat = _driverLat ?? _ride.pickup.latitude;
            _animatedDriverLng = _driverLng ?? _ride.pickup.longitude;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading driver info: $e');
    }
  }

  Future<void> _initCustomMarkers() async {
    // Taksi marker'ı
    _taxiMarker = await AnimatedMapMarkers.createTaxiMarker(
      rotation: _driverRotation,
      color: Colors.amber,
      size: 80,
    );

    // Alış noktası marker'ı
    _pickupMarker = await AnimatedMapMarkers.createPickupMarker(size: 70);

    // Varış noktası marker'ı
    _dropoffMarker = await AnimatedMapMarkers.createDropoffMarker(size: 70);

    // Müşteri marker'ı (nabızlı)
    _customerMarker = await AnimatedMapMarkers.createCustomerMarker(
      color: Colors.blue,
      size: 90,
    );

    if (mounted) setState(() {});
  }

  void _initTaxiTracker() {
    if (_driverLat != null && _driverLng != null) {
      _taxiTracker = RealtimeTaxiTracker(
        rideId: _ride.id,
        initialLat: _driverLat,
        initialLng: _driverLng,
        onLocationUpdate: (lat, lng, rotation) {
          if (mounted) {
            setState(() {
              _animatedDriverLat = lat;
              _animatedDriverLng = lng;
              _driverRotation = rotation;
            });
            // Kamera takip modundaysa haritayı güncelle
            if (_followDriver) {
              _updateMapCamera();
            }
          }
        },
        onEtaUpdate: (etaMinutes) {
          if (mounted) {
            setState(() {
              _estimatedArrivalMinutes = etaMinutes;
            });
          }
        },
        onProgressUpdate: (progressPercent) {
          if (mounted) {
            setState(() {
              _routeProgressPercent = progressPercent;
            });
          }
        },
      );

      // Rota noktalarını ayarla
      if (_routePoints.isNotEmpty) {
        _taxiTracker!.setRoutePoints(_routePoints);
      }
    }
  }

  void _startEtaUpdates() {
    _updateEta();
    _etaUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateEta();
    });
  }

  Future<void> _updateEta() async {
    if (_driverLat == null || _driverLng == null) return;

    try {
      final targetLat = _ride.status == RideStatus.inProgress
          ? _ride.dropoff.latitude
          : _ride.pickup.latitude;
      final targetLng = _ride.status == RideStatus.inProgress
          ? _ride.dropoff.longitude
          : _ride.pickup.longitude;

      final directions = await GooglePlacesService.getDirections(
        originLat: _driverLat!,
        originLng: _driverLng!,
        destLat: targetLat,
        destLng: targetLng,
      );

      if (directions != null && mounted) {
        setState(() {
          _estimatedArrivalMinutes = directions.durationMinutes;
        });
      }
    } catch (e) {
      debugPrint('Error updating ETA: $e');
    }
  }

  Future<void> _loadRoute() async {
    try {
      final result = await GooglePlacesService.getDirections(
        originLat: _ride.pickup.latitude,
        originLng: _ride.pickup.longitude,
        destLat: _ride.dropoff.latitude,
        destLng: _ride.dropoff.longitude,
      );

      if (result != null && mounted) {
        setState(() {
          _routePoints = result.routePoints
              .map((p) => gmaps.LatLng(p.latitude, p.longitude))
              .toList();
        });

        // Tracker'a rota noktalarını ayarla
        _taxiTracker?.setRoutePoints(_routePoints);
      }
    } catch (e) {
      debugPrint('Error loading route: $e');
    }
  }

  Future<void> _loadRouteFromDriver() async {
    if (_driverLat == null || _driverLng == null) return;
    try {
      final destLat = _ride.status == RideStatus.inProgress
          ? _ride.dropoff.latitude
          : _ride.pickup.latitude;
      final destLng = _ride.status == RideStatus.inProgress
          ? _ride.dropoff.longitude
          : _ride.pickup.longitude;

      final result = await GooglePlacesService.getDirections(
        originLat: _driverLat!,
        originLng: _driverLng!,
        destLat: destLat,
        destLng: destLng,
      );
      if (result != null && mounted) {
        setState(() {
          _routePoints = result.routePoints
              .map((p) => gmaps.LatLng(p.latitude, p.longitude))
              .toList();
          _estimatedArrivalMinutes = result.durationMinutes;
        });
        _taxiTracker?.setRoutePoints(_routePoints);
      }
    } catch (e) {
      debugPrint('Error refreshing route from driver: $e');
    }
  }

  Future<void> _shareLocation() async {
    try {
      final link = await CommunicationService.createShareLink(rideId: _ride.id);
      if (link != null && mounted) {
        await SharePlus.instance.share(
          ShareParams(text: 'Yolculugumu canli takip et: ${link.shareUrl}'),
        );
      } else if (mounted) {
        await AppDialogs.showError(context, 'Paylaşım linki oluşturulamadı');
      }
    } catch (e) {
      debugPrint('Share location error: $e');
      if (mounted) {
        await AppDialogs.showError(context, 'Hata: $e');
      }
    }
  }

  Future<void> _sendSos() async {
    await CommunicationService.sendSosToEmergencyContacts(
      context: context,
      rideId: _ride.id,
      driverName: _ride.driver?.fullName,
      vehicleInfo: _ride.driver != null
          ? '${_ride.driver!.vehicleBrand ?? ''} ${_ride.driver!.vehicleModel ?? ''}'.trim()
          : null,
      vehiclePlate: _ride.driver?.vehiclePlate,
      latitude: _ride.pickup.latitude,
      longitude: _ride.pickup.longitude,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _markerPulseController.dispose();
    _mapController?.dispose();
    _taxiTracker?.dispose();
    _etaUpdateTimer?.cancel();
    if (_rideChannel != null) {
      TaxiService.unsubscribe(_rideChannel);
    }
    if (_driverLocationChannel != null) {
      TaxiService.unsubscribe(_driverLocationChannel);
    }
    super.dispose();
  }

  // State
  bool _isCancelling = false;

  void _subscribeToUpdates() {
    debugPrint('TaxiRideScreen: Subscribing to updates for ride ${_ride.id}');
    // Subscribe to ride status updates
    _rideChannel = TaxiService.subscribeToRide(_ride.id, (rideData) async {
      if (!mounted) return;

      debugPrint('TaxiRideScreen: Received ride update: ${rideData['status']}');
      final fullRideData = await TaxiService.getRide(_ride.id);
      if (fullRideData == null || !mounted) return;

      final updatedRide = TaxiRide.fromJson(fullRideData);
      setState(() => _ride = updatedRide);

      if (updatedRide.status == RideStatus.completed) {
        debugPrint(
          'TaxiRideScreen: Ride completed, navigating to rating screen',
        );
        _onRideCompleted();
      } else if (updatedRide.status == RideStatus.cancelled && !_isCancelling) {
        // Only show cancellation dialog if it wasn't initiated by the user
        _onRideCancelled();
      }
    });

    // Subscribe to driver location updates
    if (_ride.driverId != null) {
      _driverLocationChannel = TaxiService.subscribeToDriverLocation(
        _ride.driverId!,
        (lat, lng) {
          if (!mounted) return;
          // debugPrint('TaxiRideScreen: Driver location update: $lat, $lng'); // Commented out to reduce noise

          // Tracker varsa smooth animasyonlu güncelleme yap
          if (_taxiTracker != null) {
            _taxiTracker!.updateLocation(lat, lng);
          } else {
            // İlk kez konum geliyorsa tracker'ı başlat
            _taxiTracker = RealtimeTaxiTracker(
              rideId: _ride.id,
              initialLat: lat,
              initialLng: lng,
              onLocationUpdate: (animLat, animLng, rotation) {
                if (mounted) {
                  setState(() {
                    _animatedDriverLat = animLat;
                    _animatedDriverLng = animLng;
                    _driverRotation = rotation;
                  });
                  if (_followDriver) {
                    _updateMapCamera();
                  }
                }
              },
              onEtaUpdate: (etaMinutes) {
                if (mounted) {
                  setState(() {
                    _estimatedArrivalMinutes = etaMinutes;
                  });
                }
              },
              onProgressUpdate: (progressPercent) {
                if (mounted) {
                  setState(() {
                    _routeProgressPercent = progressPercent;
                  });
                }
              },
            );
            // Rota noktalarını ayarla
            if (_routePoints.isNotEmpty) {
              _taxiTracker!.setRoutePoints(_routePoints);
            }
            _taxiTracker!.updateLocation(lat, lng);
          }

          setState(() {
            _driverLat = lat;
            _driverLng = lng;
          });

          // Periyodik rota yenileme (~30sn)
          _routeRefreshCounter++;
          if (_routeRefreshCounter >= 10) {
            _routeRefreshCounter = 0;
            _loadRouteFromDriver();
          }

          _updateMapCamera();
          _updateTaxiMarkerRotation();
        },
      );
    }
  }

  Future<void> _updateTaxiMarkerRotation() async {
    // Yeni rotasyonla marker'ı güncelle
    _taxiMarker = await AnimatedMapMarkers.createTaxiMarker(
      rotation: _driverRotation,
      color: Colors.amber,
      size: 80,
    );
    if (mounted) setState(() {});
  }

  void _updateMapCamera() {
    if (_mapController == null || !_followDriver) return;

    _isProgrammaticCameraMove = true;

    // Premium Smart Camera Logic
    if (_driverLat != null && _driverLng != null) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: gmaps.LatLng(_driverLat!, _driverLng!),
            zoom: 17.5, // Closer zoom for 3D effect
            tilt: 60, // Significant tilt for "navigation" feel
            bearing: _driverRotation, // Rotate map with car
          ),
        ),
      );
    } else {
      // Fallback if no driver yet
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: gmaps.LatLng(_ride.pickup.latitude, _ride.pickup.longitude),
            zoom: 15,
            tilt: 0,
            bearing: 0,
          ),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      _isProgrammaticCameraMove = false;
    });
  }

  void _onRideCompleted() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TaxiRatingScreen(ride: _ride),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _onRideCancelled() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sürüş İptal Edildi'),
        content: Text(_ride.cancellationReason ?? 'Sürüş iptal edildi.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (mounted) Navigator.pop(context); // Close screen
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _callDriver() async {
    // Güvenli arama - gerçek numara yerine uygulama içi arama kullan
    HapticFeedback.mediumImpact();

    final callInfo = await CommunicationService.initiateCall(_ride.id);
    if (callInfo != null && mounted) {
      await AppDialogs.showSuccess(context, 'Arama başlatılıyor...');
    }
  }

  void _messageDriver() {
    // Güvenli mesajlaşma - uygulama içi chat aç
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerChatSheet(rideId: _ride.id),
    );
  }

  Future<void> _cancelRide() async {
    if (_ride.status == RideStatus.inProgress) {
      await AppDialogs.showWarning(context, 'Yolculuk başladıktan sonra iptal edilemez');
      return;
    }

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
      setState(
        () => _isCancelling = true,
      ); // Set flag to prevent dialog conflict
      try {
        await TaxiService.cancelRide(_ride.id, reason: 'user_cancelled');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        setState(() => _isCancelling = false); // Reset if failed
        if (mounted) {
          await AppDialogs.showError(context, 'İptal edilemedi: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Map - tam ekran (sheet arkasinda)
          Positioned.fill(
            child: gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: gmaps.LatLng(
                  _driverLat ?? _ride.pickup.latitude,
                  _driverLng ?? _ride.pickup.longitude,
                ),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.4,
              ),
              onCameraMove: (_) {
                // Kullanıcı haritayı hareket ettirdiğinde takibi kapat
                if (!_isProgrammaticCameraMove && _followDriver) {
                  setState(() => _followDriver = false);
                }
              },
            ),
          ),

          // İlerleme çubuğu - Yolculuk başladıysa göster
          if (_ride.status == RideStatus.inProgress &&
              _routeProgressPercent > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: _buildProgressIndicator(colorScheme),
            ),

          // Takip butonu - Takip kapalıysa göster
          if (!_followDriver && _driverLat != null)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.45,
              right: 16,
              child: _buildFollowButton(colorScheme),
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

          // Status badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _ride.status == RideStatus.inProgress
                      ? _pulseAnimation.value
                      : 1.0,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _ride.status.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _ride.status.color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(), color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _ride.status.displayName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Draggable Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.10,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.10, 0.45, 0.85],
            builder: (context, scrollController) {
              return SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(top: 12, bottom: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Driver info - driverId varsa SecureDriverCard göster
                        if (_ride.driverId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SecureDriverCard(
                              rideId: _ride.id,
                              onCallPressed: _callDriver,
                              onMessagePressed: _messageDriver,
                            ),
                          )
                        else if (_ride.driver != null)
                          _buildDriverCard(theme, colorScheme),

                        // Ride details
                        _buildRideDetails(theme, colorScheme),

                        // Action buttons
                        _buildActionButtons(theme, colorScheme),

                        SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 16,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_ride.status) {
      case RideStatus.accepted:
        return Icons.directions_car_rounded;
      case RideStatus.arrived:
        return Icons.place_rounded;
      case RideStatus.inProgress:
        return Icons.navigation_rounded;
      case RideStatus.completed:
        return Icons.check_circle_rounded;
      case RideStatus.cancelled:
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  Widget _buildDriverCard(ThemeData theme, ColorScheme colorScheme) {
    final driver = _ride.driver!;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.3),
            colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green, width: 3),
                      image: driver.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(driver.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: driver.avatarUrl == null
                        ? Icon(
                            Icons.person_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 36,
                          )
                        : null,
                  ),
                  // Online indicator
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Driver info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            driver.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Verified badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Colors.blue,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Onaylı',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Rating and rides
                    Row(
                      children: [
                        if (driver.isNewDriver)
                          _buildStatChip(
                            icon: Icons.fiber_new_rounded,
                            value: 'Yeni',
                            color: Colors.green,
                            theme: theme,
                          )
                        else
                          _buildStatChip(
                            icon: Icons.star_rounded,
                            value: driver.rating.toStringAsFixed(1),
                            color: Colors.amber,
                            theme: theme,
                          ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          icon: Icons.route_rounded,
                          value: '${driver.totalRides}',
                          color: colorScheme.primary,
                          theme: theme,
                          suffix: ' yolculuk',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Vehicle info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Car icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: Colors.amber.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Vehicle details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.vehicleInfo.isNotEmpty
                            ? driver.vehicleInfo
                            : 'Araç Bilgisi',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (driver.vehicleYear != null)
                        Text(
                          '${driver.vehicleYear} Model',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // License plate
                if (driver.vehiclePlate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      driver.vehiclePlate!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ETA info (if available)
          if (_estimatedArrivalMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _ride.status == RideStatus.inProgress
                    ? Colors.purple.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _ride.status == RideStatus.inProgress
                        ? Icons.flag_rounded
                        : Icons.access_time_rounded,
                    color: _ride.status == RideStatus.inProgress
                        ? Colors.purple
                        : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _ride.status == RideStatus.inProgress
                        ? 'Varışa $_estimatedArrivalMinutes dakika'
                        : 'Sürücü $_estimatedArrivalMinutes dakika uzakta',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _ride.status == RideStatus.inProgress
                          ? Colors.purple
                          : Colors.green,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Contact buttons
          Row(
            children: [
              Expanded(
                child: _buildContactButtonLarge(
                  icon: Icons.phone_rounded,
                  label: 'Ara',
                  color: Colors.green,
                  onTap: _callDriver,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactButtonLarge(
                  icon: Icons.message_rounded,
                  label: 'Mesaj',
                  color: colorScheme.primary,
                  onTap: _messageDriver,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactButtonLarge(
                  icon: Icons.my_location_rounded,
                  label: 'Takip Et',
                  color: Colors.orange,
                  onTap: _openNavigation,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required Color color,
    required ThemeData theme,
    String? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$value${suffix ?? ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButtonLarge({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNavigation() {
    // Haritada takip modunu aç ve kamerayı sürücüye odakla
    setState(() => _followDriver = true);
    _updateMapCamera();
  }

  Widget _buildRideDetails(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
            title: 'Alış',
            address: _ride.pickup.address,
            theme: theme,
            colorScheme: colorScheme,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
              width: 2,
              height: 24,
              color: colorScheme.outlineVariant,
            ),
          ),
          _buildLocationRow(
            icon: Icons.square_rounded,
            iconColor: colorScheme.primary,
            title: 'Varış',
            address: _ride.dropoff.address,
            theme: theme,
            colorScheme: colorScheme,
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.route_rounded,
                value: '${_ride.distanceKm.toStringAsFixed(1)} km',
                theme: theme,
                colorScheme: colorScheme,
              ),
              _buildInfoItem(
                icon: Icons.access_time_rounded,
                value: '${_ride.durationMinutes} dk',
                theme: theme,
                colorScheme: colorScheme,
              ),
              _buildInfoItem(
                icon: Icons.payments_rounded,
                value: '${_ride.fare.toStringAsFixed(2)} TL',
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                address,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Cancel button
          if (_ride.status != RideStatus.inProgress &&
              _ride.status != RideStatus.completed)
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelRide,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: colorScheme.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'İptal Et',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          if (_ride.status != RideStatus.inProgress &&
              _ride.status != RideStatus.completed)
            const SizedBox(width: 12),

          // Share location button
          Expanded(
            child: FilledButton.icon(
              onPressed: _shareLocation,
              icon: const Icon(Icons.share_location_rounded),
              label: const Text('Konum Paylaş'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // SOS button
          FilledButton.icon(
            onPressed: _sendSos,
            icon: const Icon(Icons.sos_rounded),
            label: const Text('SOS'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<gmaps.Marker> _buildMarkers() {
    final markers = <gmaps.Marker>{};

    // Pickup marker (özel yeşil pin)
    markers.add(
      gmaps.Marker(
        markerId: const gmaps.MarkerId('pickup'),
        position: gmaps.LatLng(_ride.pickup.latitude, _ride.pickup.longitude),
        icon:
            _pickupMarker ??
            gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueGreen,
            ),
        anchor: const Offset(0.5, 0.9),
        infoWindow: gmaps.InfoWindow(
          title: 'Alış Noktası',
          snippet: _ride.pickup.address,
        ),
      ),
    );

    // Dropoff marker (özel kırmızı pin)
    markers.add(
      gmaps.Marker(
        markerId: const gmaps.MarkerId('dropoff'),
        position: gmaps.LatLng(_ride.dropoff.latitude, _ride.dropoff.longitude),
        icon:
            _dropoffMarker ??
            gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueRed,
            ),
        anchor: const Offset(0.5, 0.9),
        infoWindow: gmaps.InfoWindow(
          title: 'Varış Noktası',
          snippet: _ride.dropoff.address,
        ),
      ),
    );

    // Animasyonlu taksi marker
    final driverDisplayLat = _animatedDriverLat != 0
        ? _animatedDriverLat
        : _driverLat;
    final driverDisplayLng = _animatedDriverLng != 0
        ? _animatedDriverLng
        : _driverLng;

    if (driverDisplayLat != null && driverDisplayLng != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('driver'),
          position: gmaps.LatLng(driverDisplayLat, driverDisplayLng),
          icon:
              _taxiMarker ??
              gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueOrange,
              ),
          anchor: const Offset(0.5, 0.5),
          rotation: _driverRotation,
          flat: true,
          infoWindow: gmaps.InfoWindow(
            title: _ride.driver?.fullName ?? 'Sürücü',
            snippet:
                '${_ride.driver?.vehiclePlate ?? ''} ${_estimatedArrivalMinutes != null ? '• $_estimatedArrivalMinutes dk' : ''}',
          ),
        ),
      );
    }

    return markers;
  }

  // İlerleme göstergesi widget'ı
  Widget _buildProgressIndicator(ColorScheme colorScheme) {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.navigation_rounded,
                color: colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Yolculuk İlerlemesi',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '${_routeProgressPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Animasyonlu ilerleme çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _routeProgressPercent / 100),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                  minHeight: 6,
                );
              },
            ),
          ),
          if (_estimatedArrivalMinutes != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_rounded, color: Colors.green, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Tahmini varış: $_estimatedArrivalMinutes dk',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Takip butonu widget'ı
  Widget _buildFollowButton(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        setState(() => _followDriver = true);
        _updateMapCamera();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.my_location_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Takip Et',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<gmaps.Polyline> _buildPolylines() {
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
          gmaps.LatLng(_ride.pickup.latitude, _ride.pickup.longitude),
          gmaps.LatLng(_ride.dropoff.latitude, _ride.dropoff.longitude),
        ],
        color: Theme.of(context).colorScheme.primary,
        width: 4,
        patterns: [gmaps.PatternItem.dash(20), gmaps.PatternItem.gap(10)],
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
