import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'product_favorite_provider.dart';
import 'store_favorite_provider.dart';
import '../services/favorites_service.dart';
import '../services/supabase_service.dart';

// ============================================
// YEMEK FAVORİLERİ
// ============================================

class FavoriteRestaurant {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final double rating;
  final String deliveryTime;
  final double minOrder;
  final DateTime addedAt;

  const FavoriteRestaurant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.rating,
    required this.deliveryTime,
    required this.minOrder,
    required this.addedAt,
  });

  factory FavoriteRestaurant.fromJson(Map<String, dynamic> json) {
    return FavoriteRestaurant(
      id: json['id'],
      name: json['name'],
      imageUrl: json['imageUrl'] ?? '',
      category: json['category'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      deliveryTime: json['deliveryTime'] ?? '',
      minOrder: (json['minOrder'] as num?)?.toDouble() ?? 0.0,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'category': category,
      'rating': rating,
      'deliveryTime': deliveryTime,
      'minOrder': minOrder,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

class FoodFavoriteState {
  final List<FavoriteRestaurant> restaurants;
  const FoodFavoriteState({this.restaurants = const []});

  bool isFavorite(String id) => restaurants.any((r) => r.id == id);

  FoodFavoriteState copyWith({List<FavoriteRestaurant>? restaurants}) {
    return FoodFavoriteState(restaurants: restaurants ?? this.restaurants);
  }
}

class FoodFavoriteNotifier extends StateNotifier<FoodFavoriteState> {
  FoodFavoriteNotifier() : super(const FoodFavoriteState()) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    // Load favorite merchant IDs from database
    final favoriteMerchantIds = await FavoritesService.getFavoriteMerchantIds();

    // Load restaurant details for each favorite
    final List<FavoriteRestaurant> foodFavorites = [];
    for (final merchantId in favoriteMerchantIds) {
      try {
        final data = await SupabaseService.client
            .from('merchants')
            .select('id, business_name, cover_url, rating, delivery_time, min_order_amount, type')
            .eq('id', merchantId)
            .eq('type', 'restaurant')
            .maybeSingle();

        if (data != null) {
          foodFavorites.add(FavoriteRestaurant(
            id: data['id'],
            name: data['business_name'] ?? '',
            imageUrl: data['cover_url'] ?? '',
            category: 'Restoran',
            rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
            deliveryTime: data['delivery_time'] ?? '',
            minOrder: (data['min_order_amount'] as num?)?.toDouble() ?? 0.0,
            addedAt: DateTime.now(),
          ));
        }
      } catch (e) {
        // Skip if error
      }
    }

    state = state.copyWith(restaurants: foodFavorites);
  }

  Future<void> addRestaurant(FavoriteRestaurant restaurant) async {
    if (state.isFavorite(restaurant.id)) return;

    // Optimistic Update
    state = state.copyWith(restaurants: [...state.restaurants, restaurant]);

    await FavoritesService.addFavorite(restaurant.id);
  }

  Future<void> removeRestaurant(String id) async {
    // Optimistic Update
    state = state.copyWith(
      restaurants: state.restaurants.where((r) => r.id != id).toList(),
    );

    await FavoritesService.removeFavorite(id);
  }

  void toggleRestaurant(FavoriteRestaurant restaurant) {
    if (state.isFavorite(restaurant.id)) {
      removeRestaurant(restaurant.id);
    } else {
      addRestaurant(restaurant);
    }
  }
}

final foodFavoriteProvider =
    StateNotifierProvider<FoodFavoriteNotifier, FoodFavoriteState>((ref) {
      return FoodFavoriteNotifier();
    });

final isFoodFavoriteProvider = Provider.family<bool, String>((ref, id) {
  return ref.watch(foodFavoriteProvider).isFavorite(id);
});

// ============================================
// EMLAK FAVORİLERİ
// ============================================

class FavoriteProperty {
  final String id;
  final String title;
  final String imageUrl;
  final String location;
  final double price;
  final String type;
  final String propertyType;
  final int rooms;
  final int area;
  final DateTime addedAt;

  const FavoriteProperty({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.location,
    required this.price,
    required this.type,
    required this.propertyType,
    required this.rooms,
    required this.area,
    required this.addedAt,
  });

  String get formattedPrice {
    if (price >= 1000000) {
      return '₺${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '₺${(price / 1000).toStringAsFixed(0)}K';
    }
    return '₺${price.toStringAsFixed(0)}';
  }

  factory FavoriteProperty.fromJson(Map<String, dynamic> json) {
    return FavoriteProperty(
      id: json['id'],
      title: json['title'],
      imageUrl: json['imageUrl'],
      location: json['location'],
      price: (json['price'] as num).toDouble(),
      type: json['type'],
      propertyType: json['propertyType'],
      rooms: json['rooms'],
      area: json['area'],
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'location': location,
      'price': price,
      'type': type,
      'propertyType': propertyType,
      'rooms': rooms,
      'area': area,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

class EmlakFavoriteState {
  final List<FavoriteProperty> properties;
  const EmlakFavoriteState({this.properties = const []});

  bool isFavorite(String id) => properties.any((p) => p.id == id);

  EmlakFavoriteState copyWith({List<FavoriteProperty>? properties}) {
    return EmlakFavoriteState(properties: properties ?? this.properties);
  }
}

class EmlakFavoriteNotifier extends StateNotifier<EmlakFavoriteState> {
  EmlakFavoriteNotifier() : super(const EmlakFavoriteState()) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    // Property favorites use local state only (no DB table)
  }

  Future<void> addProperty(FavoriteProperty property) async {
    if (state.isFavorite(property.id)) return;
    state = state.copyWith(properties: [...state.properties, property]);
  }

  Future<void> removeProperty(String id) async {
    state = state.copyWith(
      properties: state.properties.where((p) => p.id != id).toList(),
    );
  }

  void toggleProperty(FavoriteProperty property) {
    if (state.isFavorite(property.id)) {
      removeProperty(property.id);
    } else {
      addProperty(property);
    }
  }
}

final emlakFavoriteProvider =
    StateNotifierProvider<EmlakFavoriteNotifier, EmlakFavoriteState>((ref) {
      return EmlakFavoriteNotifier();
    });

final isEmlakFavoriteProvider = Provider.family<bool, String>((ref, id) {
  return ref.watch(emlakFavoriteProvider).isFavorite(id);
});

// ============================================
// ARAÇ FAVORİLERİ
// ============================================

class FavoriteCar {
  final String id;
  final String title;
  final String imageUrl;
  final String brand;
  final String model;
  final int year;
  final int km;
  final double price;
  final String fuelType;
  final String transmission;
  final String location;
  final DateTime addedAt;

  const FavoriteCar({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.brand,
    required this.model,
    required this.year,
    required this.km,
    required this.price,
    required this.fuelType,
    required this.transmission,
    required this.location,
    required this.addedAt,
  });

  String get formattedPrice {
    if (price >= 1000000) {
      return '₺${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '₺${(price / 1000).toStringAsFixed(0)}K';
    }
    return '₺${price.toStringAsFixed(0)}';
  }

  String get formattedKm {
    if (km >= 1000) {
      return '${(km / 1000).toStringAsFixed(0)}K km';
    }
    return '$km km';
  }

  factory FavoriteCar.fromJson(Map<String, dynamic> json) {
    return FavoriteCar(
      id: json['id'],
      title: json['title'],
      imageUrl: json['imageUrl'],
      brand: json['brand'],
      model: json['model'],
      year: json['year'],
      km: json['km'],
      price: (json['price'] as num).toDouble(),
      fuelType: json['fuelType'],
      transmission: json['transmission'],
      location: json['location'],
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'brand': brand,
      'model': model,
      'year': year,
      'km': km,
      'price': price,
      'fuelType': fuelType,
      'transmission': transmission,
      'location': location,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

class CarFavoriteState {
  final List<FavoriteCar> cars;
  const CarFavoriteState({this.cars = const []});

  bool isFavorite(String id) => cars.any((c) => c.id == id);

  CarFavoriteState copyWith({List<FavoriteCar>? cars}) {
    return CarFavoriteState(cars: cars ?? this.cars);
  }
}

class CarFavoriteNotifier extends StateNotifier<CarFavoriteState> {
  CarFavoriteNotifier() : super(const CarFavoriteState()) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    // Car favorites use local state only (no DB table for generic favorites)
  }

  Future<void> addCar(FavoriteCar car) async {
    if (state.isFavorite(car.id)) return;
    state = state.copyWith(cars: [...state.cars, car]);
  }

  Future<void> removeCar(String id) async {
    state = state.copyWith(cars: state.cars.where((c) => c.id != id).toList());
  }

  void toggleCar(FavoriteCar car) {
    if (state.isFavorite(car.id)) {
      removeCar(car.id);
    } else {
      addCar(car);
    }
  }
}

final carFavoriteProvider =
    StateNotifierProvider<CarFavoriteNotifier, CarFavoriteState>((ref) {
      return CarFavoriteNotifier();
    });

final isCarFavoriteProvider = Provider.family<bool, String>((ref, id) {
  return ref.watch(carFavoriteProvider).isFavorite(id);
});

// ============================================
// İŞ İLANI FAVORİLERİ
// ============================================

class FavoriteJob {
  final String id;
  final String title;
  final String companyName;
  final String companyLogo;
  final String location;
  final String salary;
  final String employmentType;
  final List<String> tags;
  final DateTime addedAt;

  const FavoriteJob({
    required this.id,
    required this.title,
    required this.companyName,
    required this.companyLogo,
    required this.location,
    required this.salary,
    required this.employmentType,
    required this.tags,
    required this.addedAt,
  });

  factory FavoriteJob.fromJson(Map<String, dynamic> json) {
    return FavoriteJob(
      id: json['id'],
      title: json['title'],
      companyName: json['companyName'],
      companyLogo: json['companyLogo'],
      location: json['location'],
      salary: json['salary'],
      employmentType: json['employmentType'],
      tags: List<String>.from(json['tags'] ?? []),
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'companyName': companyName,
      'companyLogo': companyLogo,
      'location': location,
      'salary': salary,
      'employmentType': employmentType,
      'tags': tags,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

class JobFavoriteState {
  final List<FavoriteJob> jobs;
  const JobFavoriteState({this.jobs = const []});

  bool isFavorite(String id) => jobs.any((j) => j.id == id);

  JobFavoriteState copyWith({List<FavoriteJob>? jobs}) {
    return JobFavoriteState(jobs: jobs ?? this.jobs);
  }
}

class JobFavoriteNotifier extends StateNotifier<JobFavoriteState> {
  JobFavoriteNotifier() : super(const JobFavoriteState()) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    // Job favorites use local state only (no DB table for generic favorites)
  }

  Future<void> addJob(FavoriteJob job) async {
    if (state.isFavorite(job.id)) return;
    state = state.copyWith(jobs: [...state.jobs, job]);
  }

  Future<void> removeJob(String id) async {
    state = state.copyWith(jobs: state.jobs.where((j) => j.id != id).toList());
  }

  void toggleJob(FavoriteJob job) {
    if (state.isFavorite(job.id)) {
      removeJob(job.id);
    } else {
      addJob(job);
    }
  }
}

final jobFavoriteProvider =
    StateNotifierProvider<JobFavoriteNotifier, JobFavoriteState>((ref) {
      return JobFavoriteNotifier();
    });

final isJobFavoriteProvider = Provider.family<bool, String>((ref, id) {
  return ref.watch(jobFavoriteProvider).isFavorite(id);
});

// ============================================
// TOPLAM FAVORİ SAYISI
// ============================================

final totalFavoriteCountProvider = Provider<int>((ref) {
  final food = ref.watch(foodFavoriteProvider).restaurants.length;
  final products = ref.watch(productFavoriteProvider).favorites.length;
  final stores = ref.watch(storeFavoriteProvider).favorites.length;
  final emlak = ref.watch(emlakFavoriteProvider).properties.length;
  final cars = ref.watch(carFavoriteProvider).cars.length;
  final jobs = ref.watch(jobFavoriteProvider).jobs.length;
  return food + products + stores + emlak + cars + jobs;
});

// Servis Renkleri
class FavoriteServiceColors {
  static const food = Color(0xFFEC6D13);
  static const market = Color(0xFF6366F1);
  static const emlak = Color(0xFF10B981);
  static const car = Color(0xFF3B82F6);
  static const jobs = Color(0xFF8B5CF6);
}
