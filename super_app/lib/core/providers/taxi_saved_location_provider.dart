import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Taksi için Kayıtlı Konum Modeli
class TaxiSavedLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String type; // 'home', 'work', 'favorite'
  final IconData icon;
  final Color color;
  final DateTime createdAt;

  const TaxiSavedLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.icon,
    required this.color,
    required this.createdAt,
  });

  TaxiSavedLocation copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? type,
    IconData? icon,
    Color? color,
    DateTime? createdAt,
  }) {
    return TaxiSavedLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Convert to TaxiLocation for destination screen
  Map<String, dynamic> toTaxiLocationMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
    };
  }
}

// Son Konumlar için Model
class RecentTaxiLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime visitedAt;

  const RecentTaxiLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.visitedAt,
  });
}

// Taksi Konumları State
class TaxiLocationState {
  final List<TaxiSavedLocation> savedLocations;
  final List<RecentTaxiLocation> recentLocations;
  final bool isLoading;

  const TaxiLocationState({
    this.savedLocations = const [],
    this.recentLocations = const [],
    this.isLoading = false,
  });

  TaxiSavedLocation? get homeLocation {
    try {
      return savedLocations.firstWhere((l) => l.type == 'home');
    } catch (_) {
      return null;
    }
  }

  TaxiSavedLocation? get workLocation {
    try {
      return savedLocations.firstWhere((l) => l.type == 'work');
    } catch (_) {
      return null;
    }
  }

  List<TaxiSavedLocation> get favoriteLocations {
    return savedLocations.where((l) => l.type == 'favorite').toList();
  }

  TaxiLocationState copyWith({
    List<TaxiSavedLocation>? savedLocations,
    List<RecentTaxiLocation>? recentLocations,
    bool? isLoading,
  }) {
    return TaxiLocationState(
      savedLocations: savedLocations ?? this.savedLocations,
      recentLocations: recentLocations ?? this.recentLocations,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Taksi Konumları Notifier
class TaxiLocationNotifier extends StateNotifier<TaxiLocationState> {
  TaxiLocationNotifier() : super(const TaxiLocationState()) {
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    // TODO: Supabase'den kayıtlı ve son konumları yükle
    // Şimdilik boş başlıyor
  }

  // Yeni kayıtlı konum ekle
  void addSavedLocation(TaxiSavedLocation location) {
    // Aynı tipte varsa güncelle
    if (location.type == 'home' || location.type == 'work') {
      final existingIndex = state.savedLocations.indexWhere((l) => l.type == location.type);
      if (existingIndex != -1) {
        updateSavedLocation(location.copyWith(id: state.savedLocations[existingIndex].id));
        return;
      }
    }

    state = state.copyWith(
      savedLocations: [...state.savedLocations, location],
    );
  }

  // Kayıtlı konumu güncelle
  void updateSavedLocation(TaxiSavedLocation location) {
    final updatedList = state.savedLocations.map((l) {
      return l.id == location.id ? location : l;
    }).toList();

    state = state.copyWith(savedLocations: updatedList);
  }

  // Kayıtlı konumu sil
  void deleteSavedLocation(String locationId) {
    final updatedList = state.savedLocations.where((l) => l.id != locationId).toList();
    state = state.copyWith(savedLocations: updatedList);
  }

  // Son konumlara ekle
  void addToRecentLocations(RecentTaxiLocation location) {
    // Zaten varsa öne taşı
    final existingIndex = state.recentLocations.indexWhere(
      (l) => l.latitude == location.latitude && l.longitude == location.longitude,
    );

    List<RecentTaxiLocation> updatedList;
    if (existingIndex != -1) {
      updatedList = [...state.recentLocations];
      updatedList.removeAt(existingIndex);
      updatedList.insert(0, location);
    } else {
      updatedList = [location, ...state.recentLocations];
      // Maksimum 10 son konum tut
      if (updatedList.length > 10) {
        updatedList = updatedList.sublist(0, 10);
      }
    }

    state = state.copyWith(recentLocations: updatedList);
  }

  // Son konumları temizle
  void clearRecentLocations() {
    state = state.copyWith(recentLocations: []);
  }

  // Son konumu sil
  void removeRecentLocation(String locationId) {
    final updatedList = state.recentLocations.where((l) => l.id != locationId).toList();
    state = state.copyWith(recentLocations: updatedList);
  }
}

// Provider tanımları
final taxiLocationProvider =
    StateNotifierProvider<TaxiLocationNotifier, TaxiLocationState>((ref) {
  return TaxiLocationNotifier();
});

// Convenience providers
final taxiSavedLocationsProvider = Provider<List<TaxiSavedLocation>>((ref) {
  return ref.watch(taxiLocationProvider).savedLocations;
});

final taxiRecentLocationsProvider = Provider<List<RecentTaxiLocation>>((ref) {
  return ref.watch(taxiLocationProvider).recentLocations;
});

final taxiHomeLocationProvider = Provider<TaxiSavedLocation?>((ref) {
  return ref.watch(taxiLocationProvider).homeLocation;
});

final taxiWorkLocationProvider = Provider<TaxiSavedLocation?>((ref) {
  return ref.watch(taxiLocationProvider).workLocation;
});
