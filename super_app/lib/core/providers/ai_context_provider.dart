import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AI asistanın bulunduğu ekranı ve bağlamı bilmesi için model
class AiScreenContext {
  final String screenType; // home, food_home, restaurant_detail, store_detail, market_detail, cart, grocery_home, etc.
  final String? entityId; // merchant_id (restaurant/store/market)
  final String? entityName; // merchant name
  final String? entityType; // restaurant, store, market
  final Map<String, dynamic> extra; // additional context data

  const AiScreenContext({
    required this.screenType,
    this.entityId,
    this.entityName,
    this.entityType,
    this.extra = const {},
  });

  const AiScreenContext.home()
      : screenType = 'home',
        entityId = null,
        entityName = null,
        entityType = null,
        extra = const {};

  Map<String, dynamic> toJson() {
    return {
      'screen_type': screenType,
      if (entityId != null) 'entity_id': entityId,
      if (entityName != null) 'entity_name': entityName,
      if (entityType != null) 'entity_type': entityType,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }

  @override
  String toString() =>
      'AiScreenContext(screen: $screenType, entity: $entityName [$entityType], id: $entityId)';
}

/// Global state provider for current screen context
final aiScreenContextProvider = StateProvider<AiScreenContext>((ref) {
  return const AiScreenContext.home();
});
