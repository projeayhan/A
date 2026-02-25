import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/emlak/emlak_models.dart';
import '../../services/emlak/property_service.dart';
import '../../core/providers/emlak_provider.dart';
import '../../core/utils/app_dialogs.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  final String? propertyId; // Düzenleme modunda property ID

  const AddPropertyScreen({super.key, this.propertyId});

  bool get isEditMode => propertyId != null;

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen>
    with TickerProviderStateMixin {
  bool _isSubmitting = false;
  late AnimationController _progressController;
  late PageController _pageController;

  int _currentStep = 0;
  final int _totalSteps = 5;

  // Form data
  ListingType _listingType = ListingType.sale;
  String? _selectedPropertyTypeName; // Dinamik property type (DB'den)
  PropertyTypeModel? _selectedPropertyTypeModel;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _squareMetersController = TextEditingController();
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _floorController = TextEditingController();
  final _totalFloorsController = TextEditingController();
  final _buildingAgeController = TextEditingController();

  // Location
  String _selectedCity = 'Girne';
  String _selectedDistrict = '';
  final _neighborhoodController = TextEditingController();
  final _addressController = TextEditingController();

  // Harita ve Konum
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isGettingLocation = false;
  static const LatLng _defaultCenter = LatLng(35.1856, 33.3823); // Kuzey Kıbrıs merkez

  // Para Birimi
  String _selectedCurrency = 'TL';
  final List<Map<String, String>> _currencyOptions = [
    {'code': 'TL', 'symbol': '₺', 'name': 'Türk Lirası'},
    {'code': 'USD', 'symbol': '\$', 'name': 'Amerikan Doları'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'İngiliz Sterlini'},
  ];

  // Features - 101evler
  String? _roomType;
  String? _furnitureStatus;
  String? _heatingType;
  String? _deedType;
  final _netSquareMetersController = TextEditingController();
  final Map<String, bool> _features = {};

  // Images - Bytes olarak sakla (Storage'a yüklemek için)
  final List<_UploadedImage> _uploadedImages = [];
  // Mevcut resimler (düzenleme modunda)
  List<String> _existingImageUrls = [];

  // DB'den gelen veriler
  List<String> _cities = [];
  List<String> _districtList = [];
  bool _isLoadingLocations = true;
  bool _isLoadingProperty = false;
  Property? _existingProperty;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pageController = PageController();
    _loadLocations();

    // Düzenleme modundaysa mevcut property'yi yükle
    if (widget.isEditMode) {
      _loadExistingProperty();
    }
  }

  Future<void> _loadExistingProperty() async {
    if (widget.propertyId == null) return;

    setState(() => _isLoadingProperty = true);

    try {
      final propertyService = ref.read(propertyServiceProvider);
      final property = await propertyService.getPropertyById(widget.propertyId!);

      if (property != null && mounted) {
        setState(() {
          _existingProperty = property;

          // Form alanlarını doldur
          _listingType = property.listingType;
          _selectedPropertyTypeName = property.type.name;
          _titleController.text = property.title;
          _descriptionController.text = property.description;
          _priceController.text = property.price.toInt().toString();
          _squareMetersController.text = property.squareMeters.toString();
          _roomsController.text = property.rooms.toString();
          _bathroomsController.text = property.bathrooms.toString();
          if (property.floor != null) {
            _floorController.text = property.floor.toString();
          }
          if (property.totalFloors != null) {
            _totalFloorsController.text = property.totalFloors.toString();
          }
          if (property.buildingAge != null) {
            _buildingAgeController.text = property.buildingAge.toString();
          }

          // Para birimi
          _selectedCurrency = property.currency ?? 'TL';

          // Konum
          _selectedCity = property.location.city;
          _selectedDistrict = property.location.district;
          _neighborhoodController.text = property.location.neighborhood ?? '';
          _addressController.text = property.location.address ?? '';

          // Harita koordinatları
          final lat = property.location.latitude;
          final lng = property.location.longitude;
          if (lat != null && lng != null) {
            if (lat != 0 || lng != 0) {
              _selectedLocation = LatLng(lat, lng);
              _latitudeController.text = lat.toStringAsFixed(6);
              _longitudeController.text = lng.toStringAsFixed(6);
            }
          }

          // Dropdowns
          _roomType = property.roomType;
          _furnitureStatus = property.furnitureStatus;
          _heatingType = property.heatingType;
          _deedType = property.deedType;
          if (property.netSquareMeters != null) {
            _netSquareMetersController.text = property.netSquareMeters.toString();
          }
          // Quick amenities (bunlar da feature map'ine eklenmeli)
          _features['hasFurniture'] = property.hasFurniture;
          _features['hasPool'] = property.hasPool;
          _features['hasGym'] = property.hasGym;
          _features['hasSecurity'] = property.hasSecurity;
          _features['isSmartHome'] = property.isSmartHome;
          // Tüm boolean özellikler
          _features['isOpenToTrade'] = property.isOpenToTrade;
          _features['isInComplex'] = property.isInComplex;
          _features['hasGarage'] = property.hasGarage;
          _features['hasGarden'] = property.hasGarden;
          _features['hasPrivatePool'] = property.hasPrivatePool;
          _features['hasSharedPool'] = property.hasSharedPool;
          _features['hasSecurityCamera'] = property.hasSecurityCamera;
          _features['hasTerrace'] = property.hasTerrace;
          _features['hasInsulation'] = property.hasInsulation;
          _features['hasWaterTank'] = property.hasWaterTank;
          _features['hasWell'] = property.hasWell;
          _features['hasBarbeque'] = property.hasBarbeque;
          _features['hasDoubleGlazing'] = property.hasDoubleGlazing;
          _features['hasCoveredParking'] = property.hasCoveredParking;
          _features['hasGenerator'] = property.hasGenerator;
          _features['hasElevator'] = property.hasElevator;
          _features['hasParking'] = property.hasParking;
          _features['hasSandstoneHouse'] = property.hasSandstoneHouse;
          _features['isDuplex'] = property.isDuplex;
          _features['hasAirConditioning'] = property.hasAirConditioning;
          _features['hasBalcony'] = property.hasBalcony;
          _features['hasShutter'] = property.hasShutter;
          _features['hasBuiltinKitchen'] = property.hasBuiltinKitchen;
          _features['hasBuiltinWardrobe'] = property.hasBuiltinWardrobe;
          _features['hasIntercom'] = property.hasIntercom;
          _features['hasFireplace'] = property.hasFireplace;
          _features['hasCrown'] = property.hasCrown;
          _features['hasLaundryRoom'] = property.hasLaundryRoom;
          _features['hasParentBathroom'] = property.hasParentBathroom;
          _features['hasParentCloset'] = property.hasParentCloset;
          _features['hasNaturalMarble'] = property.hasNaturalMarble;
          _features['hasPanelDoor'] = property.hasPanelDoor;
          _features['hasParquet'] = property.hasParquet;
          _features['hasShower'] = property.hasShower;
          _features['hasSteelDoor'] = property.hasSteelDoor;
          _features['hasTvInfra'] = property.hasTvInfra;
          _features['hasVestibule'] = property.hasVestibule;
          _features['hasWallpaper'] = property.hasWallpaper;
          _features['hasCeramic'] = property.hasCeramic;
          _features['hasFireAlarm'] = property.hasFireAlarm;
          _features['hasPantry'] = property.hasPantry;
          _features['hasSolarPower'] = property.hasSolarPower;
          _features['hasHydrophore'] = property.hasHydrophore;
          _features['hasCityView'] = property.hasCityView;
          _features['isEastFacing'] = property.isEastFacing;
          _features['isCityCenter'] = property.isCityCenter;
          _features['hasMountainView'] = property.hasMountainView;
          _features['hasNatureView'] = property.hasNatureView;
          _features['isNorthFacing'] = property.isNorthFacing;
          _features['isSeafront'] = property.isSeafront;
          _features['hasSeaView'] = property.hasSeaView;
          _features['isSouthFacing'] = property.isSouthFacing;
          _features['isWestFacing'] = property.isWestFacing;

          // Görseller - Mevcut URL'leri sakla (düzenleme modunda)
          _existingImageUrls = List.from(property.images);

          _isLoadingProperty = false;
        });

        // Şehir değiştiğinde ilçeleri yükle
        await _loadDistricts();
      }
    } catch (e) {
      debugPrint('Property yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoadingProperty = false);
        AppDialogs.showError(context, 'İlan yüklenirken hata: $e');
      }
    }
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      final propertyService = ref.read(propertyServiceProvider);
      final cities = await propertyService.getCities();

      if (mounted) {
        setState(() {
          _cities = cities;
          if (_cities.isNotEmpty && !_cities.contains(_selectedCity)) {
            _selectedCity = _cities.first;
          }
        });
        await _loadDistricts();
      }
    } catch (e) {
      debugPrint('Lokasyon yükleme hatası: $e');
    }
    if (mounted) {
      setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _loadDistricts() async {
    try {
      final propertyService = ref.read(propertyServiceProvider);
      final districts = await propertyService.getDistrictsByCity(_selectedCity);

      if (mounted) {
        setState(() {
          _districtList = districts;
          // Edit modunda mevcut district'i koru
          if (_districtList.isNotEmpty) {
            if (!_districtList.contains(_selectedDistrict)) {
              _selectedDistrict = _districtList.first;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('İlçe yükleme hatası: $e');
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _squareMetersController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _floorController.dispose();
    _totalFloorsController.dispose();
    _buildingAgeController.dispose();
    _neighborhoodController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _netSquareMetersController.dispose();
    super.dispose();
  }

  /// GPS ile mevcut konumu al
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppDialogs.showWarning(context, 'Konum izni reddedildi');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppDialogs.showWarning(context, 'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.');
        }
        return;
      }

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
        AppDialogs.showError(context, 'Konum alınamadı: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  /// Koordinat giriş dialog'u
  void _showCoordinateDialog() {
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
              backgroundColor: EmlakColors.primary,
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
      AppDialogs.showWarning(context, 'Geçerli koordinat girin');
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      AppDialogs.showWarning(context, 'Koordinat aralık dışında');
      return;
    }

    final newLocation = LatLng(lat, lng);
    setState(() => _selectedLocation = newLocation);
    _mapController.move(newLocation, 15);
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _submitListing();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _submitListing() async {
    // Form doğrulama
    if (_titleController.text.trim().isEmpty) {
      _showError('Lütfen ilan başlığı girin');
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      _showError('Lütfen fiyat girin');
      return;
    }
    if (_squareMetersController.text.trim().isEmpty) {
      _showError('Lütfen alan bilgisi girin');
      return;
    }

    // Fotoğraf kontrolü - yeni yüklenen + mevcut
    final totalImages = _uploadedImages.length + _existingImageUrls.length;
    if (totalImages < 3) {
      _showError('Lütfen en az 3 fotoğraf ekleyin');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Yeni fotoğrafları Supabase Storage'a yükle
      final List<String> imageUrls = List.from(_existingImageUrls);

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

      final propertyService = ref.read(propertyServiceProvider);

      // Amenities listesi oluştur (display amaçlı)
      const featureLabels = {
        'hasGarage': 'Garaj', 'hasGarden': 'Bahçe', 'hasPrivatePool': 'Özel Havuz',
        'hasSharedPool': 'Ortak Havuz', 'hasSecurityCamera': 'Güvenlik Kamerası',
        'hasTerrace': 'Teras', 'hasInsulation': 'Isı Yalıtımı', 'hasWaterTank': 'Su Deposu',
        'hasWell': 'Su Kuyusu', 'hasBarbeque': 'Barbekü', 'hasDoubleGlazing': 'Çift Cam',
        'hasCoveredParking': 'Kapalı Otopark', 'hasGenerator': 'Jeneratör',
        'hasElevator': 'Asansör', 'hasParking': 'Otopark', 'hasSandstoneHouse': 'Taş Ev',
        'isDuplex': 'Dubleks', 'hasAirConditioning': 'Klima', 'hasBalcony': 'Balkon',
        'hasShutter': 'Kepenk', 'hasBuiltinKitchen': 'Ankastre Mutfak',
        'hasBuiltinWardrobe': 'Gömme Dolap', 'hasIntercom': 'İnterkom',
        'hasFireplace': 'Şömine', 'hasCrown': 'Kartonpiyer',
        'hasLaundryRoom': 'Çamaşır Odası', 'hasParentBathroom': 'Ebeveyn Banyosu',
        'hasParentCloset': 'Ebeveyn Giyinme', 'hasNaturalMarble': 'Doğal Mermer',
        'hasPanelDoor': 'Panel Kapı', 'hasParquet': 'Parke', 'hasShower': 'Duşakabin',
        'hasSteelDoor': 'Çelik Kapı', 'hasTvInfra': 'TV Altyapısı',
        'hasVestibule': 'Vestiyer', 'hasWallpaper': 'Duvar Kağıdı',
        'hasCeramic': 'Seramik', 'hasFireAlarm': 'Yangın Alarmı', 'hasPantry': 'Kiler',
        'hasSolarPower': 'Güneş Enerjisi', 'hasHydrophore': 'Hidrofor',
      };
      final amenities = <String>[];
      for (final entry in _features.entries) {
        if (entry.value && featureLabels.containsKey(entry.key)) {
          amenities.add(featureLabels[entry.key]!);
        }
      }

      // Property oluştur
      final propertyType = PropertyType.values.firstWhere(
        (e) => e.name == _selectedPropertyTypeName,
        orElse: () => PropertyType.apartment,
      );

      bool f(String key) => _features[key] ?? false;

      final property = Property(
        id: widget.isEditMode ? widget.propertyId! : '',
        userId: _existingProperty?.userId ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: propertyType,
        listingType: _listingType,
        price: double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        currency: _selectedCurrency,
        location: PropertyLocation(
          city: _selectedCity,
          district: _selectedDistrict,
          neighborhood: _neighborhoodController.text.trim(),
          address: _addressController.text.trim(),
          latitude: _selectedLocation?.latitude ?? _existingProperty?.location.latitude ?? 0,
          longitude: _selectedLocation?.longitude ?? _existingProperty?.location.longitude ?? 0,
        ),
        squareMeters: int.tryParse(_squareMetersController.text) ?? 0,
        rooms: int.tryParse(_roomsController.text) ?? 0,
        bathrooms: int.tryParse(_bathroomsController.text) ?? 1,
        floor: int.tryParse(_floorController.text),
        totalFloors: int.tryParse(_totalFloorsController.text),
        buildingAge: int.tryParse(_buildingAgeController.text),
        hasParking: f('hasParking'),
        hasBalcony: f('hasBalcony'),
        hasFurniture: f('hasFurniture'),
        hasPool: f('hasPool'),
        hasGym: f('hasGym'),
        hasSecurity: f('hasSecurity'),
        hasElevator: f('hasElevator'),
        isSmartHome: f('isSmartHome'),
        roomType: _roomType,
        furnitureStatus: _furnitureStatus,
        heatingType: _heatingType,
        deedType: _deedType,
        netSquareMeters: int.tryParse(_netSquareMetersController.text),
        isOpenToTrade: f('isOpenToTrade'),
        isInComplex: f('isInComplex'),
        hasGarage: f('hasGarage'),
        hasGarden: f('hasGarden'),
        hasPrivatePool: f('hasPrivatePool'),
        hasSharedPool: f('hasSharedPool'),
        hasSecurityCamera: f('hasSecurityCamera'),
        hasTerrace: f('hasTerrace'),
        hasInsulation: f('hasInsulation'),
        hasWaterTank: f('hasWaterTank'),
        hasWell: f('hasWell'),
        hasBarbeque: f('hasBarbeque'),
        hasDoubleGlazing: f('hasDoubleGlazing'),
        hasCoveredParking: f('hasCoveredParking'),
        hasGenerator: f('hasGenerator'),
        hasSandstoneHouse: f('hasSandstoneHouse'),
        isDuplex: f('isDuplex'),
        hasAirConditioning: f('hasAirConditioning'),
        hasShutter: f('hasShutter'),
        hasBuiltinKitchen: f('hasBuiltinKitchen'),
        hasBuiltinWardrobe: f('hasBuiltinWardrobe'),
        hasIntercom: f('hasIntercom'),
        hasFireplace: f('hasFireplace'),
        hasCrown: f('hasCrown'),
        hasLaundryRoom: f('hasLaundryRoom'),
        hasParentBathroom: f('hasParentBathroom'),
        hasParentCloset: f('hasParentCloset'),
        hasNaturalMarble: f('hasNaturalMarble'),
        hasPanelDoor: f('hasPanelDoor'),
        hasParquet: f('hasParquet'),
        hasShower: f('hasShower'),
        hasSteelDoor: f('hasSteelDoor'),
        hasTvInfra: f('hasTvInfra'),
        hasVestibule: f('hasVestibule'),
        hasWallpaper: f('hasWallpaper'),
        hasCeramic: f('hasCeramic'),
        hasFireAlarm: f('hasFireAlarm'),
        hasPantry: f('hasPantry'),
        hasSolarPower: f('hasSolarPower'),
        hasHydrophore: f('hasHydrophore'),
        hasCityView: f('hasCityView'),
        isEastFacing: f('isEastFacing'),
        isCityCenter: f('isCityCenter'),
        hasMountainView: f('hasMountainView'),
        hasNatureView: f('hasNatureView'),
        isNorthFacing: f('isNorthFacing'),
        isSeafront: f('isSeafront'),
        hasSeaView: f('hasSeaView'),
        isSouthFacing: f('isSouthFacing'),
        isWestFacing: f('isWestFacing'),
        amenities: amenities,
        images: imageUrls,
        status: widget.isEditMode ? (_existingProperty?.status ?? PropertyStatus.pending) : PropertyStatus.pending,
        isFeatured: _existingProperty?.isFeatured ?? false,
        isPremium: _existingProperty?.isPremium ?? false,
        viewCount: _existingProperty?.viewCount ?? 0,
        createdAt: _existingProperty?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Property? resultProperty;

      if (widget.isEditMode) {
        // Güncelle - toJson tüm alanları içerir
        final updates = property.toJson();
        updates.remove('status');
        updates.remove('is_featured');
        updates.remove('is_premium');
        updates['images'] = property.images;
        updates['updated_at'] = DateTime.now().toIso8601String();
        resultProperty = await propertyService.updateProperty(widget.propertyId!, updates);
      } else {
        // Yeni oluştur
        resultProperty = await propertyService.createProperty(property);
      }

      if (resultProperty != null) {
        // Provider'ı yenile
        ref.read(propertyListProvider.notifier).refresh();
        ref.read(userPropertiesProvider.notifier).refresh();

        if (mounted) {
          setState(() => _isSubmitting = false);

          // Show success dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _SuccessDialog(
              isEditMode: widget.isEditMode,
              onDone: () {
                Navigator.pop(ctx);
                context.pop();
              },
            ),
          );
        }
      } else {
        throw Exception(widget.isEditMode ? 'İlan güncellenemedi' : 'İlan oluşturulamadı');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(widget.isEditMode ? 'İlan güncellenirken hata oluştu: $e' : 'İlan oluşturulurken hata oluştu: $e');
      }
    }
  }

  void _showError(String message) {
    AppDialogs.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Düzenleme modunda property yüklenirken loading göster
    if (_isLoadingProperty) {
      return Scaffold(
        backgroundColor: EmlakColors.background(isDark),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: EmlakColors.background(isDark),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context, isDark),

              // Progress Indicator
              _buildProgressIndicator(isDark),

              // Step Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1TypeSelection(isDark),
                    _buildStep2BasicInfo(isDark),
                    _buildStep3Location(isDark),
                    _buildStep4Features(isDark),
                    _buildStep5Photos(isDark),
                  ],
                ),
              ),

              // Bottom Navigation
              _buildBottomNavigation(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final stepTitles = [
      'İlan Türü',
      'Temel Bilgiler',
      'Konum',
      'Özellikler',
      'Fotoğraflar',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _previousStep();
              },
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : Colors.grey[800],
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditMode ? 'İlan Düzenle' : 'İlan Ver',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                Text(
                  stepTitles[_currentStep],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: EmlakColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentStep + 1}/$_totalSteps',
              style: TextStyle(
                color: EmlakColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? EmlakColors.primary
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1TypeSelection(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Listing Type
          Text(
            'İlan Tipi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ListingType.values.map((type) {
              final isSelected = _listingType == type;
              final icon = switch (type) {
                ListingType.sale => Icons.sell_rounded,
                ListingType.rent => Icons.vpn_key_rounded,
                ListingType.dailyRent => Icons.calendar_today_rounded,
                ListingType.project => Icons.apartment_rounded,
              };
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: Material(
                  color: isSelected
                      ? type.color
                      : (isDark ? const Color(0xFF1E293B) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _listingType = type);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: type.color.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          type.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Property Type
          Text(
            'Emlak Tipi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: ref.watch(propertyTypesProvider).when(
              data: (types) => types.length,
              loading: () => PropertyType.values.length,
              error: (_, __) => PropertyType.values.length,
            ),
            itemBuilder: (context, index) {
              return ref.watch(propertyTypesProvider).when(
                data: (types) {
                  final type = types[index];
                  final isSelected = _selectedPropertyTypeName == type.name;
                  return Material(
                    color: isSelected
                        ? EmlakColors.primary
                        : (isDark ? const Color(0xFF1E293B) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedPropertyTypeName = type.name;
                          _selectedPropertyTypeModel = type;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                              ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            type.iconData,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  );
                },
                loading: () => _buildFallbackPropertyTypeItem(index, isDark),
                error: (_, __) => _buildFallbackPropertyTypeItem(index, isDark),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2BasicInfo(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // Title
          _buildTextField(
            controller: _titleController,
            label: 'İlan Başlığı',
            hint: 'Örn: Deniz Manzaralı Lüks Daire',
            isDark: isDark,
            maxLength: 100,
          ),

          const SizedBox(height: 20),

          // Description
          _buildTextField(
            controller: _descriptionController,
            label: 'Açıklama',
            hint: 'Emlağınızı detaylı bir şekilde tanımlayın...',
            isDark: isDark,
            maxLines: 5,
            maxLength: 1000,
          ),

          const SizedBox(height: 20),

          // Price with Currency Selector
          Text(
            _listingType == ListingType.rent ? 'Aylık Kira' : 'Satış Fiyatı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Para Birimi Seçici
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 20,
                    ),
                    items: _currencyOptions.map((currency) {
                      return DropdownMenuItem(
                        value: currency['code'],
                        child: Text(
                          '${currency['symbol']} ${currency['code']}',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey[900],
                            fontWeight: FontWeight.w600,
                          ),
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
              // Fiyat Alanı
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[900],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    prefixIcon: Icon(Icons.attach_money_rounded, color: EmlakColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: EmlakColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Size & Rooms Row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _squareMetersController,
                  label: 'Alan (m²)',
                  hint: '0',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _roomsController,
                  label: 'Oda Sayısı',
                  hint: '0',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Bathrooms & Floor Row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _bathroomsController,
                  label: 'Banyo Sayısı',
                  hint: '0',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _floorController,
                  label: 'Bulunduğu Kat',
                  hint: '0',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Total Floors & Building Age Row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _totalFloorsController,
                  label: 'Toplam Kat',
                  hint: '0',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _buildingAgeController,
                  label: 'Bina Yaşı',
                  hint: '0',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Location(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // City Dropdown
          Text(
            'Şehir',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCity,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                items: _cities.map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(
                      city,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value != null) {
                    setState(() {
                      _selectedCity = value;
                      _selectedDistrict = '';
                      _districtList = []; // Eski ilçeleri temizle
                    });
                    await _loadDistricts();
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // District Dropdown
          Text(
            'İlçe',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDistrict.isEmpty ? null : _selectedDistrict,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                hint: Text(
                  'İlçe seçin',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                items: _districtList.map((district) {
                  return DropdownMenuItem(
                    value: district,
                    child: Text(
                      district,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDistrict = value);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Neighborhood
          _buildTextField(
            controller: _neighborhoodController,
            label: 'Mahalle',
            hint: 'Mahalle adını girin',
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          // Address
          _buildTextField(
            controller: _addressController,
            label: 'Adres Detayı (Opsiyonel)',
            hint: 'Cadde, sokak, bina no...',
            isDark: isDark,
            maxLines: 3,
          ),

          const SizedBox(height: 24),

          // Konum Başlık
          Text(
            'Harita Konumu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Haritaya tıklayarak veya aşağıdaki butonları kullanarak konum belirleyin',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // Konum Seçim Butonları
          Row(
            children: [
              // GPS Konumu Al
              Expanded(
                child: Material(
                  color: EmlakColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _isGettingLocation ? null : () {
                      HapticFeedback.selectionClick();
                      _getCurrentLocation();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EmlakColors.primary),
                      ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isGettingLocation)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: EmlakColors.primary,
                            ),
                          )
                        else
                          Icon(Icons.my_location, color: EmlakColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _isGettingLocation ? 'Alınıyor...' : 'Konumumu Al',
                          style: TextStyle(
                            color: EmlakColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(width: 12),
              // Koordinat Gir
              Expanded(
                child: Material(
                  color: EmlakColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showCoordinateDialog();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EmlakColors.secondary),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_location_alt, color: EmlakColors.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Koordinat Gir',
                            style: TextStyle(
                              color: EmlakColors.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Harita
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? _defaultCenter,
                    initialZoom: _selectedLocation != null ? 15 : 10,
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
                      userAgentPackageName: 'com.example.super_app',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 50,
                            height: 50,
                            child: Icon(
                              Icons.location_pin,
                              color: EmlakColors.primary,
                              size: 50,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Konum bilgisi
                if (_selectedLocation != null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: EmlakColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Konum: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedLocation = null;
                                _latitudeController.clear();
                                _longitudeController.clear();
                              });
                            },
                            customBorder: const CircleBorder(),
                            child: const Icon(Icons.close, size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            'İpucu: Haritaya tıklayarak da konum seçebilirsiniz',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Features(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Özellikler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emlağınızın detaylı özelliklerini girin',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          // Oda Tipi
          _buildFormDropdown(label: 'Oda Tipi', value: _roomType, items: const ['1+0','1+1','2+1','2+2','3+1','3+2','4+1','4+2','5','5+1','5+2','5+3','5+4','6+1','6+2','6+3','6+4','7+1','7+2','7+3','8+'], onChanged: (v) => setState(() => _roomType = v), isDark: isDark),
          const SizedBox(height: 16),
          // Eşya Durumu
          _buildFormDropdown(label: 'Eşya Durumu', value: _furnitureStatus, items: const ['Eşyasız','Yarı Eşyalı','Eşyalı','Ful Eşyalı','Sadece Beyaz Eşya'], onChanged: (v) => setState(() => _furnitureStatus = v), isDark: isDark),
          const SizedBox(height: 16),
          // Isıtma Tipi
          _buildFormDropdown(label: 'Isıtma Tipi', value: _heatingType, items: const ['Kombi','Merkezi','Yerden Isıtma','Doğalgaz','Klima','Soba','Güneş Enerjisi','Yok'], onChanged: (v) => setState(() => _heatingType = v), isDark: isDark),
          const SizedBox(height: 16),
          // Tapu Tipi
          _buildFormDropdown(label: 'Tapu Tipi', value: _deedType, items: const ['Kat Mülkiyeti','Kat İrtifakı','Arsa Tapusu','Hisseli','Koçan'], onChanged: (v) => setState(() => _deedType = v), isDark: isDark),
          const SizedBox(height: 16),
          // Net m²
          _buildTextField(controller: _netSquareMetersController, label: 'Net m²', hint: '0', isDark: isDark, keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          // Toggles
          _buildFeatureToggle('Takasa Açık', 'isOpenToTrade', isDark),
          const SizedBox(height: 8),
          _buildFeatureToggle('Site İçerisinde', 'isInComplex', isDark),
          const SizedBox(height: 20),
          // Dış Özellikler
          _buildFeatureSection(title: 'Dış Özellikler', icon: Icons.home_outlined, features: const [
            ['hasGarage','Garaj'],['hasGarden','Bahçe'],['hasPrivatePool','Özel Havuz'],
            ['hasSharedPool','Ortak Havuz'],['hasSecurityCamera','Güvenlik Kamerası'],
            ['hasTerrace','Teras'],['hasInsulation','Isı Yalıtımı'],['hasWaterTank','Su Deposu'],
            ['hasWell','Su Kuyusu'],['hasBarbeque','Barbekü'],['hasDoubleGlazing','Çift Cam'],
            ['hasCoveredParking','Kapalı Otopark'],['hasGenerator','Jeneratör'],
            ['hasElevator','Asansör'],['hasParking','Otopark'],['hasSandstoneHouse','Taş Ev'],
          ], isDark: isDark),
          const SizedBox(height: 12),
          // İç Özellikler
          _buildFeatureSection(title: 'İç Özellikler', icon: Icons.chair_outlined, features: const [
            ['isDuplex','Dubleks'],['hasAirConditioning','Klima'],['hasBalcony','Balkon'],
            ['hasShutter','Kepenk'],['hasBuiltinKitchen','Ankastre Mutfak'],
            ['hasBuiltinWardrobe','Gömme Dolap'],['hasIntercom','İnterkom'],
            ['hasFireplace','Şömine'],['hasCrown','Kartonpiyer'],['hasLaundryRoom','Çamaşır Odası'],
            ['hasParentBathroom','Ebeveyn Banyosu'],['hasParentCloset','Ebeveyn Giyinme'],
            ['hasNaturalMarble','Doğal Mermer'],['hasPanelDoor','Panel Kapı'],
            ['hasParquet','Parke'],['hasShower','Duşakabin'],['hasSteelDoor','Çelik Kapı'],
            ['hasTvInfra','TV Altyapısı'],['hasVestibule','Vestiyer'],['hasWallpaper','Duvar Kağıdı'],
            ['hasCeramic','Seramik'],['hasFireAlarm','Yangın Alarmı'],['hasPantry','Kiler'],
            ['hasSolarPower','Güneş Enerjisi'],['hasHydrophore','Hidrofor'],
          ], isDark: isDark),
          const SizedBox(height: 12),
          // Konum Özellikleri
          _buildFeatureSection(title: 'Konum Özellikleri', icon: Icons.location_on_outlined, features: const [
            ['hasCityView','Şehir Manzarası'],['isEastFacing','Doğu Cepheli'],
            ['isCityCenter','Şehir Merkezi'],['hasMountainView','Dağ Manzarası'],
            ['hasNatureView','Doğa Manzarası'],['isNorthFacing','Kuzey Cepheli'],
            ['isSeafront','Denize Sıfır'],['hasSeaView','Deniz Manzarası'],
            ['isSouthFacing','Güney Cepheli'],['isWestFacing','Batı Cepheli'],
          ], isDark: isDark),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFormDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[300] : Colors.grey[700])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text('Seçiniz', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400])),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: TextStyle(color: isDark ? Colors.white : Colors.grey[900])))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureToggle(String label, String key, bool isDark) {
    final isActive = _features[key] ?? false;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? EmlakColors.primary : (isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      child: SwitchListTile(
        title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.grey[800])),
        value: isActive,
        activeColor: EmlakColors.primary,
        onChanged: (v) => setState(() => _features[key] = v),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFeatureSection({
    required String title,
    required IconData icon,
    required List<List<String>> features,
    required bool isDark,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: EmlakColors.primary, size: 22),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.grey[900])),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features.map((f) {
              final key = f[0];
              final lbl = f[1];
              final sel = _features[key] ?? false;
              return FilterChip(
                label: Text(lbl),
                selected: sel,
                onSelected: (v) => setState(() => _features[key] = v),
                selectedColor: EmlakColors.primary.withValues(alpha: 0.2),
                checkmarkColor: EmlakColors.primary,
                labelStyle: TextStyle(color: sel ? EmlakColors.primary : (isDark ? Colors.grey[400] : Colors.grey[700]), fontWeight: sel ? FontWeight.w600 : FontWeight.w400, fontSize: 13),
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                side: BorderSide(color: sel ? EmlakColors.primary : (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5Photos(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          Text(
            'Fotoğraf Ekleyin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'En az 3, en fazla 20 fotoğraf yükleyebilirsiniz',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),

          const SizedBox(height: 20),

          // Add Photo Buttons
          Row(
            children: [
              // Gallery Button
              Expanded(
                child: Material(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _addPhotos();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: EmlakColors.primary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: EmlakColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.photo_library_rounded,
                            color: EmlakColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Galeriden Seç',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: EmlakColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Çoklu seçim',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(width: 12),
              // Camera Button
              Expanded(
                child: Material(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _takePhoto();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: EmlakColors.secondary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: EmlakColors.secondary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: EmlakColors.secondary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Fotoğraf Çek',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: EmlakColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kamera',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Photo Grid (placeholder)
          if (_uploadedImages.isEmpty && _existingImageUrls.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.amber[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fotoğraf İpuçları',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Aydınlık ve net fotoğraflar ilanınızın görünürlüğünü artırır.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _uploadedImages.length + _existingImageUrls.length,
              itemBuilder: (context, index) {
                // Önce mevcut URL'ler, sonra yeni yüklenen
                final isExisting = index < _existingImageUrls.length;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isExisting
                          ? CachedNetworkImage(
                              imageUrl: _existingImageUrls[index],
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              ),
                            )
                          : Image.memory(
                              _uploadedImages[index - _existingImageUrls.length].bytes,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.red,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isExisting) {
                                _existingImageUrls.removeAt(index);
                              } else {
                                _uploadedImages.removeAt(index - _existingImageUrls.length);
                              }
                            });
                          },
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: EmlakColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Kapak',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // Fallback: DB yüklenemezse enum'dan property type göster
  Widget _buildFallbackPropertyTypeItem(int index, bool isDark) {
    final type = PropertyType.values[index];
    final isSelected = _selectedPropertyTypeName == type.name;
    return Material(
      color: isSelected
          ? EmlakColors.primary
          : (isDark ? const Color(0xFF1E293B) : Colors.grey[100]),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedPropertyTypeName = type.name;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.grey[900],
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: EmlakColors.primary)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EmlakColors.primary,
                width: 2,
              ),
            ),
            counterStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation(BuildContext context, bool isDark) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _previousStep();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'Geri',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _nextStep();
                },
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: EmlakColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: EmlakColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 56,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastStep ? 'İlanı Yayınla' : 'Devam Et',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (!isLastStep) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
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

  Future<void> _addPhotos() async {
    final ImagePicker picker = ImagePicker();

    try {
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (images.isNotEmpty) {
        for (var image in images) {
          if (_uploadedImages.length + _existingImageUrls.length < 20) {
            final bytes = await image.readAsBytes();
            setState(() {
              _uploadedImages.add(_UploadedImage(
                bytes: bytes,
                name: image.name,
              ));
            });
          }
        }
      }
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      if (mounted) {
        AppDialogs.showError(context, 'Fotoğraf seçilirken hata oluştu: $e');
      }
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null && (_uploadedImages.length + _existingImageUrls.length) < 20) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _uploadedImages.add(_UploadedImage(
            bytes: bytes,
            name: photo.name,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Fotoğraf çekilirken hata oluştu: $e');
      }
    }
  }
}


class _SuccessDialog extends StatefulWidget {
  final VoidCallback onDone;
  final bool isEditMode;

  const _SuccessDialog({required this.onDone, this.isEditMode = false});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [EmlakColors.success, EmlakColors.secondary],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tebrikler!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isEditMode
                    ? 'İlanınız başarıyla güncellendi.'
                    : 'İlanınız başarıyla oluşturuldu ve onay için gönderildi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmlakColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tamam',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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

/// Yüklenen fotoğraf için helper sınıf
class _UploadedImage {
  final Uint8List bytes;
  final String name;

  _UploadedImage({required this.bytes, required this.name});
}
