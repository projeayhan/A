import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/providers/emlak_provider.dart';

/// Konut alt tipler (101evler benzeri)
const _konutTypes = [
  PropertyType.apartment,
  PropertyType.villa,
  PropertyType.twinVilla,
  PropertyType.penthouse,
  PropertyType.residence,
  PropertyType.bungalow,
  PropertyType.detachedHouse,
  PropertyType.completeBuilding,
  PropertyType.timeshare,
  PropertyType.derelictBuilding,
  PropertyType.halfConstruction,
];

const _arsaTypes = [PropertyType.land];

const _ticariTypes = [
  PropertyType.office,
  PropertyType.shop,
  PropertyType.building,
];

/// Oda sayısı seçenekleri
const _roomOptions = [
  '1+0', '1+1', '2+1', '2+2', '3+1', '3+2',
  '4+1', '4+2', '5', '5+1', '5+2', '5+3',
  '5+4', '6+1', '6+2', '6+3', '6+4', '7+1',
  '7+2', '7+3', '8+',
];

/// Bina yaşı seçenekleri
const _buildingAgeOptions = [
  '0', 'project', '1', '2', '3', '4', '5',
  '6-10', '11-15', '16-20', '21-25', '26+',
];

const _buildingAgeLabels = {
  '0': '0', 'project': 'Proje Aşamasında',
  '1': '1', '2': '2', '3': '3', '4': '4', '5': '5',
  '6-10': '6 - 10', '11-15': '11 - 15', '16-20': '16 - 20',
  '21-25': '21 - 25', '26+': '26+',
};

/// Eşya durumu seçenekleri
const _furnitureOptions = {
  'Eşyasız': 'Eşyasız',
  'Yarı Eşyalı': 'Yarı Eşyalı',
  'Eşyalı': 'Eşyalı',
  'Ful Eşyalı': 'Ful Eşyalı',
  'Sadece Beyaz Eşya': 'Sadece Beyaz Eşya',
};

/// İlan sahibi seçenekleri
const _ownerOptions = {
  'agency': 'Emlak Acentesinden',
  'construction': 'İnşaat Firmasından',
  'individual': 'Bireysel',
};

/// İlan tarihi seçenekleri
const _dateOptions = {
  'all': 'Tümü',
  'last_24h': 'Son 24 saat',
  'last_3d': 'Son 3 gün',
  'last_1w': 'Son 1 hafta',
  'last_15d': 'Son 15 gün',
};

/// Fiyat preset
const _pricePresets = <String, Map<String, dynamic>>{
  '100k': {'label': '100.000 altı', 'min': 0.0, 'max': 100000.0},
  '100-250k': {'label': '100K - 250K', 'min': 100000.0, 'max': 250000.0},
  '250-500k': {'label': '250K - 500K', 'min': 250000.0, 'max': 500000.0},
  '500k-1m': {'label': '500K - 1M', 'min': 500000.0, 'max': 1000000.0},
  '1-3m': {'label': '1M - 3M', 'min': 1000000.0, 'max': 3000000.0},
  '3-5m': {'label': '3M - 5M', 'min': 3000000.0, 'max': 5000000.0},
  '5m+': {'label': '5M+', 'min': 5000000.0, 'max': null},
};

/// Dış özellikler (model'deki boolean alanlar)
const _exteriorFeatureKeys = <String, String>{
  'hasGarage': 'Garaj',
  'hasGarden': 'Bahçe',
  'hasPrivatePool': 'Özel Havuz',
  'hasSharedPool': 'Ortak Havuz',
  'hasSecurityCamera': 'Güvenlik Kamerası',
  'hasTerrace': 'Teras',
  'hasInsulation': 'Yalıtım',
  'hasWaterTank': 'Su Deposu',
  'hasWell': 'Kuyu',
  'hasBarbeque': 'Barbekü',
  'hasDoubleGlazing': 'Çift Cam',
  'hasCoveredParking': 'Kapalı Otopark',
  'hasGenerator': 'Jeneratör',
  'hasElevator': 'Asansör',
  'hasParking': 'Otopark',
  'hasSandstoneHouse': 'Taş Ev',
};

