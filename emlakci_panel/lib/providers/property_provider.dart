import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/property_service.dart';
import '../models/emlak_models.dart';

// ============================================
// PROPERTY SERVICE PROVIDER
// ============================================

final propertyServiceProvider = Provider<PropertyService>((ref) {
  return PropertyService();
});

// ============================================
// USER PROPERTIES STATE
// ============================================

class UserPropertiesState {
  final List<Property> allProperties;
  final bool isLoading;
  final String? error;

  const UserPropertiesState({
    this.allProperties = const [],
    this.isLoading = false,
    this.error,
  });

  List<Property> get activeProperties =>
      allProperties.where((p) => p.status == PropertyStatus.active).toList();

  List<Property> get pendingProperties =>
      allProperties.where((p) => p.status == PropertyStatus.pending).toList();

  List<Property> get soldProperties =>
      allProperties.where((p) => p.status == PropertyStatus.sold).toList();

  List<Property> get rentedProperties =>
      allProperties.where((p) => p.status == PropertyStatus.rented).toList();

  UserPropertiesState copyWith({
    List<Property>? allProperties,
    bool? isLoading,
    String? error,
  }) {
    return UserPropertiesState(
      allProperties: allProperties ?? this.allProperties,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ============================================
// USER PROPERTIES NOTIFIER
// ============================================

class UserPropertiesNotifier extends StateNotifier<UserPropertiesState> {
  final PropertyService _service;

  UserPropertiesNotifier(this._service) : super(const UserPropertiesState()) {
    loadProperties();
  }

  Future<void> loadProperties() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final properties = await _service.getUserProperties();
      state = state.copyWith(allProperties: properties, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createProperty(Property property) async {
    try {
      await _service.createProperty(property);
      await loadProperties();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateProperty(String propertyId, Map<String, dynamic> updates) async {
    try {
      await _service.updateProperty(propertyId, updates);
      await loadProperties();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteProperty(String propertyId) async {
    try {
      await _service.deleteProperty(propertyId);
      await loadProperties();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updatePropertyStatus(String propertyId, PropertyStatus status) async {
    try {
      await _service.updatePropertyStatus(propertyId, status);
      await loadProperties();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// ============================================
// USER PROPERTIES PROVIDER
// ============================================

final userPropertiesProvider =
    StateNotifierProvider<UserPropertiesNotifier, UserPropertiesState>((ref) {
  final service = ref.watch(propertyServiceProvider);
  return UserPropertiesNotifier(service);
});

// ============================================
// CITIES PROVIDER
// ============================================

final citiesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getCities();
});

// ============================================
// DISTRICTS PROVIDER
// ============================================

final districtsProvider = FutureProvider.family<List<String>, String>((ref, city) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getDistrictsByCity(city);
});

// ============================================
// PROPERTY TYPES PROVIDER
// ============================================

final propertyTypesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getPropertyTypes();
});

// ============================================
// AMENITIES PROVIDER
// ============================================

final amenitiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(propertyServiceProvider);
  return service.getAmenities();
});
