import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/emlak/emlak_models.dart';
import '../../services/emlak/property_service.dart';

// ============================================
// PROPERTY SERVICE PROVIDER
// ============================================

final propertyServiceProvider = Provider<PropertyService>((ref) {
  return PropertyService();
});

// ============================================
// İLAN LİSTESİ PROVIDER
// ============================================

class PropertyListState {
  final List<Property> properties;
  final bool isLoading;
  final String? error;
  final PropertyFilter filter;
  final SortOption sortOption;
  final bool hasMore;
  final int currentPage;

  const PropertyListState({
    this.properties = const [],
    this.isLoading = false,
    this.error,
    this.filter = const PropertyFilter(),
    this.sortOption = SortOption.newest,
    this.hasMore = true,
    this.currentPage = 0,
  });

  PropertyListState copyWith({
    List<Property>? properties,
    bool? isLoading,
    String? error,
    PropertyFilter? filter,
    SortOption? sortOption,
    bool? hasMore,
    int? currentPage,
  }) {
    return PropertyListState(
      properties: properties ?? this.properties,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filter: filter ?? this.filter,
      sortOption: sortOption ?? this.sortOption,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PropertyListNotifier extends StateNotifier<PropertyListState> {
  final PropertyService _service;
  static const int _pageSize = 20;

  PropertyListNotifier(this._service) : super(const PropertyListState()) {
    loadProperties();
  }

  Future<void> loadProperties({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: refresh ? 0 : state.currentPage,
      properties: refresh ? [] : state.properties,
    );

    try {
      final properties = await _service.getProperties(
        filter: state.filter,
        sortOption: state.sortOption,
        limit: _pageSize,
        offset: refresh ? 0 : state.currentPage * _pageSize,
      );

      state = state.copyWith(
        properties: refresh ? properties : [...state.properties, ...properties],
        isLoading: false,
        hasMore: properties.length >= _pageSize,
        currentPage: refresh ? 1 : state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadProperties(refresh: true);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadProperties();
  }

  void setFilter(PropertyFilter filter) {
    state = state.copyWith(filter: filter);
    loadProperties(refresh: true);
  }

  void setSortOption(SortOption sortOption) {
    state = state.copyWith(sortOption: sortOption);
    loadProperties(refresh: true);
  }

  void clearFilters() {
    state = state.copyWith(filter: const PropertyFilter());
    loadProperties(refresh: true);
  }
}

final propertyListProvider =
    StateNotifierProvider<PropertyListNotifier, PropertyListState>((ref) {
  final service = ref.watch(propertyServiceProvider);
  return PropertyListNotifier(service);
});

// ============================================
// ÖNE ÇIKAN İLANLAR PROVIDER
// ============================================

final featuredPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getFeaturedProperties(limit: 10);
});

// ============================================
// PREMİUM İLANLAR PROVIDER
// ============================================

final premiumPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getPremiumProperties(limit: 10);
});

// ============================================
// İLAN DETAY PROVIDER
// ============================================

final propertyDetailProvider =
    FutureProvider.family<Property?, String>((ref, propertyId) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getPropertyById(propertyId);
});

// ============================================
// BENZER İLANLAR PROVIDER
// ============================================

final similarPropertiesProvider =
    FutureProvider.family<List<Property>, Property>((ref, property) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getSimilarProperties(property, limit: 4);
});

// ============================================
// KULLANICI İLANLARI PROVIDER
// ============================================

class UserPropertiesState {
  final List<Property> activeProperties;
  final List<Property> pendingProperties;
  final List<Property> closedProperties;
  final List<Property> rejectedProperties;
  final bool isLoading;
  final String? error;

  const UserPropertiesState({
    this.activeProperties = const [],
    this.pendingProperties = const [],
    this.closedProperties = const [],
    this.rejectedProperties = const [],
    this.isLoading = false,
    this.error,
  });