/// İç özellikler
const _interiorFeatureKeys = <String, String>{
  'isDuplex': 'Dubleks',
  'hasAirConditioning': 'Klima',
  'hasBalcony': 'Balkon',
  'hasShutter': 'Kepenk',
  'hasBuiltinKitchen': 'Ankastre Mutfak',
  'hasBuiltinWardrobe': 'Gömme Dolap',
  'hasIntercom': 'İnterkom',
  'hasFireplace': 'Şömine',
  'hasCrown': 'Kartonpiyer',
  'hasLaundryRoom': 'Çamaşır Odası',
  'hasParentBathroom': 'Ebeveyn Banyosu',
  'hasParentCloset': 'Ebeveyn Giyinme',
  'hasNaturalMarble': 'Doğal Mermer',
  'hasPanelDoor': 'Panel Kapı',
  'hasParquet': 'Parke',
  'hasShower': 'Duşakabin',
  'hasSteelDoor': 'Çelik Kapı',
  'hasTvInfra': 'TV Altyapısı',
  'hasVestibule': 'Vestiyer',
  'hasWallpaper': 'Duvar Kağıdı',
  'hasCeramic': 'Seramik',
  'hasFireAlarm': 'Yangın Alarmı',
  'hasPantry': 'Kiler',
  'hasSolarPower': 'Güneş Enerjisi',
  'hasHydrophore': 'Hidrofor',
};

/// Konum özellikleri
const _locationFeatureKeys = <String, String>{
  'hasCityView': 'Şehir Manzarası',
  'isEastFacing': 'Doğu Cepheli',
  'isCityCenter': 'Şehir Merkezi',
  'hasMountainView': 'Dağ Manzarası',
  'hasNatureView': 'Doğa Manzarası',
  'isNorthFacing': 'Kuzey Cepheli',
  'isSeafront': 'Denize Sıfır',
  'hasSeaView': 'Deniz Manzarası',
  'isSouthFacing': 'Güney Cepheli',
  'isWestFacing': 'Batı Cepheli',
};

class PropertyFilterScreen extends ConsumerStatefulWidget {
  final PropertyFilter initialFilter;

  const PropertyFilterScreen({
    super.key,
    this.initialFilter = const PropertyFilter(),
  });

  @override
  ConsumerState<PropertyFilterScreen> createState() =>
      _PropertyFilterScreenState();
}

class _PropertyFilterScreenState extends ConsumerState<PropertyFilterScreen> {
  // === Temel ===
  ListingType? _listingType;
  String _selectedCity = '';
  String _selectedDistrict = '';
  String? _selectedCategory; // 'konut', 'arsa', 'ticari'
  final Set<PropertyType> _selectedPropertyTypes = {};

  // === Fiyat ===
  double? _minPrice;
  double? _maxPrice;
  String? _selectedPricePreset;
  String? _selectedCurrency;

  // === Alan ===
  int? _minSqm;
  int? _maxSqm;

  // === Detaylı Arama ===
  String _keyword = '';
  final Set<String> _selectedRoomTypes = {};
  final Set<String> _selectedBuildingAges = {};
  final Set<int> _selectedFloors = {};
  final Set<String> _selectedFurnitureStatuses = {};
  final Set<String> _selectedOwnerTypes = {};
  String _listingDateRange = 'all';

  // === Toggle'lar ===
  bool _isOpenToTrade = false;
  bool _isInComplex = false;

  // === Özellikler (boolean) ===
  final Map<String, bool> _features = {};

  // === Data ===
  List<String> _cities = [];
  List<String> _districts = [];

