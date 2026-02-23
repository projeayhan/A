import 'package:flutter_riverpod/flutter_riverpod.dart';

// Selected business state
class SelectedBusiness {
  final String id;
  final String name;
  final String type; // merchant, rental, emlak, car_sales
  final String? subType; // restaurant, market, store
  final Map<String, dynamic>? data;

  SelectedBusiness({
    required this.id,
    required this.name,
    required this.type,
    this.subType,
    this.data,
  });
}

final selectedBusinessProvider = StateProvider<SelectedBusiness?>((ref) => null);
