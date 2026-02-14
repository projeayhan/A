import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

// Merkezi Adres Modeli
class UserAddress {
  final String id;
  final String title;
  final String shortAddress; // Kısa adres (dropdown'da gösterilecek)
  final String fullAddress; // Tam adres
  final String type; // 'home', 'work', 'other'
  final String? floor;
  final String? apartment;
  final String? directions;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const UserAddress({
    required this.id,
    required this.title,
    required this.shortAddress,
    required this.fullAddress,
    required this.type,
    this.floor,
    this.apartment,
    this.directions,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  IconData get icon {
    switch (type) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  // Supabase'den gelen veriyi parse et
  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'] as String,
      title: json['name'] as String? ?? json['title'] as String? ?? '',
      shortAddress: json['address'] as String? ?? '',
      fullAddress: json['address_details'] as String? ?? json['address'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      floor: json['floor'] as String?,
      apartment: json['apartment'] as String?,
      directions: json['directions'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  // Supabase'e kaydetmek için JSON'a çevir
  Map<String, dynamic> toJson(String userId) {
    return {
      'user_id': userId,
      'name': title,
      'type': type,
      'address': shortAddress.isNotEmpty ? shortAddress : fullAddress,
      'address_details': fullAddress,
      'floor': floor,
      'apartment': apartment,
      'directions': directions,
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'is_default': isDefault,
      'is_active': true,
      'sort_order': 0,
    };
  }

  UserAddress copyWith({
    String? id,
    String? title,
    String? shortAddress,
    String? fullAddress,
    String? type,
    String? floor,
    String? apartment,
    String? directions,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) {
    return UserAddress(
      id: id ?? this.id,
      title: title ?? this.title,
      shortAddress: shortAddress ?? this.shortAddress,
      fullAddress: fullAddress ?? this.fullAddress,
      type: type ?? this.type,
      floor: floor ?? this.floor,
      apartment: apartment ?? this.apartment,
      directions: directions ?? this.directions,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

// Adres State
class AddressState {
  final List<UserAddress> addresses;
  final String? selectedAddressId;
  final bool isLoading;

  const AddressState({
    this.addresses = const [],
    this.selectedAddressId,
    this.isLoading = false,
  });

  UserAddress? get selectedAddress {
    if (selectedAddressId == null) return addresses.isNotEmpty ? addresses.first : null;
    return addresses.firstWhere(
      (a) => a.id == selectedAddressId,
      orElse: () => addresses.isNotEmpty ? addresses.first : const UserAddress(
        id: '0',
        title: 'Adres Seç',
        shortAddress: 'Adres seçilmedi',
        fullAddress: '',
        type: 'other',
      ),
    );
  }

  AddressState copyWith({
    List<UserAddress>? addresses,
    String? selectedAddressId,
    bool? isLoading,
  }) {
    return AddressState(
      addresses: addresses ?? this.addresses,
      selectedAddressId: selectedAddressId ?? this.selectedAddressId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Adres Notifier
class AddressNotifier extends StateNotifier<AddressState> {
  AddressNotifier() : super(const AddressState(isLoading: true)) {
    _loadAddressesFromSupabase();
  }

  // Supabase'den adresleri yükle
  Future<void> _loadAddressesFromSupabase() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      state = const AddressState(isLoading: false);
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('saved_locations')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('sort_order');

      final addresses = (response as List)
          .map((json) => UserAddress.fromJson(json))
          .toList();

      // Varsayılan adresi bul
      String? defaultAddressId;
      for (final addr in addresses) {
        if (addr.isDefault) {
          defaultAddressId = addr.id;
          break;
        }
      }

      state = AddressState(
        addresses: addresses,
        selectedAddressId: defaultAddressId ?? (addresses.isNotEmpty ? addresses.first.id : null),
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) print('Error loading addresses: $e');
      state = const AddressState(isLoading: false);
    }
  }

  // Adresleri yeniden yükle
  Future<void> refreshAddresses() async {
    state = state.copyWith(isLoading: true);
    await _loadAddressesFromSupabase();
  }

  void selectAddress(String addressId) {
    state = state.copyWith(selectedAddressId: addressId);
  }

  // Yeni adres ekle - Supabase'e kaydet
  Future<bool> addAddress(UserAddress address) async {
    final userId = SupabaseService.currentUser?.id;
    if (kDebugMode) print('DEBUG addAddress: userId = $userId');
    if (userId == null) {
      if (kDebugMode) print('DEBUG addAddress: userId is null, returning false');
      return false;
    }

    try {
      final data = address.toJson(userId);
      if (kDebugMode) print('DEBUG addAddress: inserting data = $data');

      final response = await SupabaseService.client
          .from('saved_locations')
          .insert(data)
          .select()
          .single();

      if (kDebugMode) print('DEBUG addAddress: response = $response');
      final newAddress = UserAddress.fromJson(response);

      state = state.copyWith(
        addresses: [...state.addresses, newAddress],
      );

      // İlk adresse varsayılan olarak seç
      if (state.addresses.length == 1) {
        state = state.copyWith(selectedAddressId: newAddress.id);
      }

      if (kDebugMode) print('DEBUG addAddress: success!');
      return true;
    } catch (e) {
      if (kDebugMode) print('DEBUG addAddress: ERROR = $e');
      return false;
    }
  }

  // Adres güncelle - Supabase'de güncelle
  Future<bool> updateAddress(UserAddress updatedAddress) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .from('saved_locations')
          .update({
            'name': updatedAddress.title,
            'type': updatedAddress.type,
            'address': updatedAddress.shortAddress.isNotEmpty
                ? updatedAddress.shortAddress
                : updatedAddress.fullAddress,
            'address_details': updatedAddress.fullAddress,
            'floor': updatedAddress.floor,
            'apartment': updatedAddress.apartment,
            'directions': updatedAddress.directions,
            'latitude': updatedAddress.latitude ?? 0.0,
            'longitude': updatedAddress.longitude ?? 0.0,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', updatedAddress.id);

      final updatedList = state.addresses.map((a) {
        return a.id == updatedAddress.id ? updatedAddress : a;
      }).toList();

      state = state.copyWith(addresses: updatedList);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error updating address: $e');
      return false;
    }
  }

  // Adres sil - Supabase'den sil (soft delete)
  Future<bool> deleteAddress(String addressId) async {
    try {
      await SupabaseService.client
          .from('saved_locations')
          .update({'is_active': false})
          .eq('id', addressId);

      final updatedList = state.addresses.where((a) => a.id != addressId).toList();

      // Eğer silinen adres seçili ise, ilk adresi seç
      String? newSelectedId = state.selectedAddressId;
      if (state.selectedAddressId == addressId) {
        newSelectedId = updatedList.isNotEmpty ? updatedList.first.id : null;
      }

      state = state.copyWith(
        addresses: updatedList,
        selectedAddressId: newSelectedId,
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('Error deleting address: $e');
      return false;
    }
  }

  // Varsayılan adres ayarla
  Future<void> setDefaultAddress(String addressId) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      // Önce tüm adreslerin is_default'unu false yap
      await SupabaseService.client
          .from('saved_locations')
          .update({'is_default': false})
          .eq('user_id', userId);

      // Seçilen adresi varsayılan yap
      await SupabaseService.client
          .from('saved_locations')
          .update({'is_default': true})
          .eq('id', addressId);

      // Local state güncelle
      final updatedList = state.addresses.map((a) {
        return a.copyWith(isDefault: a.id == addressId);
      }).toList();

      state = state.copyWith(
        addresses: updatedList,
        selectedAddressId: addressId,
      );
    } catch (e) {
      if (kDebugMode) print('Error setting default address: $e');
    }
  }
}

// Provider - rebuilds when auth state changes (login/logout)
final addressProvider = StateNotifierProvider<AddressNotifier, AddressState>((ref) {
  ref.watch(authProvider);
  return AddressNotifier();
});

// Convenience providers
final selectedAddressProvider = Provider<UserAddress?>((ref) {
  return ref.watch(addressProvider).selectedAddress;
});

final allAddressesProvider = Provider<List<UserAddress>>((ref) {
  return ref.watch(addressProvider).addresses;
});