  UserPropertiesState copyWith({
    List<Property>? activeProperties,
    List<Property>? pendingProperties,
    List<Property>? closedProperties,
    List<Property>? rejectedProperties,
    bool? isLoading,
    String? error,
  }) {
    return UserPropertiesState(
      activeProperties: activeProperties ?? this.activeProperties,
      pendingProperties: pendingProperties ?? this.pendingProperties,
      closedProperties: closedProperties ?? this.closedProperties,
      rejectedProperties: rejectedProperties ?? this.rejectedProperties,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get totalCount =>
      activeProperties.length + pendingProperties.length + closedProperties.length + rejectedProperties.length;
}

class UserPropertiesNotifier extends StateNotifier<UserPropertiesState> {
  final PropertyService _service;

  UserPropertiesNotifier(this._service) : super(const UserPropertiesState()) {
    loadUserProperties();
  }

  Future<void> loadUserProperties() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final active = await _service.getUserProperties(status: PropertyStatus.active);
      final pending = await _service.getUserProperties(status: PropertyStatus.pending);
      final rejected = await _service.getUserProperties(status: PropertyStatus.rejected);

      // Kapalı ilanlar: satıldı, kiralandı, rezerve
      final sold = await _service.getUserProperties(status: PropertyStatus.sold);
      final rented = await _service.getUserProperties(status: PropertyStatus.rented);
      final reserved = await _service.getUserProperties(status: PropertyStatus.reserved);

      state = state.copyWith(
        activeProperties: active,
        pendingProperties: pending,
        rejectedProperties: rejected,
        closedProperties: [...sold, ...rented, ...reserved],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadUserProperties();
  }

  Future<bool> updatePropertyStatus(String propertyId, PropertyStatus status) async {
    final success = await _service.updatePropertyStatus(propertyId, status);
    if (success) {
      await loadUserProperties();
    }
    return success;
  }

  Future<bool> deleteProperty(String propertyId) async {
    final success = await _service.deleteProperty(propertyId);
    if (success) {
      await loadUserProperties();
    }
    return success;
  }
}

final userPropertiesProvider =
    StateNotifierProvider<UserPropertiesNotifier, UserPropertiesState>((ref) {
  final service = ref.watch(propertyServiceProvider);
  return UserPropertiesNotifier(service);
});

// ============================================
// ARAMA PROVIDER
// ============================================

class PropertySearchState {
  final List<Property> results;
  final String query;
  final bool isLoading;
  final String? error;
  final PropertyFilter filter;
  final SortOption sortOption;

  const PropertySearchState({
    this.results = const [],
    this.query = '',
    this.isLoading = false,
    this.error,
    this.filter = const PropertyFilter(),
    this.sortOption = SortOption.newest,
  });

  PropertySearchState copyWith({
    List<Property>? results,
    String? query,
    bool? isLoading,
    String? error,
    PropertyFilter? filter,
    SortOption? sortOption,
  }) {
    return PropertySearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filter: filter ?? this.filter,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

class PropertySearchNotifier extends StateNotifier<PropertySearchState> {
  final PropertyService _service;

  PropertySearchNotifier(this._service) : super(const PropertySearchState());

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(results: [], query: '');
      return;
    }

    state = state.copyWith(isLoading: true, query: query, error: null);

    try {
      final results = await _service.searchProperties(
        searchQuery: query,
        filter: state.filter,
        sortOption: state.sortOption,
      );

      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setFilter(PropertyFilter filter) {
    state = state.copyWith(filter: filter);
    if (state.query.isNotEmpty) {
      search(state.query);
    }
  }

  void setSortOption(SortOption sortOption) {
    state = state.copyWith(sortOption: sortOption);
    if (state.query.isNotEmpty) {
      search(state.query);
    }
  }

  void clear() {
    state = const PropertySearchState();
  }
}

final propertySearchProvider =
    StateNotifierProvider<PropertySearchNotifier, PropertySearchState>((ref) {
  final service = ref.watch(propertyServiceProvider);
  return PropertySearchNotifier(service);
});

// ============================================
// ŞEHİR VE İLÇE PROVIDERs
// ============================================

final citiesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getCities();
});

final districtsByCityProvider =
    FutureProvider.family<List<String>, String>((ref, city) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getDistrictsByCity(city);
});

// ============================================
// İLAN İSTATİSTİKLERİ PROVIDER
// ============================================

final propertyViewStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, propertyId) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getPropertyViewStats(propertyId);
});

// ============================================
// AKTİF İLAN SAYISI PROVIDER
// ============================================

final userActiveListingsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getUserActiveListingsCount();
});

// ============================================
// DİNAMİK EMLAK TÜRLERİ PROVIDER (DB'den)
// ============================================

final propertyTypesProvider = FutureProvider<List<PropertyTypeModel>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  final data = await service.getPropertyTypes();
  return data.map((json) => PropertyTypeModel.fromJson(json)).toList();
});

// ============================================
// DİNAMİK ÖZELLİKLER (AMENITIES) PROVIDER (DB'den)
// ============================================

final amenitiesProvider = FutureProvider<List<AmenityModel>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  final data = await service.getAmenities();
  return data.map((json) => AmenityModel.fromJson(json)).toList();
});

// Kategoriye göre özellikler
final amenitiesByCategoryProvider = FutureProvider.family<List<AmenityModel>, String?>((ref, category) async {
  final service = ref.watch(propertyServiceProvider);
  final data = await service.getAmenities(category: category);
  return data.map((json) => AmenityModel.fromJson(json)).toList();
});

// ============================================
// EMLAK AYARLARI PROVIDER (DB'den)
// ============================================

final emlakSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getSettings();
});
