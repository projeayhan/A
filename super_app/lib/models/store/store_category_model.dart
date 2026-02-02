import 'package:flutter/material.dart';

class StoreCategory {
  final String id;
  final String name;
  final String iconName;
  final Color color;
  final int storeCount;

  const StoreCategory({
    required this.id,
    required this.name,
    required this.iconName,
    required this.color,
    this.storeCount = 0,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    // Renk formatı: #RRGGBB -> 0xFFRRGGBB
    String colorStr = json['color'] as String? ?? '#2196F3';
    colorStr = colorStr.replaceFirst('#', '');
    // 6 karakter ise başına FF (alpha) ekle
    if (colorStr.length == 6) {
      colorStr = 'FF$colorStr';
    }

    return StoreCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['icon_name'] as String? ?? 'category',
      color: Color(int.parse(colorStr, radix: 16)),
      storeCount: json['store_count'] as int? ?? 0,
    );
  }

  IconData get icon {
    switch (iconName) {
      case 'electronics':
        return Icons.devices_rounded;
      case 'fashion':
        return Icons.checkroom_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'beauty':
        return Icons.spa_rounded;
      case 'sports':
        return Icons.sports_basketball_rounded;
      case 'books':
        return Icons.menu_book_rounded;
      case 'toys':
        return Icons.toys_rounded;
      case 'grocery':
        return Icons.local_grocery_store_rounded;
      case 'jewelry':
        return Icons.diamond_rounded;
      case 'pet':
        return Icons.pets_rounded;
      case 'automotive':
        return Icons.directions_car_rounded;
      case 'garden':
        return Icons.yard_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // Veriler Supabase'den yüklenir
  static List<StoreCategory> get mockCategories => [];
}
