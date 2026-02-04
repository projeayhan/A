import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;

// Restaurant Category Model
class RestaurantCategory {
  final String id;
  final String name;
  final String? imageUrl;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  RestaurantCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory RestaurantCategory.fromJson(Map<String, dynamic> json) {
    return RestaurantCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// Store Category Model
class StoreCategory {
  final String id;
  final String name;
  final String? imageUrl;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  StoreCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    return StoreCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// Food Admin Service
class FoodAdminService {
  final SupabaseClient _client = Supabase.instance.client;

  // Restaurant Categories
  Future<List<RestaurantCategory>> getRestaurantCategories() async {
    final response = await _client
        .from('restaurant_categories')
        .select()
        .order('sort_order');
    return (response as List).map((e) => RestaurantCategory.fromJson(e)).toList();
  }

  Future<void> createRestaurantCategory(Map<String, dynamic> data) async {
    await _client.from('restaurant_categories').insert(data);
  }

  Future<void> updateRestaurantCategory(String id, Map<String, dynamic> data) async {
    await _client.from('restaurant_categories').update(data).eq('id', id);
  }

  Future<void> deleteRestaurantCategory(String id) async {
    await _client.from('restaurant_categories').delete().eq('id', id);
  }

  // Image Upload with Auto-Resize
  Future<String> uploadCategoryImage(Uint8List imageBytes, String fileName) async {
    // Resize image to max 400x400 for category thumbnails
    final resizedBytes = _resizeImage(imageBytes, maxWidth: 400, maxHeight: 400);

    // Generate unique filename (remove special characters from filename)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName
        .replaceAll(RegExp(r'[^\w\.]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final uniqueFileName = 'restaurant_categories/${timestamp}_$safeName.jpg';

    // Upload to Supabase Storage - always JPEG after resize
    await _client.storage.from('images').uploadBinary(
      uniqueFileName,
      resizedBytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    // Get public URL
    final publicUrl = _client.storage.from('images').getPublicUrl(uniqueFileName);
    return publicUrl;
  }

  Uint8List _resizeImage(Uint8List imageBytes, {required int maxWidth, required int maxHeight}) {
    // Decode image
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // Check if resizing is needed
    if (image.width <= maxWidth && image.height <= maxHeight) {
      // Just optimize quality without resizing
      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    }

    // Calculate new dimensions maintaining aspect ratio
    double ratio = image.width / image.height;
    int newWidth, newHeight;

    if (image.width > image.height) {
      newWidth = maxWidth;
      newHeight = (maxWidth / ratio).round();
    } else {
      newHeight = maxHeight;
      newWidth = (maxHeight * ratio).round();
    }

    // Resize and encode as JPEG with good quality
    final resized = img.copyResize(image, width: newWidth, height: newHeight);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  // Store Categories
  Future<List<StoreCategory>> getStoreCategories() async {
    final response = await _client
        .from('store_categories')
        .select()
        .order('sort_order');
    return (response as List).map((e) => StoreCategory.fromJson(e)).toList();
  }

  Future<void> createStoreCategory(Map<String, dynamic> data) async {
    await _client.from('store_categories').insert(data);
  }

  Future<void> updateStoreCategory(String id, Map<String, dynamic> data) async {
    await _client.from('store_categories').update(data).eq('id', id);
  }

  Future<void> deleteStoreCategory(String id) async {
    await _client.from('store_categories').delete().eq('id', id);
  }
}

// Providers
final foodAdminServiceProvider = Provider((ref) => FoodAdminService());

final restaurantCategoriesProvider = FutureProvider<List<RestaurantCategory>>((ref) async {
  final service = ref.watch(foodAdminServiceProvider);
  return service.getRestaurantCategories();
});

final storeCategoriesProvider = FutureProvider<List<StoreCategory>>((ref) async {
  final service = ref.watch(foodAdminServiceProvider);
  return service.getStoreCategories();
});