  // === Controllers ===
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _minSqmController = TextEditingController();
  final _maxSqmController = TextEditingController();
  final _keywordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initFromFilter(widget.initialFilter);
    _loadCities();
  }

  void _initFromFilter(PropertyFilter f) {
    _listingType = f.listingType;
    _selectedCity = f.city ?? '';
    _selectedDistrict = f.district ?? '';
    _keyword = f.keyword ?? '';
    _minPrice = f.minPrice;
    _maxPrice = f.maxPrice;
    _selectedCurrency = f.currency;
    _minSqm = f.minSquareMeters;
    _maxSqm = f.maxSquareMeters;
    _isOpenToTrade = f.isOpenToTrade ?? false;
    _isInComplex = f.isInComplex ?? false;
    _listingDateRange = f.listingDateRange ?? 'all';

    // selectedPropertyTypes -> PropertyType enum'lara dönüştür
    if (f.selectedPropertyTypes != null) {
      for (final name in f.selectedPropertyTypes!) {
        try {
          _selectedPropertyTypes.add(PropertyType.values.firstWhere((e) => e.name == name));
        } catch (_) {}
      }
    } else if (f.type != null) {
      _selectedPropertyTypes.add(f.type!);
    }
    if (_selectedPropertyTypes.any((t) => _konutTypes.contains(t))) {
      _selectedCategory = 'konut';
    } else if (_selectedPropertyTypes.any((t) => _arsaTypes.contains(t))) {
      _selectedCategory = 'arsa';
    } else if (_selectedPropertyTypes.any((t) => _ticariTypes.contains(t))) {
      _selectedCategory = 'ticari';
    }

    if (f.roomTypes != null) _selectedRoomTypes.addAll(f.roomTypes!);
    if (f.buildingAges != null) _selectedBuildingAges.addAll(f.buildingAges!);
    if (f.floors != null) _selectedFloors.addAll(f.floors!);
    if (f.furnitureStatuses != null) _selectedFurnitureStatuses.addAll(f.furnitureStatuses!);
    if (f.ownerTypes != null) _selectedOwnerTypes.addAll(f.ownerTypes!);

    // Boolean özellikler
    final boolMap = <String, bool?>{
      // Dış
      'hasGarage': f.hasGarage, 'hasGarden': f.hasGarden,
      'hasPrivatePool': f.hasPrivatePool, 'hasSharedPool': f.hasSharedPool,
      'hasSecurityCamera': f.hasSecurityCamera, 'hasTerrace': f.hasTerrace,
      'hasInsulation': f.hasInsulation, 'hasWaterTank': f.hasWaterTank,
      'hasWell': f.hasWell, 'hasBarbeque': f.hasBarbeque,
      'hasDoubleGlazing': f.hasDoubleGlazing, 'hasCoveredParking': f.hasCoveredParking,
      'hasGenerator': f.hasGenerator, 'hasElevator': f.hasElevator,
      'hasParking': f.hasParking, 'hasSandstoneHouse': f.hasSandstoneHouse,
      // İç
      'isDuplex': f.isDuplex, 'hasAirConditioning': f.hasAirConditioning,
      'hasBalcony': f.hasBalcony, 'hasShutter': f.hasShutter,
      'hasBuiltinKitchen': f.hasBuiltinKitchen, 'hasBuiltinWardrobe': f.hasBuiltinWardrobe,
      'hasIntercom': f.hasIntercom, 'hasFireplace': f.hasFireplace,
      'hasCrown': f.hasCrown, 'hasLaundryRoom': f.hasLaundryRoom,
      'hasParentBathroom': f.hasParentBathroom, 'hasParentCloset': f.hasParentCloset,
      'hasNaturalMarble': f.hasNaturalMarble, 'hasPanelDoor': f.hasPanelDoor,
      'hasParquet': f.hasParquet, 'hasShower': f.hasShower,
      'hasSteelDoor': f.hasSteelDoor, 'hasTvInfra': f.hasTvInfra,
      'hasVestibule': f.hasVestibule, 'hasWallpaper': f.hasWallpaper,
      'hasCeramic': f.hasCeramic, 'hasFireAlarm': f.hasFireAlarm,
      'hasPantry': f.hasPantry, 'hasSolarPower': f.hasSolarPower,
      'hasHydrophore': f.hasHydrophore,
      // Konum
      'hasCityView': f.hasCityView, 'isEastFacing': f.isEastFacing,
      'isCityCenter': f.isCityCenter, 'hasMountainView': f.hasMountainView,
      'hasNatureView': f.hasNatureView, 'isNorthFacing': f.isNorthFacing,
      'isSeafront': f.isSeafront, 'hasSeaView': f.hasSeaView,
      'isSouthFacing': f.isSouthFacing, 'isWestFacing': f.isWestFacing,
    };
    for (final e in boolMap.entries) {
      if (e.value == true) _features[e.key] = true;
    }

    // Controllers
    if (_minPrice != null) _minPriceController.text = _minPrice!.toInt().toString();
    if (_maxPrice != null) _maxPriceController.text = _maxPrice!.toInt().toString();
    if (_minSqm != null) _minSqmController.text = _minSqm.toString();
    if (_maxSqm != null) _maxSqmController.text = _maxSqm.toString();
    if (_keyword.isNotEmpty) _keywordController.text = _keyword;
  }

  Future<void> _loadCities() async {
    try {
      final service = ref.read(propertyServiceProvider);
      final cities = await service.getCities();
      if (mounted) {
        setState(() => _cities = cities);
        if (_selectedCity.isNotEmpty) _loadDistricts();
      }
    } catch (_) {}
  }

  Future<void> _loadDistricts() async {
    if (_selectedCity.isEmpty) {
      setState(() => _districts = []);
      return;
    }
    try {
      final service = ref.read(propertyServiceProvider);
      final districts = await service.getDistrictsByCity(_selectedCity);
      if (mounted) setState(() => _districts = districts);
    } catch (_) {}
  }

  bool? _fb(String key) => _features[key] == true ? true : null;

  PropertyFilter _buildFilter() {
    return PropertyFilter(
      listingType: _listingType,
      selectedPropertyTypes: _selectedPropertyTypes.isNotEmpty
          ? _selectedPropertyTypes.map((t) => t.name).toSet()
          : null,
      city: _selectedCity.isEmpty ? null : _selectedCity,
      district: _selectedDistrict.isEmpty ? null : _selectedDistrict,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      currency: _selectedCurrency,
      minSquareMeters: _minSqm,
      maxSquareMeters: _maxSqm,
      keyword: _keyword.isEmpty ? null : _keyword,
      roomTypes: _selectedRoomTypes.isNotEmpty ? Set.from(_selectedRoomTypes) : null,
      buildingAges: _selectedBuildingAges.isNotEmpty ? Set.from(_selectedBuildingAges) : null,
      floors: _selectedFloors.isNotEmpty ? Set.from(_selectedFloors) : null,
      furnitureStatuses: _selectedFurnitureStatuses.isNotEmpty ? Set.from(_selectedFurnitureStatuses) : null,
      ownerTypes: _selectedOwnerTypes.isNotEmpty ? Set.from(_selectedOwnerTypes) : null,
      listingDateRange: _listingDateRange == 'all' ? null : _listingDateRange,
      isOpenToTrade: _isOpenToTrade ? true : null,
      isInComplex: _isInComplex ? true : null,
      // Dış
      hasGarage: _fb('hasGarage'),
      hasGarden: _fb('hasGarden'),
      hasPrivatePool: _fb('hasPrivatePool'),
      hasSharedPool: _fb('hasSharedPool'),
      hasSecurityCamera: _fb('hasSecurityCamera'),
      hasTerrace: _fb('hasTerrace'),
      hasInsulation: _fb('hasInsulation'),
      hasWaterTank: _fb('hasWaterTank'),
      hasWell: _fb('hasWell'),
      hasBarbeque: _fb('hasBarbeque'),
      hasDoubleGlazing: _fb('hasDoubleGlazing'),
      hasCoveredParking: _fb('hasCoveredParking'),
      hasGenerator: _fb('hasGenerator'),
      hasElevator: _fb('hasElevator'),
      hasParking: _fb('hasParking'),
      hasSandstoneHouse: _fb('hasSandstoneHouse'),
      // İç
      isDuplex: _fb('isDuplex'),
      hasAirConditioning: _fb('hasAirConditioning'),
      hasBalcony: _fb('hasBalcony'),
      hasShutter: _fb('hasShutter'),
      hasBuiltinKitchen: _fb('hasBuiltinKitchen'),
      hasBuiltinWardrobe: _fb('hasBuiltinWardrobe'),
      hasIntercom: _fb('hasIntercom'),
      hasFireplace: _fb('hasFireplace'),
      hasCrown: _fb('hasCrown'),
      hasLaundryRoom: _fb('hasLaundryRoom'),
      hasParentBathroom: _fb('hasParentBathroom'),
      hasParentCloset: _fb('hasParentCloset'),
      hasNaturalMarble: _fb('hasNaturalMarble'),
      hasPanelDoor: _fb('hasPanelDoor'),
      hasParquet: _fb('hasParquet'),
      hasShower: _fb('hasShower'),
      hasSteelDoor: _fb('hasSteelDoor'),
      hasTvInfra: _fb('hasTvInfra'),
      hasVestibule: _fb('hasVestibule'),
      hasWallpaper: _fb('hasWallpaper'),
      hasCeramic: _fb('hasCeramic'),
      hasFireAlarm: _fb('hasFireAlarm'),
      hasPantry: _fb('hasPantry'),
      hasSolarPower: _fb('hasSolarPower'),
      hasHydrophore: _fb('hasHydrophore'),
      // Konum
      hasCityView: _fb('hasCityView'),
      isEastFacing: _fb('isEastFacing'),
      isCityCenter: _fb('isCityCenter'),
      hasMountainView: _fb('hasMountainView'),
      hasNatureView: _fb('hasNatureView'),
      isNorthFacing: _fb('isNorthFacing'),
      isSeafront: _fb('isSeafront'),
      hasSeaView: _fb('hasSeaView'),
      isSouthFacing: _fb('isSouthFacing'),
      isWestFacing: _fb('isWestFacing'),
    );
  }

  void _clearAll() {
    setState(() {
      _listingType = null;
      _selectedCity = '';
      _selectedDistrict = '';
      _selectedCategory = null;
      _selectedPropertyTypes.clear();
      _minPrice = null;
      _maxPrice = null;
      _selectedPricePreset = null;
      _selectedCurrency = null;
      _minSqm = null;
      _maxSqm = null;
      _keyword = '';
      _selectedRoomTypes.clear();
      _selectedBuildingAges.clear();
      _selectedFloors.clear();
      _selectedFurnitureStatuses.clear();
      _selectedOwnerTypes.clear();
      _listingDateRange = 'all';
      _isOpenToTrade = false;
      _isInComplex = false;
      _features.clear();
      _districts = [];
      _minPriceController.clear();
      _maxPriceController.clear();
      _minSqmController.clear();
      _maxSqmController.clear();
      _keywordController.clear();
    });
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minSqmController.dispose();
    _maxSqmController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount = _buildFilter().activeCount;

    return Scaffold(
      backgroundColor: EmlakColors.background(isDark),
      appBar: AppBar(
        backgroundColor: EmlakColors.background(isDark),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.bookmark_outline, size: 20, color: EmlakColors.primary),
            const SizedBox(width: 8),
            Text(
              'Bu Aramayı Kaydet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: EmlakColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
        actions: [
          if (activeCount > 0)
            TextButton(
              onPressed: _clearAll,
              child: Text('Temizle', style: TextStyle(color: EmlakColors.error, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. İlan Tipi Tab'ları
                  _buildListingTypeTabs(isDark),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Lokasyon
                        _buildSectionHeader('Lokasyon', Icons.location_on_outlined, isDark),
                        const SizedBox(height: 8),
                        _buildLocationSection(isDark),
                        const SizedBox(height: 20),

                        // 3. Emlak Tipi
                        _buildSectionHeader('Emlak Tipi', Icons.apartment_rounded, isDark),
                        const SizedBox(height: 8),
                        _buildPropertyTypeSection(isDark),
                        const SizedBox(height: 20),

                        // 4. Fiyat Aralığı
                        _buildSectionHeader('Fiyat Aralığı', Icons.monetization_on_outlined, isDark),
                        const SizedBox(height: 8),
                        _buildPriceSection(isDark),
                        const SizedBox(height: 20),

                        // 5. Alan m²
                        _buildSectionHeader('Alan - m²', Icons.straighten_outlined, isDark),
                        const SizedBox(height: 8),
                        _buildRangeRow(_minSqmController, _maxSqmController, isDark,
                          onMinChanged: (v) => _minSqm = v.isNotEmpty ? int.tryParse(v) : null,
                          onMaxChanged: (v) => _maxSqm = v.isNotEmpty ? int.tryParse(v) : null,
                        ),
                        const SizedBox(height: 16),

                        // 6. Detaylı Arama
                        _buildExpandableSection('Detaylı Arama', Icons.tune_rounded, isDark,
                          _buildDetailedSearchContent(isDark)),
                        const SizedBox(height: 8),

                        // 7. Toggle'lar
                        _buildToggleRow('Sadece Takasa Açık', _isOpenToTrade, isDark,
                            (v) => setState(() => _isOpenToTrade = v)),
                        Divider(color: EmlakColors.border(isDark), height: 1),
                        _buildToggleRow('Site İçerisinde', _isInComplex, isDark,
                            (v) => setState(() => _isInComplex = v)),
                        Divider(color: EmlakColors.border(isDark), height: 1),
                        const SizedBox(height: 8),

                        // 8. Dış Özellikler
                        _buildExpandableSection('Dış Özellikler', Icons.yard_outlined, isDark,
                          _buildBooleanFeatureGrid(_exteriorFeatureKeys, isDark)),
                        const SizedBox(height: 8),

                        // 9. İç Özellikler
                        _buildExpandableSection('İç Özellikler', Icons.chair_outlined, isDark,
                          _buildBooleanFeatureGrid(_interiorFeatureKeys, isDark)),
                        const SizedBox(height: 8),

                        // 10. Konum Özellikleri
                        _buildExpandableSection('Konum Özellikleri', Icons.explore_outlined, isDark,
                          _buildBooleanFeatureGrid(_locationFeatureKeys, isDark)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(isDark, activeCount),
        ],
      ),
    );
  }

  // ==========================================
  // Section Header
  // ==========================================
  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: EmlakColors.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: EmlakColors.textPrimary(isDark),
        )),
      ],
    );
  }

  // ==========================================
  // 1. İlan Tipi Tab'ları (4 tab)
  // ==========================================
  Widget _buildListingTypeTabs(bool isDark) {
    final types = [
      (ListingType.sale, 'Satılık'),
      (ListingType.rent, 'Kiralık'),
      (ListingType.dailyRent, 'Günlük Kiralık'),
      (ListingType.project, 'Projeler'),
    ];
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: EmlakColors.surface(isDark),
        border: Border(bottom: BorderSide(color: EmlakColors.border(isDark))),
      ),
      child: Row(
        children: types.map((t) {
          final sel = _listingType == t.$1;
          return Expanded(
            child: Material(
              color: sel ? EmlakColors.primary : Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _listingType = _listingType == t.$1 ? null : t.$1);
                },
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(t.$2, style: TextStyle(
                      color: sel ? Colors.white : EmlakColors.textPrimary(isDark),
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    )),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // 2. Lokasyon (2 dropdown)
  // ==========================================
  Widget _buildLocationSection(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildDropdown(
          value: _selectedCity.isEmpty ? null : _selectedCity,
          hint: 'Şehir Seçiniz', items: _cities, isDark: isDark,
          onChanged: (v) { setState(() { _selectedCity = v ?? ''; _selectedDistrict = ''; }); _loadDistricts(); },
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildDropdown(
          value: _selectedDistrict.isEmpty ? null : _selectedDistrict,
          hint: 'Bölge Seçiniz', items: _districts, isDark: isDark,
          onChanged: (v) => setState(() => _selectedDistrict = v ?? ''),
        )),
      ],
    );
  }

  // ==========================================
  // 3. Emlak Tipi
  // ==========================================
  Widget _buildPropertyTypeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _buildCategoryBtn('Konut', 'konut', isDark),
          const SizedBox(width: 8),
          _buildCategoryBtn('Arsa', 'arsa', isDark),
          const SizedBox(width: 8),
          _buildCategoryBtn('Ticari Emlak', 'ticari', isDark),
        ]),
        if (_selectedCategory != null) ...[
          const SizedBox(height: 12),
          _buildPropertySubTypes(isDark),
        ],
      ],
    );
  }

  Widget _buildCategoryBtn(String label, String cat, bool isDark) {
    final sel = _selectedCategory == cat;
    return Expanded(
      child: Material(
        color: sel ? EmlakColors.primary : EmlakColors.surface(isDark),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (_selectedCategory == cat) { _selectedCategory = null; _selectedPropertyTypes.clear(); }
              else { _selectedCategory = cat; _selectedPropertyTypes.clear(); }
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? EmlakColors.primary : EmlakColors.border(isDark)),
            ),
            child: Center(child: Text(label, style: TextStyle(
              color: sel ? Colors.white : EmlakColors.textSecondary(isDark),
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 13,
            ))),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertySubTypes(bool isDark) {
    final types = _selectedCategory == 'konut' ? _konutTypes
        : _selectedCategory == 'arsa' ? _arsaTypes : _ticariTypes;
    final w = (MediaQuery.of(context).size.width - 32) / 2;
    return Wrap(
      children: types.map((pt) {
        final sel = _selectedPropertyTypes.contains(pt);
        return SizedBox(width: w, child: _buildCheckboxTile(pt.label, sel, isDark, () {
          setState(() { if (sel) _selectedPropertyTypes.remove(pt); else _selectedPropertyTypes.add(pt); });
        }));
      }).toList(),
    );
  }

  // ==========================================
  // 4. Fiyat Aralığı
  // ==========================================
  Widget _buildPriceSection(bool isDark) {
    const currencyOptions = [
      {'code': 'TL', 'symbol': '₺'},
      {'code': 'USD', 'symbol': '\$'},
      {'code': 'EUR', 'symbol': '€'},
      {'code': 'GBP', 'symbol': '£'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Para Birimi Seçici
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // "Tümü" butonu
            _buildCurrencyChip(null, 'Tümü', isDark),
            ...currencyOptions.map((c) =>
              _buildCurrencyChip(c['code']!, '${c['symbol']} ${c['code']}', isDark)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          value: _selectedPricePreset,
          hint: 'Lütfen Seçiniz',
          items: _pricePresets.keys.toList(), isDark: isDark,
          itemLabelBuilder: (k) => _pricePresets[k]!['label'] as String,
          onChanged: (v) => setState(() {
            _selectedPricePreset = v;
            if (v != null) {
              final p = _pricePresets[v]!;
              final minVal = p['min'] as double?;
              _minPrice = (minVal != null && minVal > 0) ? minVal : null;
              _maxPrice = p['max'] as double?;
              _minPriceController.text = _minPrice?.toInt().toString() ?? '';
              _maxPriceController.text = _maxPrice?.toInt().toString() ?? '';
            }
          }),
        ),
        const SizedBox(height: 10),
        _buildRangeRow(_minPriceController, _maxPriceController, isDark,
          onMinChanged: (v) { _minPrice = v.isNotEmpty ? double.tryParse(v) : null; _selectedPricePreset = null; },
          onMaxChanged: (v) { _maxPrice = v.isNotEmpty ? double.tryParse(v) : null; _selectedPricePreset = null; },
        ),
      ],
    );
  }

  Widget _buildCurrencyChip(String? code, String label, bool isDark) {
    final isSelected = _selectedCurrency == code;
    return Material(
      color: isSelected
          ? EmlakColors.primary
          : (isDark ? const Color(0xFF1E293B) : Colors.grey[100]),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedCurrency = code);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? EmlakColors.primary
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 6. Detaylı Arama
  // ==========================================
  Widget _buildDetailedSearchContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInput(_keywordController, 'Anahtar kelime ile arama yap', isDark,
          isNumeric: false, prefixIcon: Icons.search,
          onChanged: (v) => _keyword = v),
        const SizedBox(height: 16),
        _buildSubExpand('Oda Sayısı', isDark, _buildStringCheckboxGrid(_roomOptions, _selectedRoomTypes, isDark, 3)),
        _buildSubExpand('Bina Yaşı', isDark, _buildStringCheckboxGrid(
          _buildingAgeOptions, _selectedBuildingAges, isDark, 3, labelMap: _buildingAgeLabels)),
        _buildSubExpand('Kat', isDark, _buildFloorGrid(isDark)),
        _buildSubExpand('Eşya Durumu', isDark, _buildStringCheckboxGrid(
          _furnitureOptions.keys.toList(), _selectedFurnitureStatuses, isDark, 2, labelMap: _furnitureOptions)),
        _buildSubExpand('İlan Sahibi', isDark, _buildOwnerSection(isDark)),
        _buildSubExpand('İlan Ekleme Tarihi', isDark, _buildDateRadio(isDark)),
      ],
    );
  }

  Widget _buildStringCheckboxGrid(List<String> opts, Set<String> sel, bool isDark, int cols, {Map<String, String>? labelMap}) {
    final w = (MediaQuery.of(context).size.width - 48) / cols;
    return Wrap(
      children: opts.map((o) {
        final s = sel.contains(o);
        return SizedBox(width: w, child: _buildCheckboxTile(
          labelMap?[o] ?? o, s, isDark,
          () => setState(() { if (s) sel.remove(o); else sel.add(o); }),
        ));
      }).toList(),
    );
  }

  Widget _buildFloorGrid(bool isDark) {
    final w = (MediaQuery.of(context).size.width - 48) / 3;
    return Wrap(
      children: List.generate(16, (i) => i).map((f) {
        final s = _selectedFloors.contains(f);
        return SizedBox(width: w, child: _buildCheckboxTile('$f', s, isDark,
          () => setState(() { if (s) _selectedFloors.remove(f); else _selectedFloors.add(f); }),
        ));
      }).toList(),
    );
  }

  Widget _buildOwnerSection(bool isDark) {
    final w = (MediaQuery.of(context).size.width - 48) / 3;
    return Wrap(
      children: _ownerOptions.entries.map((e) {
        final s = _selectedOwnerTypes.contains(e.key);
        return SizedBox(width: w, child: _buildCheckboxTile(e.value, s, isDark, () {
          setState(() {
            if (s) _selectedOwnerTypes.remove(e.key);
            else _selectedOwnerTypes.add(e.key);
          });
        }));
      }).toList(),
    );
  }

  Widget _buildDateRadio(bool isDark) {
    final w = (MediaQuery.of(context).size.width - 48) / 3;
    return Wrap(
      children: _dateOptions.entries.map((e) {
        final s = _listingDateRange == e.key;
        return SizedBox(width: w, child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _listingDateRange = e.key);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(s ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18, color: s ? EmlakColors.primary : EmlakColors.textTertiary(isDark)),
              const SizedBox(width: 6),
              Flexible(child: Text(e.value, style: TextStyle(
                fontSize: 12, color: s ? EmlakColors.primary : EmlakColors.textPrimary(isDark),
                fontWeight: s ? FontWeight.w600 : FontWeight.w400,
              ))),
            ]),
          ),
        ));
      }).toList(),
    );
  }

  // ==========================================
  // Boolean Feature Grid
  // ==========================================
  Widget _buildBooleanFeatureGrid(Map<String, String> featureMap, bool isDark) {
    final w = (MediaQuery.of(context).size.width - 48) / 2;
    return Wrap(
      children: featureMap.entries.map((e) {
        final s = _features[e.key] == true;
        return SizedBox(width: w, child: _buildCheckboxTile(e.value, s, isDark, () {
          setState(() { if (s) _features.remove(e.key); else _features[e.key] = true; });
        }));
      }).toList(),
    );
  }

  // ==========================================
  // Bottom Bar
  // ==========================================
  Widget _buildBottomBar(bool isDark, int activeCount) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: EmlakColors.card(isDark),
        border: Border(top: BorderSide(color: EmlakColors.border(isDark))),
      ),
      child: Row(children: [
        if (activeCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: EmlakColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$activeCount filtre', style: TextStyle(
              color: EmlakColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(child: ElevatedButton(
          onPressed: () => Navigator.pop(context, _buildFilter()),
          style: ElevatedButton.styleFrom(
            backgroundColor: EmlakColors.primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Uygula', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        )),
      ]),
    );
  }

  // ==========================================
  // REUSABLE WIDGETS
  // ==========================================

  Widget _buildCheckboxTile(String label, bool sel, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: sel ? EmlakColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: sel ? EmlakColors.primary : EmlakColors.border(isDark), width: 1.5),
            ),
            child: sel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: TextStyle(
            fontSize: 13,
            color: sel ? EmlakColors.textPrimary(isDark) : EmlakColors.textSecondary(isDark),
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
          ))),
        ]),
      ),
    );
  }

  Widget _buildExpandableSection(String title, IconData icon, bool isDark, Widget content) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        leading: Icon(icon, size: 20, color: EmlakColors.primary),
        title: Text(title, style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: EmlakColors.textPrimary(isDark))),
        trailing: Icon(Icons.add, size: 20, color: EmlakColors.textSecondary(isDark)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: EmlakColors.border(isDark)),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: EmlakColors.border(isDark)),
        ),
        backgroundColor: EmlakColors.card(isDark),
        collapsedBackgroundColor: EmlakColors.card(isDark),
        children: [content],
      ),
    );
  }

  Widget _buildSubExpand(String title, bool isDark, Widget content) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(title, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: EmlakColors.textPrimary(isDark))),
        trailing: Icon(Icons.add, size: 18, color: EmlakColors.textSecondary(isDark)),
        children: [content],
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, bool isDark, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: EmlakColors.textPrimary(isDark))),
        Switch.adaptive(value: value, onChanged: onChanged,
          activeTrackColor: EmlakColors.primary, activeThumbColor: Colors.white),
      ]),
    );
  }

  Widget _buildDropdown({
    required String? value, required String hint, required List<String> items,
    required bool isDark, required ValueChanged<String?> onChanged,
    String Function(String)? itemLabelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: EmlakColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EmlakColors.border(isDark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: EmlakColors.textTertiary(isDark), fontSize: 14)),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: EmlakColors.textSecondary(isDark)),
          dropdownColor: EmlakColors.card(isDark),
          items: items.map((i) => DropdownMenuItem(
            value: i,
            child: Text(itemLabelBuilder?.call(i) ?? i,
              style: TextStyle(color: EmlakColors.textPrimary(isDark), fontSize: 14)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRangeRow(TextEditingController minC, TextEditingController maxC, bool isDark, {
    required ValueChanged<String> onMinChanged, required ValueChanged<String> onMaxChanged,
  }) {
    return Row(children: [
      Expanded(child: _buildInput(minC, 'En Az', isDark, onChanged: onMinChanged)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('-', style: TextStyle(color: EmlakColors.textSecondary(isDark), fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      Expanded(child: _buildInput(maxC, 'En Çok', isDark, onChanged: onMaxChanged)),
    ]);
  }

  Widget _buildInput(TextEditingController c, String hint, bool isDark, {
    required ValueChanged<String> onChanged, bool isNumeric = true, IconData? prefixIcon,
  }) {
    return TextField(
      controller: c,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: EmlakColors.textPrimary(isDark), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: EmlakColors.textTertiary(isDark), fontSize: 14),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: EmlakColors.textTertiary(isDark)) : null,
        filled: true, fillColor: EmlakColors.surface(isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EmlakColors.border(isDark))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EmlakColors.border(isDark))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EmlakColors.primary)),
      ),
      onChanged: onChanged,
    );
  }
}
