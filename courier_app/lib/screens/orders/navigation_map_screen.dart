import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_dialogs.dart';

const String _directionsProxyUrl = 'https://mzgtvdgwxrlhgjboolys.supabase.co/functions/v1/get-directions';
const String _osrmDirectionsUrl = 'https://router.project-osrm.org/route/v1/driving';

class NavigationMapScreen extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;
  final String destinationName;
  final String destinationAddress;
  final String? destinationPhone;
  final bool isCustomer; // true: müşteri, false: restoran

  const NavigationMapScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationName,
    required this.destinationAddress,
    this.destinationPhone,
    this.isCustomer = true,
  });

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

class _NavigationMapScreenState extends State<NavigationMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Timer? _locationTimer;
  double? _distance;
  String? _duration;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  bool _isLoading = true;
  int _routeUpdateCounter = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Konum servisi kapalıysa bile fallback mesafe göster
      _setFallbackDistanceFromWidget();
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setFallbackDistanceFromWidget();
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setFallbackDistanceFromWidget();
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await _updatePosition();
    if (_currentPosition != null) {
      // Yön bilgisini bekle - bu önemli!
      await _updateMarkersAndRoute();
      _startLocationUpdates();
    } else {
      // Konum alınamadıysa fallback mesafe göster
      _setFallbackDistanceFromWidget();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Widget'tan gelen hedef koordinatlarına göre tahmini mesafe
  void _setFallbackDistanceFromWidget() {
    // Varsayılan başlangıç noktası yoksa yaklaşık mesafe göster
    _distance = 0;
    _duration = '-- dk';
    if (mounted) setState(() {});
  }

  /// Konumu güncelle - exception fırlatmadan güvenli şekilde
  Future<void> _updatePosition() async {
    try {
      // Önce son bilinen konumu dene (hızlı)
      _currentPosition ??= await Geolocator.getLastKnownPosition();

      // Güncel konum al
      try {
        _currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        debugPrint('getCurrentPosition error: $e');
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      await _updatePosition();
      if (_currentPosition != null) {
        await _updateMarkersAndRoute(); // await eklendi - yön hesaplanmasını bekle
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _updateMarkersAndRoute() async {
    if (_currentPosition == null) return;

    final courierLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final destinationLatLng = LatLng(widget.destinationLat, widget.destinationLng);

    // Marker'ları güncelle
    _markers = {
      Marker(
        markerId: const MarkerId('courier'),
        position: courierLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Konumunuz'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destinationLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.isCustomer ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: widget.destinationName,
          snippet: widget.destinationAddress,
        ),
      ),
    };

    // Google Directions API ile gerçek rota al
    // İlk seferde ve her 6 güncellemede (30 saniye) rotayı yenile
    _routeUpdateCounter++;
    debugPrint('📍 _updateMarkersAndRoute: counter=$_routeUpdateCounter, routePoints=${_routePoints.length}');
    if (_routePoints.isEmpty || _routeUpdateCounter >= 6) {
      _routeUpdateCounter = 0;
      debugPrint('🚀 Yön hesaplama başlatılıyor...');
      await _getDirections(courierLatLng, destinationLatLng);
      debugPrint('✅ Yön hesaplama tamamlandı: distance=$_distance, duration=$_duration');
    }

    // Rota çizgisi
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints.isNotEmpty ? _routePoints : [courierLatLng, destinationLatLng],
        color: widget.isCustomer ? AppColors.error : AppColors.primary,
        width: 5,
      ),
    };

    // Kamerayı her iki noktayı gösterecek şekilde ayarla
    _fitBounds(courierLatLng, destinationLatLng);
  }

  // Supabase Edge Function üzerinden Google Directions API'den gerçek rota, mesafe ve süre al
  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    debugPrint('🗺️ _getDirections çağrıldı: ${origin.latitude},${origin.longitude} -> ${destination.latitude},${destination.longitude}');
    try {
      // Edge Function proxy kullan (CORS sorununu çözer)
      // 10 saniye timeout ekle - KKTC için API yavaş olabilir
      debugPrint('📡 Edge Function\'a istek gönderiliyor...');
      final response = await http.post(
        Uri.parse(_directionsProxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'origin_lat': origin.latitude,
          'origin_lng': origin.longitude,
          'destination_lat': destination.latitude,
          'destination_lng': destination.longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 Edge Function yanıtı: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('🔍 Google API status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Gerçek mesafe (API'den metre cinsinden geliyor)
          // num olarak al, int'e çevrilemeyen durumları handle et
          final distanceValue = (leg['distance']['value'] as num).toDouble();
          _distance = distanceValue / 1000.0; // km'ye çevir

          // Gerçek süre (API'den saniye cinsinden geliyor)
          final durationValue = (leg['duration']['value'] as num).toDouble();
          final durationMinutes = (durationValue / 60).round();
          if (durationMinutes < 60) {
            _duration = '$durationMinutes dk';
          } else {
            final hours = durationMinutes ~/ 60;
            final mins = durationMinutes % 60;
            _duration = '$hours sa $mins dk';
          }

          // Polyline noktalarını decode et
          final encodedPolyline = route['overview_polyline']['points'] as String;
          _routePoints = _decodePolyline(encodedPolyline);

          debugPrint('✅ Google Directions API: ${_distance?.toStringAsFixed(1)} km, $_duration, ${_routePoints.length} points');

          if (mounted) setState(() {});
          return; // Başarılı, çık
        } else {
          // Google API çalışmazsa OSRM dene (KKTC/Kıbrıs için)
          debugPrint('Google Directions API error: ${data['status']} - trying OSRM fallback');
        }
      } else {
        debugPrint('Directions API HTTP error: ${response.statusCode} - trying OSRM fallback');
      }
    } catch (e) {
      debugPrint('Directions API error: $e - trying OSRM fallback');
    }

    // Google başarısız olduysa OSRM dene
    await _getOsrmDirections(origin, destination);
  }

  // OSRM (Open Source Routing Machine) fallback - Google çalışmazsa
  Future<void> _getOsrmDirections(LatLng origin, LatLng destination) async {
    try {
      final url = '$_osrmDirectionsUrl/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=polyline';

      // 8 saniye timeout ekle
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('OSRM response code: ${data['code']}');

        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];

          // Mesafe (metre cinsinden)
          final distanceValue = (route['distance'] as num).toDouble();
          _distance = distanceValue / 1000.0; // km'ye çevir

          // Süre (saniye cinsinden)
          final durationValue = (route['duration'] as num).toDouble();
          final durationMinutes = (durationValue / 60).round();
          if (durationMinutes < 60) {
            _duration = '$durationMinutes dk';
          } else {
            final hours = durationMinutes ~/ 60;
            final mins = durationMinutes % 60;
            _duration = '$hours sa $mins dk';
          }

          // Polyline noktalarını decode et
          final encodedPolyline = route['geometry'] as String;
          _routePoints = _decodePolyline(encodedPolyline);

          debugPrint('OSRM Directions: ${_distance?.toStringAsFixed(1)} km, $_duration');

          if (mounted) setState(() {});
          return; // Başarılı, çık
        } else {
          debugPrint('OSRM error: ${data['code']}');
        }
      } else {
        debugPrint('OSRM HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OSRM error: $e');
    }

    // OSRM de başarısız olduysa kuş uçuşu hesapla
    _setFallbackDistance(origin, destination);
  }

  // Google'ın encoded polyline formatını decode et
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _setFallbackDistance(LatLng origin, LatLng destination) {
    // Hata durumunda kuş uçuşu mesafe hesapla
    final directDistance = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    ) / 1000;

    // Şehir içi rotalar için kuş uçuşunun yaklaşık 1.3-1.4 katı
    _distance = directDistance * 1.35;
    _duration = '~${(_distance! * 2).round()} dk';

    // Düz çizgi rota
    _routePoints = [origin, destination];

    if (mounted) setState(() {});
  }

  void _fitBounds(LatLng point1, LatLng point2) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        point1.latitude < point2.latitude ? point1.latitude : point2.latitude,
        point1.longitude < point2.longitude ? point1.longitude : point2.longitude,
      ),
      northeast: LatLng(
        point1.latitude > point2.latitude ? point1.latitude : point2.latitude,
        point1.longitude > point2.longitude ? point1.longitude : point2.longitude,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void _centerOnCourier() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16,
      ),
    );
  }

  void _centerOnDestination() {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(widget.destinationLat, widget.destinationLng),
        16,
      ),
    );
  }

  Future<void> _openExternalNavigation() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.destinationLat},${widget.destinationLng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone() async {
    if (widget.destinationPhone != null && widget.destinationPhone!.isNotEmpty) {
      final uri = Uri.parse('tel:${widget.destinationPhone}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else {
      AppDialogs.showInfo(context, 'Telefon numarası bulunamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Harita
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.destinationLat, widget.destinationLng),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                _updateMarkersAndRoute();
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Üst bilgi kartı
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.isCustomer ? AppColors.error : AppColors.primary,
                    (widget.isCustomer ? AppColors.error : AppColors.primary).withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Geri butonu ve başlık
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isCustomer ? 'Müşteriye Navigasyon' : 'Restorana Navigasyon',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.destinationName,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _distance != null && _distance! > 0
                                      ? '${_distance!.toStringAsFixed(1)} km'
                                      : 'Hesaplanıyor...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Adres
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.destinationAddress,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Sağ alt köşe butonları
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              children: [
                // Konumuma git
                FloatingActionButton.small(
                  heroTag: 'myLocation',
                  onPressed: _centerOnCourier,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.my_location, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                // Hedefe git
                FloatingActionButton.small(
                  heroTag: 'destination',
                  onPressed: _centerOnDestination,
                  backgroundColor: AppColors.surface,
                  child: Icon(
                    widget.isCustomer ? Icons.person_pin_circle : Icons.store,
                    color: widget.isCustomer ? AppColors.error : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // Her ikisini göster
                FloatingActionButton.small(
                  heroTag: 'fitBounds',
                  onPressed: () {
                    if (_currentPosition != null) {
                      _fitBounds(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        LatLng(widget.destinationLat, widget.destinationLng),
                      );
                    }
                  },
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.zoom_out_map, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Alt aksiyon butonları
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mesafe ve süre bilgisi
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoChip(
                          icon: Icons.directions,
                          label: _distance != null && _distance! > 0
                              ? '${_distance!.toStringAsFixed(1)} km'
                              : 'Hesaplanıyor...',
                          color: AppColors.primary,
                        ),
                        _buildInfoChip(
                          icon: Icons.access_time,
                          label: _duration ?? 'Hesaplanıyor...',
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                  // Aksiyon butonları
                  Row(
                    children: [
                      // Telefon butonu
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _callPhone,
                          icon: const Icon(Icons.phone),
                          label: const Text('Ara'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.success,
                            side: BorderSide(color: AppColors.success),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Google Maps'te aç
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _openExternalNavigation,
                          icon: const Icon(Icons.navigation),
                          label: const Text('Google Maps\'te Aç'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isCustomer ? AppColors.error : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Yükleniyor göstergesi
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
