import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/emlak_models.dart';
import '../../providers/property_provider.dart';

/// Yeni İlan Ekleme Ekranı - Tam Form
class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _squareMetersController = TextEditingController();
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _floorController = TextEditingController();
  final _totalFloorsController = TextEditingController();
  final _buildingAgeController = TextEditingController();
  final _addressController = TextEditingController();

  // Form Values
  ListingType _listingType = ListingType.sale;
  PropertyType _propertyType = PropertyType.apartment;
  String _selectedCurrency = 'TL';
  String? _selectedCity;
  String? _selectedDistrict;
  List<String> _selectedAmenities = [];
  List<_UploadedImage> _uploadedImages = [];

  // Para birimi seçenekleri
  final List<Map<String, String>> _currencyOptions = [
    {'code': 'TL', 'symbol': '₺', 'name': 'Türk Lirası'},
    {'code': 'USD', 'symbol': '\$', 'name': 'Amerikan Doları'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'İngiliz Sterlini'},
  ];

  // Konum (Harita)
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isGettingLocation = false;
  // Kuzey Kıbrıs merkez koordinatları (varsayılan)
  static const LatLng _defaultCenter = LatLng(35.1856, 33.3823);

  // Feature Flags
  bool _hasParking = false;
  bool _hasBalcony = false;
  bool _hasFurniture = false;
  bool _hasPool = false;
  bool _hasGym = false;
  bool _hasSecurity = false;
  bool _hasElevator = false;
  bool _isSmartHome = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _squareMetersController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _floorController.dispose();
    _totalFloorsController.dispose();
    _buildingAgeController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  /// GPS ile mevcut konumu al
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Konum izni kontrolü
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Konum izni reddedildi')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.'),
            ),
          );
        }
        return;
      }

      // Konumu al
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = newLocation;
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });

      // Haritayı yeni konuma taşı
      _mapController.move(newLocation, 15);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum başarıyla alındı'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konum alınamadı: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  /// Koordinat giriş dialog'u
  void _showCoordinateDialog() {
    // Mevcut değerleri göster
    if (_selectedLocation != null) {
      _latitudeController.text = _selectedLocation!.latitude.toStringAsFixed(6);
      _longitudeController.text = _selectedLocation!.longitude.toStringAsFixed(6);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Koordinat Girin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _latitudeController,
              decoration: const InputDecoration(
                labelText: 'Enlem (Latitude)',
                hintText: 'Örn: 35.185600',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _longitudeController,
              decoration: const InputDecoration(
                labelText: 'Boylam (Longitude)',
                hintText: 'Örn: 33.382300',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 12),
            Text(
              'Google Maps\'ten koordinat alabilirsiniz:\nSağ tık → "Buradaki koordinatları kopyala"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              _setLocationFromCoordinates();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }

  /// Koordinatlardan konum ayarla
  void _setLocationFromCoordinates() {
    final lat = double.tryParse(_latitudeController.text.replaceAll(',', '.'));
    final lng = double.tryParse(_longitudeController.text.replaceAll(',', '.'));

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli koordinat girin')),
      );
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat aralık dışında')),
      );
      return;
    }

    final newLocation = LatLng(lat, lng);
    setState(() => _selectedLocation = newLocation);
    _mapController.move(newLocation, 15);
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(citiesProvider);
    final districts = _selectedCity != null
        ? ref.watch(districtsProvider(_selectedCity!))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Yeni İlan Ekle'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Step Indicator
            _buildStepIndicator(),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentStep(cities, districts),
              ),
            ),

            // Bottom Actions
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Temel Bilgiler', 'Konum', 'Özellikler', 'Fotoğraflar'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: Colors.white,
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF3B82F6)
                        : isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      color: isActive ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 24,
                    height: 2,
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep(
    AsyncValue<List<String>> cities,
    AsyncValue<List<String>>? districts,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildLocationStep(cities, districts);
      case 2:
        return _buildFeaturesStep();
      case 3:
        return _buildImagesStep();
      default:
        return _buildBasicInfoStep();
    }
  }

  // ==================== STEP 1: BASIC INFO ====================
  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('İlan Türü'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildListingTypeCard(ListingType.sale, 'Satılık', Icons.sell),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildListingTypeCard(ListingType.rent, 'Kiralık', Icons.home),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _buildSectionTitle('Emlak Türü'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PropertyType.values.map((type) {
            final isSelected = _propertyType == type;
            return ChoiceChip(
              label: Text(type.label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _propertyType = type);
                }
              },
              avatar: Icon(type.icon, size: 18),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        _buildSectionTitle('İlan Başlığı'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titleController,
          decoration: _inputDecoration('Örn: Deniz Manzaralı 3+1 Daire'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'İlan başlığı zorunludur';
            }
            if (value.length < 10) {
              return 'Başlık en az 10 karakter olmalıdır';
            }
            return null;
          },
        ),

        const SizedBox(height: 24),
        _buildSectionTitle('Açıklama'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: _inputDecoration('İlanınızı detaylı açıklayın...'),
          maxLines: 5,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Açıklama zorunludur';
            }
            if (value.length < 50) {
              return 'Açıklama en az 50 karakter olmalıdır';
            }
            return null;
          },
        ),

        const SizedBox(height: 24),
        _buildSectionTitle('Fiyat'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Para birimi seçici
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCurrency,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: BorderRadius.circular(8),
                  items: _currencyOptions.map((currency) {
                    return DropdownMenuItem<String>(
                      value: currency['code'],
                      child: Text(
                        '${currency['symbol']} ${currency['code']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCurrency = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Fiyat girişi
            Expanded(
              child: TextFormField(
                controller: _priceController,
                decoration: _inputDecoration('Fiyat'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Fiyat zorunludur';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Geçerli bir fiyat girin';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListingTypeCard(ListingType type, String label, IconData icon) {
    final isSelected = _listingType == type;

    return InkWell(
      onTap: () => setState(() => _listingType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? type.color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? type.color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? type.color : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? type.color : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 2: LOCATION ====================
  Widget _buildLocationStep(
    AsyncValue<List<String>> cities,
    AsyncValue<List<String>>? districts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Şehir'),
        const SizedBox(height: 12),
        cities.when(
          data: (cityList) => DropdownButtonFormField<String>(
            value: _selectedCity,
            decoration: _inputDecoration('Şehir seçin'),
            items: cityList.map((city) {
              return DropdownMenuItem(value: city, child: Text(city));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCity = value;
                _selectedDistrict = null;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Şehir seçimi zorunludur';
              }
              return null;
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Hata: $e'),
        ),

        const SizedBox(height: 24),
        _buildSectionTitle('İlçe'),
        const SizedBox(height: 12),
        if (_selectedCity == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Önce şehir seçin',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          )
        else
          districts?.when(
            data: (districtList) => DropdownButtonFormField<String>(
              value: _selectedDistrict,
              decoration: _inputDecoration('İlçe seçin'),
              items: districtList.map((district) {
                return DropdownMenuItem(value: district, child: Text(district));
              }).toList(),
              onChanged: (value) => setState(() => _selectedDistrict = value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'İlçe seçimi zorunludur';
                }
                return null;
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Hata: $e'),
          ) ?? const SizedBox(),

        const SizedBox(height: 24),
        _buildSectionTitle('Adres (Opsiyonel)'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          decoration: _inputDecoration('Detaylı adres bilgisi'),
          maxLines: 2,
        ),

        const SizedBox(height: 24),
        _buildSectionTitle('Harita Konumu (Opsiyonel)'),
        const SizedBox(height: 12),

        // Konum seçme butonları
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(_isGettingLocation ? 'Alınıyor...' : 'Konumumu Al'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  foregroundColor: const Color(0xFF3B82F6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showCoordinateDialog(),
                icon: const Icon(Icons.edit_location_alt, size: 18),
                label: const Text('Koordinat Gir'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  foregroundColor: const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Text(
          'veya haritaya tıklayarak konum seçin',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Harita
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLocation ?? _defaultCenter,
                  initialZoom: 10,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selectedLocation = point;
                      _latitudeController.text = point.latitude.toStringAsFixed(6);
                      _longitudeController.text = point.longitude.toStringAsFixed(6);
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.emlakci.panel',
                  ),
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // Konum bilgisi göstergesi
              if (_selectedLocation != null)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Konum: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedLocation = null;
                              _latitudeController.clear();
                              _longitudeController.clear();
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== STEP 3: FEATURES ====================
  Widget _buildFeaturesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Temel Özellikler'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _squareMetersController,
                decoration: _inputDecoration('m² (Brüt)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'm² zorunludur';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _roomsController,
                decoration: _inputDecoration('Oda Sayısı'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Oda sayısı zorunludur';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _bathroomsController,
                decoration: _inputDecoration('Banyo Sayısı'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _buildingAgeController,
                decoration: _inputDecoration('Bina Yaşı'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _floorController,
                decoration: _inputDecoration('Bulunduğu Kat'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _totalFloorsController,
                decoration: _inputDecoration('Toplam Kat'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        _buildSectionTitle('Ek Özellikler'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureChip('Otopark', _hasParking, Icons.local_parking, (v) => setState(() => _hasParking = v)),
            _buildFeatureChip('Balkon', _hasBalcony, Icons.balcony, (v) => setState(() => _hasBalcony = v)),
            _buildFeatureChip('Eşyalı', _hasFurniture, Icons.chair, (v) => setState(() => _hasFurniture = v)),
            _buildFeatureChip('Havuz', _hasPool, Icons.pool, (v) => setState(() => _hasPool = v)),
            _buildFeatureChip('Spor Salonu', _hasGym, Icons.fitness_center, (v) => setState(() => _hasGym = v)),
            _buildFeatureChip('Güvenlik', _hasSecurity, Icons.security, (v) => setState(() => _hasSecurity = v)),
            _buildFeatureChip('Asansör', _hasElevator, Icons.elevator, (v) => setState(() => _hasElevator = v)),
            _buildFeatureChip('Akıllı Ev', _isSmartHome, Icons.home_max, (v) => setState(() => _isSmartHome = v)),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureChip(String label, bool isSelected, IconData icon, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onChanged,
      avatar: Icon(icon, size: 18),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
      checkmarkColor: const Color(0xFF3B82F6),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
      ),
    );
  }

  // ==================== STEP 4: IMAGES ====================
  Widget _buildImagesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('İlan Fotoğrafları'),
        const SizedBox(height: 8),
        const Text(
          'En az 1, en fazla 10 fotoğraf yükleyebilirsiniz. İlk fotoğraf kapak fotoğrafı olarak kullanılacaktır.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Upload Button
        InkWell(
          onTap: _pickImages,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6), style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_upload, color: Color(0xFF3B82F6), size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fotoğraf Yükle',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PNG, JPG, WEBP (Maks. 5MB)',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Uploaded Images Grid
        if (_uploadedImages.isNotEmpty) ...[
          _buildSectionTitle('Yüklenen Fotoğraflar (${_uploadedImages.length}/10)'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _uploadedImages.length,
            itemBuilder: (context, index) {
              final image = _uploadedImages[index];
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: index == 0
                          ? Border.all(color: const Color(0xFF3B82F6), width: 2)
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        image.bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Kapak',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _uploadedImages.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        final remainingSlots = 10 - _uploadedImages.length;
        final filesToAdd = result.files.take(remainingSlots);

        for (final file in filesToAdd) {
          if (file.bytes != null) {
            setState(() {
              _uploadedImages.add(_UploadedImage(
                bytes: file.bytes!,
                name: file.name,
              ));
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf yükleme hatası: $e')),
        );
      }
    }
  }

  // ==================== HELPERS ====================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? suffixText}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffixText,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Geri'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(_currentStep == 3 ? 'İlanı Kaydet' : 'İleri'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    // Validate current step
    if (_currentStep == 0) {
      if (_titleController.text.isEmpty ||
          _descriptionController.text.isEmpty ||
          _priceController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun')),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedCity == null || _selectedDistrict == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen şehir ve ilçe seçin')),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (_squareMetersController.text.isEmpty || _roomsController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen m² ve oda sayısı girin')),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _saveProperty();
    }
  }

  Future<void> _saveProperty() async {
    if (_uploadedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az 1 fotoğraf yüklemelisiniz')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Upload images to storage
      final List<String> imageUrls = [];
      for (int i = 0; i < _uploadedImages.length; i++) {
        final image = _uploadedImages[i];
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        await supabase.storage.from('images').uploadBinary(
          'properties/$fileName',
          image.bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

        final publicUrl = supabase.storage.from('images').getPublicUrl('properties/$fileName');
        imageUrls.add(publicUrl);
      }

      // Create property
      final property = Property(
        id: '',
        userId: userId,
        title: _titleController.text,
        description: _descriptionController.text,
        type: _propertyType,
        listingType: _listingType,
        status: PropertyStatus.pending,
        price: double.parse(_priceController.text),
        currency: _selectedCurrency,
        location: PropertyLocation(
          city: _selectedCity!,
          district: _selectedDistrict!,
          neighborhood: '',
          address: _addressController.text,
          latitude: _selectedLocation?.latitude,
          longitude: _selectedLocation?.longitude,
        ),
        images: imageUrls,
        rooms: int.tryParse(_roomsController.text) ?? 0,
        bathrooms: int.tryParse(_bathroomsController.text) ?? 1,
        squareMeters: int.tryParse(_squareMetersController.text) ?? 0,
        floor: int.tryParse(_floorController.text),
        totalFloors: int.tryParse(_totalFloorsController.text),
        buildingAge: int.tryParse(_buildingAgeController.text),
        hasParking: _hasParking,
        hasBalcony: _hasBalcony,
        hasFurniture: _hasFurniture,
        hasPool: _hasPool,
        hasGym: _hasGym,
        hasSecurity: _hasSecurity,
        hasElevator: _hasElevator,
        isSmartHome: _isSmartHome,
        amenities: _selectedAmenities,
        createdAt: DateTime.now(),
      );

      await ref.read(userPropertiesProvider.notifier).createProperty(property);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlan başarıyla oluşturuldu! Onay için bekleniyor.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _UploadedImage {
  final Uint8List bytes;
  final String name;

  _UploadedImage({required this.bytes, required this.name});
}
