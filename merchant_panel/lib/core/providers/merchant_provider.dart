import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/merchant_models.dart';
import '../services/log_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_sound_service.dart';
import '../utils/name_masking.dart';

// Unread Messages Count Provider - lightweight count + realtime events
final unreadMessagesCountProvider = StreamProvider.family<int, String>((
  ref,
  merchantId,
) {
  final controller = StreamController<int>();

  Future<void> loadCount() async {
    try {
      final orderResult = await Supabase.instance.client
          .from('order_messages')
          .select('id')
          .eq('merchant_id', merchantId)
          .eq('sender_type', 'customer')
          .eq('is_read', false);
      final storeResult = await Supabase.instance.client
          .from('store_messages')
          .select('id')
          .eq('merchant_id', merchantId)
          .eq('sender_type', 'customer')
          .eq('is_read', false);
      if (!controller.isClosed) {
        controller.add(
          (orderResult as List).length + (storeResult as List).length,
        );
      }
    } catch (e) {
      if (!controller.isClosed) controller.add(0);
    }
  }

  // Initial count
  loadCount();

  // Listen for order_messages changes
  final orderChannel =
      Supabase.instance.client
          .channel('unread_order_msgs_$merchantId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'order_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'merchant_id',
              value: merchantId,
            ),
            callback: (_) => loadCount(),
          )
          .subscribe();

  // Listen for store_messages changes
  final storeChannel =
      Supabase.instance.client
          .channel('unread_store_msgs_$merchantId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'store_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'merchant_id',
              value: merchantId,
            ),
            callback: (_) => loadCount(),
          )
          .subscribe();

  ref.onDispose(() {
    controller.close();
    Supabase.instance.client.removeChannel(orderChannel);
    Supabase.instance.client.removeChannel(storeChannel);
  });

  return controller.stream;
});

// Current Merchant Provider
final currentMerchantProvider =
    StateNotifierProvider<CurrentMerchantNotifier, AsyncValue<Merchant?>>((
      ref,
    ) {
      return CurrentMerchantNotifier(ref);
    });

class CurrentMerchantNotifier extends StateNotifier<AsyncValue<Merchant?>> {
  final Ref ref;

  CurrentMerchantNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> loadMerchant(String merchantId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response =
          await supabase
              .from('merchants')
              .select()
              .eq('id', merchantId)
              .single();

      state = AsyncValue.data(Merchant.fromJson(response));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMerchantByUserId(String userId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response =
          await supabase
              .from('merchants')
              .select()
              .eq('user_id', userId)
              .maybeSingle();

      if (response != null) {
        final merchant = Merchant.fromJson(response);
        state = AsyncValue.data(merchant);

        // Load related data with delay to avoid widget tree issues
        Future.microtask(() {
          ref.read(ordersProvider.notifier).loadOrders(merchant.id);

          if (merchant.type == MerchantType.restaurant) {
            ref.read(menuItemsProvider.notifier).loadMenuItems(merchant.id);
          } else {
            ref.read(storeProductsProvider.notifier).loadProducts(merchant.id);
            ref
                .read(productCategoriesProvider.notifier)
                .loadCategories(merchant.id);
            ref
                .read(stockMovementsProvider.notifier)
                .loadMovements(merchant.id);
          }

          ref.read(reviewsProvider.notifier).loadReviews(merchant.id);
          ref
              .read(notificationsProvider.notifier)
              .loadNotifications(merchant.id);
        });
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      LogService.error('loadMerchantByUserId failed', error: e, stackTrace: st, source: 'MerchantProvider:loadMerchantByUserId');
      state = const AsyncValue.data(null);
    }
  }

  Future<void> updateMerchant(Merchant merchant) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('merchants')
          .update(merchant.toJson())
          .eq('id', merchant.id);

      state = AsyncValue.data(merchant);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleOnlineStatus() async {
    final merchant = state.valueOrNull;
    if (merchant != null) {
      try {
        final newStatus = !merchant.isOpen;
        final supabase = ref.read(supabaseClientProvider);

        // Sadece is_open alanını güncelle
        await supabase
            .from('merchants')
            .update({'is_open': newStatus})
            .eq('id', merchant.id);

        // Local state'i güncelle
        final updated = merchant.copyWith(isOpen: newStatus);
        state = AsyncValue.data(updated);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

// Orders Provider
final ordersProvider =
    StateNotifierProvider<OrdersNotifier, AsyncValue<List<Order>>>((ref) {
      return OrdersNotifier(ref);
    });

class OrdersNotifier extends StateNotifier<AsyncValue<List<Order>>> {
  final Ref ref;
  RealtimeChannel? _channel;

  OrdersNotifier(this.ref) : super(const AsyncValue.data([]));

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    if (_channel != null) {
      ref.read(supabaseClientProvider).removeChannel(_channel!);
      _channel = null;
    }
  }

  void subscribeToOrders(String merchantId) {
    _unsubscribe();

    final supabase = ref.read(supabaseClientProvider);
    _channel =
        supabase
            .channel('orders_$merchantId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'orders',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'merchant_id',
                value: merchantId,
              ),
              callback: (payload) {
                // New order received - play notification sound
                notificationSoundService.playNewOrderSound();

                final newOrder = Order.fromJson(payload.newRecord);
                state.whenData((orders) {
                  state = AsyncValue.data([newOrder, ...orders]);
                });
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'orders',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'merchant_id',
                value: merchantId,
              ),
              callback: (payload) {
                // Order updated
                if (kDebugMode) {
                  print(
                    'Realtime order update received: ${payload.newRecord['id']} - status: ${payload.newRecord['status']}',
                  );
                }
                final updatedOrder = Order.fromJson(payload.newRecord);
                final oldRecord = payload.oldRecord;

                // Check if order was cancelled by customer
                if (updatedOrder.status == OrderStatus.cancelled &&
                    oldRecord['status'] == 'pending') {
                  // Customer cancelled the order - play general notification sound
                  NotificationSoundService.playSound(
                    type: NotificationSoundType.general,
                  );

                  // Add notification
                  ref
                      .read(notificationsProvider.notifier)
                      .addNotification(
                        MerchantNotification(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          type: 'order_cancelled',
                          title: 'Sipariş İptal Edildi',
                          message:
                              'Sipariş #${updatedOrder.orderNumber} müşteri tarafından iptal edildi.',
                          data: {'order_id': updatedOrder.id},
                          createdAt: DateTime.now(),
                        ),
                      );
                }

                // Check if order was delivered by courier
                if (updatedOrder.status == OrderStatus.delivered &&
                    oldRecord['status'] != 'delivered') {
                  if (kDebugMode) {
                    print(
                      'Order ${updatedOrder.orderNumber} delivered by courier',
                    );
                  }
                }

                state.whenData((orders) {
                  final index = orders.indexWhere(
                    (o) => o.id == updatedOrder.id,
                  );
                  if (index != -1) {
                    final newList = [...orders];
                    newList[index] = updatedOrder;
                    state = AsyncValue.data(newList);
                    if (kDebugMode) {
                      print(
                        'Order list updated, order ${updatedOrder.id} now has status: ${updatedOrder.status}',
                      );
                    }
                  }
                });
              },
            )
            .subscribe();
  }

  Future<void> loadOrders(
    String merchantId, {
    OrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      var query = supabase
          .from('orders')
          .select()
          .eq('merchant_id', merchantId);

      if (status != null) {
        query = query.eq('status', status.name);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      final orders =
          (response as List).map((json) => Order.fromJson(json)).toList();

      state = AsyncValue.data(orders);

      // Subscribe to realtime updates for new orders
      subscribeToOrders(merchantId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    int? preparationTime,
  }) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final updateData = <String, dynamic>{
        'status': newStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newStatus == OrderStatus.confirmed && preparationTime != null) {
        updateData['estimated_delivery_time'] =
            DateTime.now()
                .add(Duration(minutes: preparationTime))
                .toIso8601String();
      }

      await supabase.from('orders').update(updateData).eq('id', orderId);

      // Update local state
      state.whenData((orders) {
        final index = orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          final updatedOrder = orders[index].copyWith(status: newStatus);
          final newList = [...orders];
          newList[index] = updatedOrder;
          state = AsyncValue.data(newList);
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rejectOrder(String orderId, String reason) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('orders')
          .update({
            'status': OrderStatus.cancelled.name,
            'cancellation_reason': reason,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      state.whenData((orders) {
        final index = orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          final updatedOrder = orders[index].copyWith(
            status: OrderStatus.cancelled,
          );
          final newList = [...orders];
          newList[index] = updatedOrder;
          state = AsyncValue.data(newList);
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Active Orders Count Provider
final activeOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.maybeWhen(
    data:
        (list) =>
            list
                .where(
                  (o) =>
                      o.status != OrderStatus.delivered &&
                      o.status != OrderStatus.cancelled,
                )
                .length,
    orElse: () => 0,
  );
});

// Pending Orders Provider
final pendingOrdersProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.maybeWhen(
    data: (list) => list.where((o) => o.status == OrderStatus.pending).toList(),
    orElse: () => [],
  );
});

// Menu Items Provider (Restaurant)
final menuItemsProvider =
    StateNotifierProvider<MenuItemsNotifier, AsyncValue<List<MenuItem>>>((ref) {
      return MenuItemsNotifier(ref);
    });

class MenuItemsNotifier extends StateNotifier<AsyncValue<List<MenuItem>>> {
  final Ref ref;

  MenuItemsNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> loadMenuItems(String merchantId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('menu_items')
          .select()
          .eq('merchant_id', merchantId)
          .order('category')
          .order('sort_order');

      final items =
          (response as List).map((json) => MenuItem.fromJson(json)).toList();

      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMenuItem(MenuItem item) async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Resmi yoksa havuzdan otomatik bul
      var itemData = item.toJson();
      if ((item.imageUrl == null || item.imageUrl!.isEmpty) &&
          item.name.isNotEmpty) {
        final poolImage = await _checkMenuItemPool(item.name);
        if (poolImage != null) {
          itemData['image_url'] = poolImage;
        }
      }

      final response =
          await supabase.from('menu_items').insert(itemData).select().single();

      final newItem = MenuItem.fromJson(response);
      state.whenData((items) {
        state = AsyncValue.data([...items, newItem]);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateMenuItem(MenuItem item) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('menu_items').update(item.toJson()).eq('id', item.id);

      state.whenData((items) {
        final index = items.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          final newList = [...items];
          newList[index] = item;
          state = AsyncValue.data(newList);
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Toplu menü öğesi ekleme (Excel/CSV import)
  Future<int> bulkAddMenuItems(
    List<Map<String, dynamic>> items,
    String merchantId,
  ) async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Havuzdan resim bul (resimsizler için)
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if ((item['image_url'] == null ||
                (item['image_url'] as String? ?? '').isEmpty) &&
            item['name'] != null &&
            (item['name'] as String).isNotEmpty) {
          final poolImage = await _checkMenuItemPool(item['name'] as String);
          if (poolImage != null) {
            items[i] = {...item, 'image_url': poolImage};
          }
        }
      }

      // Toplu insert
      await supabase.from('menu_items').insert(items);

      // Listeyi yeniden yükle
      await loadMenuItems(merchantId);

      return items.length;
    } catch (e, st) {
      LogService.error('Bulk add menu items failed', error: e, stackTrace: st, source: 'MenuItemsNotifier:bulkAddMenuItems');
      state = AsyncValue.error(e, st);
      return 0;
    }
  }

  /// Paylaşılan havuzdan yemek resmi bul (isim fuzzy eşleşme, barkod yok)
  Future<String?> _checkMenuItemPool(String name) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final result = await supabase.rpc(
        'match_product_image',
        params: {'p_barcode': null, 'p_name': name, 'p_brand': null},
      );
      if (result != null && result is List && result.isNotEmpty) {
        final imageUrl = result[0]['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
      }
    } catch (e, st) {
      LogService.error('Menu item pool check failed', error: e, stackTrace: st, source: 'MenuItemsNotifier:_checkMenuItemPool');
    }
    return null;
  }

  Future<void> deleteMenuItem(String itemId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('menu_items').delete().eq('id', itemId);

      state.whenData((items) {
        state = AsyncValue.data(items.where((i) => i.id != itemId).toList());
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleAvailability(String itemId) async {
    state.whenData((items) async {
      final item = items.firstWhere((i) => i.id == itemId);
      final updated = item.copyWith(isAvailable: !item.isAvailable);
      await updateMenuItem(updated);
    });
  }
}

// Store Products Provider
final storeProductsProvider = StateNotifierProvider<
  StoreProductsNotifier,
  AsyncValue<List<StoreProduct>>
>((ref) {
  return StoreProductsNotifier(ref);
});

class StoreProductsNotifier
    extends StateNotifier<AsyncValue<List<StoreProduct>>> {
  final Ref ref;

  StoreProductsNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> loadProducts(String merchantId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('products')
          .select()
          .eq('merchant_id', merchantId)
          .order('name');

      final products =
          (response as List)
              .map((json) => StoreProduct.fromJson(json))
              .toList();

      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addProduct(StoreProduct product) async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Resmi yoksa havuzdan otomatik bul
      var productData = product.toJson();
      if ((product.imageUrl == null || product.imageUrl!.isEmpty) &&
          product.name.isNotEmpty) {
        final poolImage = await _checkSharedPool(
          product.barcode,
          product.name,
          product.brand,
        );
        if (poolImage != null) {
          productData['image_url'] = poolImage;
        }
      }

      final response =
          await supabase.from('products').insert(productData).select().single();

      final newProduct = StoreProduct.fromJson(response);
      state.whenData((products) {
        state = AsyncValue.data([...products, newProduct]);
      });
      _upsertToSharedPool(newProduct);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProduct(StoreProduct product) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id);

      state.whenData((products) {
        final index = products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          final newList = [...products];
          newList[index] = product;
          state = AsyncValue.data(newList);
        }
      });
      _upsertToSharedPool(product);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStock(
    String productId,
    int newStock, {
    String? note,
  }) async {
    state.whenData((products) async {
      final product = products.firstWhere((p) => p.id == productId);
      final previousStock = product.stock;
      final updated = product.copyWith(stockQuantity: newStock);
      await updateProduct(updated);

      // Record stock movement
      final diff = newStock - previousStock;
      final movementType =
          diff > 0
              ? 'in'
              : diff < 0
              ? 'out'
              : 'adjustment';
      ref
          .read(stockMovementsProvider.notifier)
          .addMovement(
            merchantId: product.storeId,
            productId: productId,
            movementType: movementType,
            quantity: diff,
            previousStock: previousStock,
            newStock: newStock,
            referenceType: 'manual',
            note:
                note ?? (diff > 0 ? 'Manuel stok ekleme' : 'Manuel stok dusme'),
          );
    });
  }

  /// Toplu stok güncelleme - Map<productId, newStock>
  Future<int> bulkUpdateStock(Map<String, int> stockUpdates) async {
    int updatedCount = 0;
    try {
      final supabase = ref.read(supabaseClientProvider);
      final currentProducts = state.valueOrNull ?? [];

      for (final entry in stockUpdates.entries) {
        await supabase
            .from('products')
            .update({'stock': entry.value})
            .eq('id', entry.key);
        updatedCount++;

        // Record stock movement
        final product =
            currentProducts.where((p) => p.id == entry.key).firstOrNull;
        if (product != null) {
          final diff = entry.value - product.stock;
          final movementType =
              diff > 0
                  ? 'in'
                  : diff < 0
                  ? 'out'
                  : 'adjustment';
          await supabase.from('stock_movements').insert({
            'merchant_id': product.storeId,
            'product_id': entry.key,
            'movement_type': movementType,
            'quantity': diff,
            'previous_stock': product.stock,
            'new_stock': entry.value,
            'reference_type': 'bulk_update',
            'note': 'Toplu stok guncelleme',
          });
        }
      }
      // Reload products
      state.whenData((products) {
        final newList =
            products.map((p) {
              if (stockUpdates.containsKey(p.id)) {
                return p.copyWith(stockQuantity: stockUpdates[p.id]!);
              }
              return p;
            }).toList();
        state = AsyncValue.data(newList);
      });

      // Reload movements
      final merchant = ref.read(currentMerchantProvider).valueOrNull;
      if (merchant != null) {
        ref.read(stockMovementsProvider.notifier).loadMovements(merchant.id);
      }
    } catch (e, st) {
      LogService.error('Bulk update failed', error: e, stackTrace: st, source: 'StoreProductsNotifier:bulkUpdateStock');
    }
    return updatedCount;
  }

  /// Toplu urun ekleme/guncelleme (upsert)
  /// Mevcut urunleri barkod/SKU/isim ile eslestirir:
  /// - Eslesen → fiyat, stok, aciklama vb. guncellenir
  /// - Eslesmeyen → yeni urun olarak eklenir
  Future<int> bulkAddProducts(List<StoreProduct> products) async {
    int processedCount = 0;
    try {
      final supabase = ref.read(supabaseClientProvider);
      final existing = state.valueOrNull ?? [];

      final toInsert = <Map<String, dynamic>>[];
      final toUpdate = <Map<String, dynamic>>[]; // [{id, updates}]

      for (final product in products) {
        // Eslestirme: barkod > SKU > isim (case-insensitive)
        StoreProduct? match;
        if (product.barcode != null && product.barcode!.isNotEmpty) {
          match =
              existing.where((e) => e.barcode == product.barcode).firstOrNull;
        }
        if (match == null && product.sku != null && product.sku!.isNotEmpty) {
          match = existing.where((e) => e.sku == product.sku).firstOrNull;
        }
        match ??=
            existing
                .where(
                  (e) =>
                      e.name.trim().toLowerCase() ==
                      product.name.trim().toLowerCase(),
                )
                .firstOrNull;

        if (match != null) {
          // Mevcut urun → guncelle (sadece degisen alanlari)
          final updates = <String, dynamic>{};
          if (product.price != match.price) updates['price'] = product.price;
          if (product.stock != match.stock) updates['stock'] = product.stock;
          if (product.description != null &&
              product.description != match.description) {
            updates['description'] = product.description;
          }
          if (product.barcode != null && product.barcode != match.barcode) {
            updates['barcode'] = product.barcode;
          }
          if (product.sku != null && product.sku != match.sku) {
            updates['sku'] = product.sku;
          }
          if (product.brand != null && product.brand != match.brand) {
            updates['brand'] = product.brand;
          }
          if (product.categoryId != null &&
              product.categoryId != match.categoryId) {
            updates['category_id'] = product.categoryId;
          }

          if (updates.isNotEmpty) {
            toUpdate.add({'id': match.id, ...updates});
          }
          processedCount++;
        } else {
          // Yeni urun → ekle
          toInsert.add(product.toJson());
        }
      }

      // Yeni ürünlerin resimsizleri için havuzdan otomatik resim bul
      for (int i = 0; i < toInsert.length; i++) {
        final item = toInsert[i];
        if ((item['image_url'] == null ||
                (item['image_url'] as String).isEmpty) &&
            item['name'] != null &&
            (item['name'] as String).isNotEmpty) {
          final poolImage = await _checkSharedPool(
            item['barcode'] as String?,
            item['name'] as String,
            item['brand'] as String?,
          );
          if (poolImage != null) {
            toInsert[i] = {...item, 'image_url': poolImage};
          }
        }
      }

      // Batch insert - yeni urunler
      if (toInsert.isNotEmpty) {
        await supabase.from('products').insert(toInsert).select();
        processedCount += toInsert.length;
      }

      // Tek tek update - mevcut urunler
      for (final update in toUpdate) {
        final id = update.remove('id');
        if (update.isNotEmpty) {
          await supabase.from('products').update(update).eq('id', id);
        }
      }

      // State'i yenile
      final merchant = ref.read(currentMerchantProvider).valueOrNull;
      if (merchant != null) await loadProducts(merchant.id);

      // Resimli ürünleri paylaşılan havuza kaydet
      for (final p in products) {
        if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
          _upsertToSharedPool(p);
        }
      }
    } catch (e, st) {
      LogService.error('Bulk add products failed', error: e, stackTrace: st, source: 'StoreProductsNotifier:bulkAddProducts');
    }
    return processedCount;
  }

  /// Otomatik resim bulma - Open Food Facts API
  /// Resimsiz urunler icin barkod/isim ile arama yapar
  /// [onProgress] her urun icin (bulunan, toplam) cagrilir
  Future<int> autoFetchProductImages({
    List<String>? productIds,
    void Function(int found, int total)? onProgress,
  }) async {
    int foundCount = 0;
    try {
      final supabase = ref.read(supabaseClientProvider);
      final products = state.valueOrNull ?? [];

      // Resimsiz urunleri filtrele
      final targets =
          products.where((p) {
            if (p.imageUrl != null && p.imageUrl!.isNotEmpty) return false;
            if (productIds != null && !productIds.contains(p.id)) return false;
            return true;
          }).toList();

      if (targets.isEmpty) return 0;

      // 5'erli batch'ler halinde edge function'a gonder
      const batchSize = 5;
      for (int i = 0; i < targets.length; i += batchSize) {
        final batch = targets.skip(i).take(batchSize).toList();
        final payload =
            batch
                .map(
                  (p) => {
                    'id': p.id,
                    'name': p.name,
                    'barcode': p.barcode,
                    'brand': p.brand,
                  },
                )
                .toList();

        try {
          final response = await supabase.functions.invoke(
            'auto-product-images',
            body: {'products': payload},
          );

          if (response.status == 200 && response.data != null) {
            final results =
                (response.data['results'] as Map?)?.cast<String, dynamic>() ??
                {};
            for (final entry in results.entries) {
              final productId = entry.key;
              final imageUrl = entry.value as String;

              // DB guncelle
              await supabase
                  .from('products')
                  .update({'image_url': imageUrl})
                  .eq('id', productId);

              foundCount++;
            }
          }
        } catch (e, st) {
          LogService.error('Auto image batch error', error: e, stackTrace: st, source: 'StoreProductsNotifier:autoFetchImages');
        }

        onProgress?.call(foundCount, targets.length);
      }

      // State'i yenile
      final merchant = ref.read(currentMerchantProvider).valueOrNull;
      if (merchant != null) await loadProducts(merchant.id);
    } catch (e, st) {
      LogService.error('Auto fetch images failed', error: e, stackTrace: st, source: 'StoreProductsNotifier:autoFetchImages');
    }
    return foundCount;
  }

  /// Paylaşılan havuzdan resim bul (barcode exact + name fuzzy)
  Future<String?> _checkSharedPool(
    String? barcode,
    String name,
    String? brand,
  ) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final result = await supabase.rpc(
        'match_product_image',
        params: {'p_barcode': barcode, 'p_name': name, 'p_brand': brand},
      );
      if (result != null && result is List && result.isNotEmpty) {
        final imageUrl = result[0]['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
      }
    } catch (e, st) {
      LogService.error('Shared pool check failed', error: e, stackTrace: st, source: 'StoreProductsNotifier:_checkSharedPool');
    }
    return null;
  }

  /// Ürün resmini paylaşılan havuza kaydet (cross-merchant reuse)
  Future<void> _upsertToSharedPool(StoreProduct product) async {
    if (product.imageUrl == null || product.imageUrl!.isEmpty) return;
    if (product.name.isEmpty) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc(
        'upsert_shared_product_image',
        params: {
          'p_barcode': product.barcode,
          'p_name': product.name,
          'p_brand': product.brand,
          'p_image_url': product.imageUrl,
          'p_source': 'merchant',
        },
      );
    } catch (e, st) {
      LogService.error('Shared pool upsert failed', error: e, stackTrace: st, source: 'StoreProductsNotifier:_upsertToSharedPool');
    }
  }

  Future<void> deleteProduct(String productId) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('products').delete().eq('id', productId);

    state.whenData((products) {
      state = AsyncValue.data(
        products.where((p) => p.id != productId).toList(),
      );
    });
  }
}

// Stock Movement model
class StockMovement {
  final String id;
  final String merchantId;
  final String productId;
  final String movementType; // in, out, adjustment
  final int quantity;
  final int previousStock;
  final int newStock;
  final String? referenceType;
  final String? referenceId;
  final String? note;
  final DateTime createdAt;
  // Joined field
  final String? productName;

  StockMovement({
    required this.id,
    required this.merchantId,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.referenceType,
    this.referenceId,
    this.note,
    required this.createdAt,
    this.productName,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final product = json['products'];
    return StockMovement(
      id: json['id'],
      merchantId: json['merchant_id'],
      productId: json['product_id'],
      movementType: json['movement_type'] ?? 'adjustment',
      quantity: json['quantity'] ?? 0,
      previousStock: json['previous_stock'] ?? 0,
      newStock: json['new_stock'] ?? 0,
      referenceType: json['reference_type'],
      referenceId: json['reference_id'],
      note: json['note'],
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      productName: product is Map ? product['name'] : null,
    );
  }
}

// Stock Movements Provider
final stockMovementsProvider = StateNotifierProvider<
  StockMovementsNotifier,
  AsyncValue<List<StockMovement>>
>((ref) {
  return StockMovementsNotifier(ref);
});

class StockMovementsNotifier
    extends StateNotifier<AsyncValue<List<StockMovement>>> {
  final Ref ref;

  StockMovementsNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> loadMovements(String merchantId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('stock_movements')
          .select('*, products(name)')
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .limit(50);

      final movements =
          (response as List)
              .map((json) => StockMovement.fromJson(json))
              .toList();

      state = AsyncValue.data(movements);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMovement({
    required String merchantId,
    required String productId,
    required String movementType,
    required int quantity,
    required int previousStock,
    required int newStock,
    String? referenceType,
    String? referenceId,
    String? note,
  }) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('stock_movements').insert({
        'merchant_id': merchantId,
        'product_id': productId,
        'movement_type': movementType,
        'quantity': quantity,
        'previous_stock': previousStock,
        'new_stock': newStock,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'note': note,
      });
      // Reload
      await loadMovements(merchantId);
    } catch (e, st) {
      LogService.error('Stock movement failed', error: e, stackTrace: st, source: 'StockMovementsNotifier:addMovement');
    }
  }
}

// Low Stock Products Provider
final lowStockProductsProvider = Provider<List<StoreProduct>>((ref) {
  final products = ref.watch(storeProductsProvider);
  return products.maybeWhen(
    data:
        (list) =>
            list.where((p) => p.stockQuantity <= p.lowStockThreshold).toList(),
    orElse: () => [],
  );
});

// Product Categories Provider
final productCategoriesProvider = StateNotifierProvider<
  ProductCategoriesNotifier,
  AsyncValue<List<ProductCategory>>
>((ref) {
  return ProductCategoriesNotifier(ref);
});

class ProductCategory {
  final String id;
  final String name;
  final String? merchantId;
  final int sortOrder;

  ProductCategory({
    required this.id,
    required this.name,
    this.merchantId,
    this.sortOrder = 0,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'],
      name: json['name'],
      merchantId: json['merchant_id'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

class ProductCategoriesNotifier
    extends StateNotifier<AsyncValue<List<ProductCategory>>> {
  final Ref ref;

  ProductCategoriesNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> loadCategories(String merchantId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('product_categories')
          .select()
          .or('merchant_id.eq.$merchantId,merchant_id.is.null')
          .order('sort_order');

      final categories =
          (response as List)
              .map((json) => ProductCategory.fromJson(json))
              .toList();

      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ProductCategory?> addCategory(String name, String merchantId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response =
          await supabase
              .from('product_categories')
              .insert({'name': name, 'merchant_id': merchantId})
              .select()
              .single();

      final newCategory = ProductCategory.fromJson(response);
      state.whenData((categories) {
        state = AsyncValue.data([...categories, newCategory]);
      });
      return newCategory;
    } catch (e, st) {
      LogService.error('Add category failed', error: e, stackTrace: st, source: 'StoreCategoriesNotifier:addCategory');
      return null;
    }
  }

  Future<bool> updateCategory(String id, String name) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('product_categories')
          .update({'name': name})
          .eq('id', id);

      state.whenData((categories) {
        final updated =
            categories.map((c) {
              if (c.id == id) {
                return ProductCategory(
                  id: c.id,
                  name: name,
                  merchantId: c.merchantId,
                );
              }
              return c;
            }).toList();
        state = AsyncValue.data(updated);
      });
      return true;
    } catch (e, st) {
      LogService.error('Update category failed', error: e, stackTrace: st, source: 'StoreCategoriesNotifier:updateCategory');
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('product_categories').delete().eq('id', id);

      state.whenData((categories) {
        state = AsyncValue.data(categories.where((c) => c.id != id).toList());
      });
      return true;
    } catch (e, st) {
      LogService.error('Delete category failed', error: e, stackTrace: st, source: 'StoreCategoriesNotifier:deleteCategory');
      return false;
    }
  }

  Future<bool> updateCategoryOrder(List<ProductCategory> categories) async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Update each category's sort_order
      for (int i = 0; i < categories.length; i++) {
        await supabase
            .from('product_categories')
            .update({'sort_order': i})
            .eq('id', categories[i].id);
      }

      // Update local state
      state = AsyncValue.data(categories);
      return true;
    } catch (e, st) {
      LogService.error('Update category order failed', error: e, stackTrace: st, source: 'StoreCategoriesNotifier:updateCategoryOrder');
      return false;
    }
  }
}

// Reviews Provider
final reviewsProvider =
    StateNotifierProvider<ReviewsNotifier, AsyncValue<List<Review>>>((ref) {
      return ReviewsNotifier(ref);
    });

class ReviewsNotifier extends StateNotifier<AsyncValue<List<Review>>> {
  final Ref ref;

  ReviewsNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> loadReviews(String merchantId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('reviews')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      final reviews =
          (response as List).map((json) => Review.fromJson(json)).toList();

      state = AsyncValue.data(reviews);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> replyToReview(String reviewId, String reply) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('reviews')
          .update({
            'merchant_reply': reply,
            'replied_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId);

      state.whenData((reviews) {
        final index = reviews.indexWhere((r) => r.id == reviewId);
        if (index != -1) {
          final updatedReview = reviews[index].copyWith(
            merchantReply: reply,
            repliedAt: DateTime.now(),
          );
          final newList = [...reviews];
          newList[index] = updatedReview;
          state = AsyncValue.data(newList);
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Dashboard Stats Provider
final dashboardStatsProvider = FutureProvider.family<DashboardStats, String>((
  ref,
  merchantId,
) async {
  final supabase = ref.read(supabaseClientProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
  final startOfMonth = DateTime(now.year, now.month, 1);

  // Today's orders
  final todayOrders = await supabase
      .from('orders')
      .select('id, total_amount, status')
      .eq('merchant_id', merchantId)
      .gte('created_at', startOfDay.toIso8601String());

  // This week's orders
  final weekOrders = await supabase
      .from('orders')
      .select('id, total_amount, status, created_at')
      .eq('merchant_id', merchantId)
      .gte('created_at', startOfWeek.toIso8601String());

  // This month's orders
  final monthOrders = await supabase
      .from('orders')
      .select('id, total_amount, status')
      .eq('merchant_id', merchantId)
      .gte('created_at', startOfMonth.toIso8601String());

  // Pending orders
  final pendingOrders = await supabase
      .from('orders')
      .select('id')
      .eq('merchant_id', merchantId)
      .eq('status', 'pending');

  // Reviews for rating - use courier_rating, service_rating, taste_rating
  final reviews = await supabase
      .from('reviews')
      .select('courier_rating, service_rating, taste_rating')
      .eq('merchant_id', merchantId);

  // Recent activities (orders + reviews)
  final recentOrders = await supabase
      .from('orders')
      .select('id, order_number, status, total_amount, created_at')
      .eq('merchant_id', merchantId)
      .order('created_at', ascending: false)
      .limit(5);

  final recentReviews = await supabase
      .from('reviews')
      .select(
        'id, customer_name, courier_rating, service_rating, taste_rating, created_at',
      )
      .eq('merchant_id', merchantId)
      .order('created_at', ascending: false)
      .limit(3);

  // Calculate stats
  double calculateRevenue(List<dynamic> orders) {
    return orders
        .where((o) => o['status'] != 'cancelled')
        .fold(
          0.0,
          (sum, o) =>
              sum + ((o['total_amount'] ?? o['total'] ?? 0) as num).toDouble(),
        );
  }

  int countCompleted(List<dynamic> orders) {
    return orders.where((o) => o['status'] == 'delivered').length;
  }

  // Calculate average rating from courier, service, taste ratings
  double avgRating = 0;
  if (reviews.isNotEmpty) {
    double totalRating = 0;
    for (var review in reviews) {
      final courier = (review['courier_rating'] as num?)?.toDouble() ?? 0;
      final service = (review['service_rating'] as num?)?.toDouble() ?? 0;
      final taste = (review['taste_rating'] as num?)?.toDouble() ?? 0;
      totalRating += (courier + service + taste) / 3;
    }
    avgRating = totalRating / reviews.length;
  }

  // Calculate weekly revenue (last 7 days)
  List<double> weeklyRevenue = List.filled(7, 0.0);
  for (int i = 0; i < 7; i++) {
    final dayStart = startOfWeek.add(Duration(days: i));
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (var order in weekOrders) {
      final orderDate = DateTime.parse(order['created_at']);
      if (orderDate.isAfter(dayStart) &&
          orderDate.isBefore(dayEnd) &&
          order['status'] != 'cancelled') {
        weeklyRevenue[i] +=
            ((order['total_amount'] ?? order['total'] ?? 0) as num).toDouble();
      }
    }
  }

  // Order status distribution
  Map<String, int> statusDistribution = {};
  for (var order in monthOrders) {
    final status = order['status'] as String? ?? 'unknown';
    statusDistribution[status] = (statusDistribution[status] ?? 0) + 1;
  }

  // Combine activities
  List<Map<String, dynamic>> activities = [];
  for (var order in recentOrders) {
    activities.add({
      'type': 'order',
      'data': order,
      'created_at': order['created_at'],
    });
  }
  for (var review in recentReviews) {
    activities.add({
      'type': 'review',
      'data': review,
      'created_at': review['created_at'],
    });
  }
  activities.sort(
    (a, b) => DateTime.parse(
      b['created_at'],
    ).compareTo(DateTime.parse(a['created_at'])),
  );

  return DashboardStats(
    todayOrders: todayOrders.length,
    todayRevenue: calculateRevenue(todayOrders),
    weekOrders: weekOrders.length,
    weekRevenue: calculateRevenue(weekOrders),
    monthOrders: monthOrders.length,
    monthRevenue: calculateRevenue(monthOrders),
    completedOrders: countCompleted(monthOrders),
    cancelledOrders:
        monthOrders.where((o) => o['status'] == 'cancelled').length,
    pendingOrders: pendingOrders.length,
    averageRating: avgRating,
    totalReviews: reviews.length,
    weeklyRevenue: weeklyRevenue,
    orderStatusDistribution: statusDistribution,
    recentActivities: activities.take(10).toList(),
  );
});

class DashboardStats {
  final int todayOrders;
  final double todayRevenue;
  final int weekOrders;
  final double weekRevenue;
  final int monthOrders;
  final double monthRevenue;
  final int completedOrders;
  final int cancelledOrders;
  final int pendingOrders;
  final double averageRating;
  final int totalReviews;
  final List<double> weeklyRevenue;
  final Map<String, int> orderStatusDistribution;
  final List<Map<String, dynamic>> recentActivities;

  DashboardStats({
    required this.todayOrders,
    required this.todayRevenue,
    required this.weekOrders,
    required this.weekRevenue,
    required this.monthOrders,
    required this.monthRevenue,
    required this.completedOrders,
    required this.cancelledOrders,
    this.pendingOrders = 0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.weeklyRevenue = const [],
    this.orderStatusDistribution = const {},
    this.recentActivities = const [],
  });

  double get completionRate =>
      monthOrders > 0 ? (completedOrders / monthOrders * 100) : 0;

  double get cancellationRate =>
      monthOrders > 0 ? (cancelledOrders / monthOrders * 100) : 0;

  double get revenueChangePercent {
    if (weekRevenue == 0) return todayRevenue > 0 ? 100 : 0;
    final avgDailyWeek = weekRevenue / 7;
    if (avgDailyWeek == 0) return 0;
    return ((todayRevenue - avgDailyWeek) / avgDailyWeek) * 100;
  }
}

// Notifications Provider
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<MerchantNotification>>((
      ref,
    ) {
      return NotificationsNotifier(ref);
    });

class NotificationsNotifier extends StateNotifier<List<MerchantNotification>> {
  final Ref ref;
  RealtimeChannel? _channel;
  String? _merchantId;

  NotificationsNotifier(this.ref) : super([]);

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    if (_channel != null) {
      ref.read(supabaseClientProvider).removeChannel(_channel!);
      _channel = null;
    }
  }

  Set<String> _readNotificationIds = {};

  Future<void> _loadReadIds(String merchantId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final result =
          await supabase
              .from('merchants')
              .select('notification_read_ids')
              .eq('id', merchantId)
              .single();
      final ids = result['notification_read_ids'] as List<dynamic>?;
      if (ids != null) {
        _readNotificationIds = ids.map((e) => e.toString()).toSet();
      }
    } catch (e, st) {
      LogService.error('Load read IDs failed', error: e, stackTrace: st, source: 'NotificationsNotifier:_loadReadIds');
    }
  }

  Future<void> _saveReadIds() async {
    if (_merchantId == null) return;
    try {
      final supabase = ref.read(supabaseClientProvider);
      // Keep only last 200 read IDs to prevent unbounded growth
      final ids = _readNotificationIds.toList();
      final trimmed = ids.length > 200 ? ids.sublist(ids.length - 200) : ids;
      await supabase
          .from('merchants')
          .update({'notification_read_ids': trimmed})
          .eq('id', _merchantId!);
    } catch (e, st) {
      LogService.error('Save read IDs failed', error: e, stackTrace: st, source: 'NotificationsNotifier:_saveReadIds');
    }
  }

  // Supabase'den bildirimleri yukle
  Future<void> loadNotifications(String merchantId) async {
    try {
      _merchantId = merchantId;
      await _loadReadIds(merchantId);
      final supabase = ref.read(supabaseClientProvider);

      final recentOrders = await supabase
          .from('orders')
          .select('id, order_number, status, total_amount, created_at')
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .limit(20);

      final recentReviews = await supabase
          .from('reviews')
          .select(
            'id, customer_name, courier_rating, service_rating, taste_rating, comment, created_at',
          )
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .limit(10);

      List<MerchantNotification> notifications = [];

      // Son siparisleri bildirime cevir
      for (var order in recentOrders) {
        final status = order['status'] as String? ?? '';
        final createdAt = DateTime.parse(order['created_at']);
        final orderNumber = order['order_number'] ?? '';
        final total = ((order['total_amount'] ?? 0) as num).toDouble();

        String title;
        String message;
        String type;

        switch (status) {
          case 'pending':
            title = 'Yeni Siparis';
            message = 'Siparis #$orderNumber - ${total.toStringAsFixed(2)} TL';
            type = 'order';
            break;
          case 'cancelled':
            title = 'Siparis Iptal Edildi';
            message = 'Siparis #$orderNumber iptal edildi';
            type = 'order_cancelled';
            break;
          case 'delivered':
            title = 'Siparis Teslim Edildi';
            message = 'Siparis #$orderNumber basariyla teslim edildi';
            type = 'order';
            break;
          default:
            continue; // Diger durumlari atla
        }

        final notifId = 'order_${order['id']}';
        notifications.add(
          MerchantNotification(
            id: notifId,
            type: type,
            title: title,
            message: message,
            data: {'order_id': order['id']},
            isRead: _readNotificationIds.contains(notifId),
            createdAt: createdAt,
          ),
        );
      }

      // Son yorumlari bildirime cevir
      for (var review in recentReviews) {
        final createdAt = DateTime.parse(review['created_at']);
        final customerName = maskUserName(review['customer_name'] as String?);
        final courier = (review['courier_rating'] as num?)?.toDouble() ?? 0;
        final service = (review['service_rating'] as num?)?.toDouble() ?? 0;
        final taste = (review['taste_rating'] as num?)?.toDouble() ?? 0;
        final rating = ((courier + service + taste) / 3).round();

        final notifId = 'review_${review['id']}';
        notifications.add(
          MerchantNotification(
            id: notifId,
            type: 'review',
            title: 'Yeni Degerlendirme',
            message: '$customerName - $rating yildiz',
            data: {'review_id': review['id']},
            isRead: _readNotificationIds.contains(notifId),
            createdAt: createdAt,
          ),
        );
      }

      // Tarihe gore sirala
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = notifications.take(30).toList();

      // Realtime subscription baslat
      _subscribeToNotifications(merchantId);
    } catch (e, st) {
      LogService.error('loadNotifications failed', error: e, stackTrace: st, source: 'NotificationsNotifier:loadNotifications');
    }
  }

  void _subscribeToNotifications(String merchantId) {
    _unsubscribe();

    final supabase = ref.read(supabaseClientProvider);

    // Yeni yorumlari dinle
    _channel =
        supabase
            .channel('notifications_$merchantId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'reviews',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'merchant_id',
                value: merchantId,
              ),
              callback: (payload) {
                final review = payload.newRecord;
                final customerName = maskUserName(
                  review['customer_name'] as String?,
                );
                // Calculate average rating from courier, service, taste
                final courier =
                    (review['courier_rating'] as num?)?.toDouble() ?? 0;
                final service =
                    (review['service_rating'] as num?)?.toDouble() ?? 0;
                final taste = (review['taste_rating'] as num?)?.toDouble() ?? 0;
                final rating = ((courier + service + taste) / 3).round();

                addNotification(
                  MerchantNotification(
                    id: 'review_${review['id']}',
                    type: 'review',
                    title: 'Yeni Degerlendirme',
                    message: '$customerName - $rating yildiz',
                    data: {'review_id': review['id']},
                    createdAt: DateTime.now(),
                  ),
                );
              },
            )
            .subscribe();
  }

  void addNotification(MerchantNotification notification) {
    // Ayni id'ye sahip bildirim varsa ekleme
    if (state.any((n) => n.id == notification.id)) return;
    state = [notification, ...state];
  }

  void markAsRead(String notificationId) {
    _readNotificationIds.add(notificationId);
    _saveReadIds();
    state =
        state.map((n) {
          if (n.id == notificationId) {
            return MerchantNotification(
              id: n.id,
              type: n.type,
              title: n.title,
              message: n.message,
              data: n.data,
              isRead: true,
              createdAt: n.createdAt,
            );
          }
          return n;
        }).toList();
  }

  void markAllAsRead() {
    for (final n in state) {
      _readNotificationIds.add(n.id);
    }
    _saveReadIds();
    state =
        state
            .map(
              (n) => MerchantNotification(
                id: n.id,
                type: n.type,
                title: n.title,
                message: n.message,
                data: n.data,
                isRead: true,
                createdAt: n.createdAt,
              ),
            )
            .toList();
  }

  void clearAll() {
    state = [];
  }
}

class MerchantNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  MerchantNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });
}

// Unread Notifications Count
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

// Finance Stats Provider
final financeStatsProvider = FutureProvider.family<FinanceStats, FinanceQuery>((
  ref,
  query,
) async {
  final supabase = ref.read(supabaseClientProvider);
  final now = DateTime.now();

  // Merchant type'a gore service_type belirle
  String serviceType;
  switch (query.merchantType) {
    case MerchantType.restaurant:
      serviceType = 'restaurant';
      break;
    case MerchantType.market:
      serviceType = 'market';
      break;
    case MerchantType.store:
      serviceType = 'store';
      break;
  }

  // Komisyon oranini al (önce merchant override, sonra sektör varsayilani)
  double commissionRate = 10.0; // Fallback
  try {
    // Önce merchant-specific override kontrol et
    final overrideData =
        await supabase
            .from('merchant_commission_overrides')
            .select('custom_rate')
            .eq('merchant_id', query.merchantId)
            .maybeSingle();

    if (overrideData != null) {
      commissionRate =
          double.tryParse(
            overrideData['custom_rate']?.toString() ?? '10',
          ) ??
          10.0;
    } else {
      // Sektör bazlı varsayılan komisyon oranını al
      const sectorMap = {
        'restaurant': 'food',
        'store': 'store',
        'market': 'market',
        'taxi': 'taxi',
      };
      final sector = sectorMap[serviceType] ?? 'food';
      final sectorData =
          await supabase
              .from('commission_rates')
              .select('default_rate')
              .eq('sector', sector)
              .eq('is_active', true)
              .maybeSingle();

      if (sectorData != null) {
        commissionRate =
            double.tryParse(
              sectorData['default_rate']?.toString() ?? '10',
            ) ??
            10.0;
      }
    }
  } catch (e, st) {
    LogService.error('Komisyon orani alinamadi', error: e, stackTrace: st, source: 'financeStatsProvider');
  }

  // Tarih araligini hesapla
  DateTime startDate;
  switch (query.period) {
    case 'Bu Hafta':
      startDate = now.subtract(Duration(days: now.weekday - 1));
      break;
    case 'Bu Ay':
      startDate = DateTime(now.year, now.month, 1);
      break;
    case 'Son 3 Ay':
      startDate = DateTime(now.year, now.month - 2, 1);
      break;
    case 'Bu Yil':
      startDate = DateTime(now.year, 1, 1);
      break;
    default:
      startDate = DateTime(now.year, now.month, 1);
  }

  // Tum siparisleri al (commission_rate dahil)
  final orders = await supabase
      .from('orders')
      .select(
        'id, total_amount, status, payment_method, created_at, commission_rate',
      )
      .eq('merchant_id', query.merchantId)
      .gte('created_at', startDate.toIso8601String())
      .order('created_at', ascending: false);

  // Toplam gelir ve komisyon hesapla
  double totalRevenue = 0;
  double totalCommission = 0;
  double cashRevenue = 0;
  double cardRevenue = 0;
  double transferRevenue = 0;
  int completedOrders = 0;
  int cancelledOrders = 0;

  for (var order in orders) {
    final status = order['status'] as String? ?? '';
    final amount = ((order['total_amount'] ?? 0) as num).toDouble();
    final paymentMethod = order['payment_method'] as String? ?? 'card';

    // Siparişin kendi komisyon oranını kullan, yoksa güncel oranı fallback olarak kullan
    final orderCommissionRate =
        (order['commission_rate'] as num?)?.toDouble() ?? commissionRate;

    if (status != 'cancelled') {
      totalRevenue += amount;
      totalCommission += amount * (orderCommissionRate / 100);
      completedOrders++;

      // Odeme yontemine gore ayir
      switch (paymentMethod) {
        case 'cash':
          cashRevenue += amount;
          break;
        case 'transfer':
        case 'eft':
          transferRevenue += amount;
          break;
        default:
          cardRevenue += amount;
      }
    } else {
      cancelledOrders++;
    }
  }

  // Net gelir hesapla
  final netRevenue = totalRevenue - totalCommission;

  // Gunluk gelir verileri (grafik icin)
  Map<String, double> dailyRevenue = {};
  Map<String, double> dailyNetRevenue = {};

  for (var order in orders) {
    if (order['status'] == 'cancelled') continue;

    final createdAt = DateTime.parse(order['created_at']);
    final dayKey = '${createdAt.day}';
    final amount = ((order['total_amount'] ?? 0) as num).toDouble();
    final orderCommissionRate =
        (order['commission_rate'] as num?)?.toDouble() ?? commissionRate;

    dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + amount;
    dailyNetRevenue[dayKey] =
        (dailyNetRevenue[dayKey] ?? 0) +
        (amount * (1 - orderCommissionRate / 100));
  }

  // Son islemleri olustur
  List<FinanceTransaction> transactions = [];
  for (var order in orders.take(10)) {
    final status = order['status'] as String? ?? '';
    final amount = ((order['total_amount'] ?? 0) as num).toDouble();
    final createdAt = DateTime.parse(order['created_at']);
    final orderId = order['id'] as String? ?? '';
    final orderCommissionRate =
        (order['commission_rate'] as num?)?.toDouble() ?? commissionRate;

    if (status != 'cancelled') {
      // Siparis odemesi
      transactions.add(
        FinanceTransaction(
          id: 'TRX-$orderId',
          description: 'Siparis Odemesi',
          amount: amount,
          isIncome: true,
          status: 'Tamamlandi',
          date: createdAt,
        ),
      );

      // Komisyon kesintisi (siparişin kendi oranıyla)
      transactions.add(
        FinanceTransaction(
          id: 'COM-$orderId',
          description:
              'Komisyon Kesintisi (%${orderCommissionRate.toStringAsFixed(0)})',
          amount: amount * (orderCommissionRate / 100),
          isIncome: false,
          status: 'Tamamlandi',
          date: createdAt,
        ),
      );
    } else {
      // Iptal
      transactions.add(
        FinanceTransaction(
          id: 'CNC-$orderId',
          description: 'Siparis Iptali',
          amount: amount,
          isIncome: false,
          status: 'Iptal',
          date: createdAt,
        ),
      );
    }
  }

  // Tarihe gore sirala
  transactions.sort((a, b) => b.date.compareTo(a.date));

  return FinanceStats(
    totalRevenue: totalRevenue,
    commission: totalCommission,
    commissionRate: commissionRate, // Güncel oran (bilgi amaçlı)
    netRevenue: netRevenue,
    cashRevenue: cashRevenue,
    cardRevenue: cardRevenue,
    transferRevenue: transferRevenue,
    completedOrders: completedOrders,
    cancelledOrders: cancelledOrders,
    dailyRevenue: dailyRevenue,
    dailyNetRevenue: dailyNetRevenue,
    transactions: transactions.take(10).toList(),
  );
});

class FinanceQuery {
  final String merchantId;
  final String period;
  final MerchantType merchantType;

  FinanceQuery({
    required this.merchantId,
    this.period = 'Bu Ay',
    this.merchantType = MerchantType.restaurant,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceQuery &&
          runtimeType == other.runtimeType &&
          merchantId == other.merchantId &&
          period == other.period &&
          merchantType == other.merchantType;

  @override
  int get hashCode =>
      merchantId.hashCode ^ period.hashCode ^ merchantType.hashCode;
}

class FinanceStats {
  final double totalRevenue;
  final double commission;
  final double commissionRate;
  final double netRevenue;
  final double cashRevenue;
  final double cardRevenue;
  final double transferRevenue;
  final int completedOrders;
  final int cancelledOrders;
  final Map<String, double> dailyRevenue;
  final Map<String, double> dailyNetRevenue;
  final List<FinanceTransaction> transactions;

  FinanceStats({
    required this.totalRevenue,
    required this.commission,
    required this.commissionRate,
    required this.netRevenue,
    required this.cashRevenue,
    required this.cardRevenue,
    required this.transferRevenue,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.dailyRevenue,
    required this.dailyNetRevenue,
    required this.transactions,
  });

  double get cardPercentage =>
      totalRevenue > 0 ? (cardRevenue / totalRevenue * 100) : 0;
  double get cashPercentage =>
      totalRevenue > 0 ? (cashRevenue / totalRevenue * 100) : 0;
  double get transferPercentage =>
      totalRevenue > 0 ? (transferRevenue / totalRevenue * 100) : 0;
}

class FinanceTransaction {
  final String id;
  final String description;
  final double amount;
  final bool isIncome;
  final String status;
  final DateTime date;

  FinanceTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.status,
    required this.date,
  });
}

// Reports Stats Provider with date range parameter
class ReportsParams {
  final String merchantId;
  final DateTime startDate;
  final DateTime endDate;

  ReportsParams({
    required this.merchantId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportsParams &&
          merchantId == other.merchantId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(merchantId, startDate, endDate);
}

final reportsStatsProvider = FutureProvider.family<
  ReportsStats,
  ReportsParams
>((ref, params) async {
  final supabase = ref.read(supabaseClientProvider);
  final merchantId = params.merchantId;
  final startDate = params.startDate;
  final endDate = params.endDate.add(
    const Duration(days: 1),
  ); // Include end date

  // Calculate previous period for comparison (same duration before start date)
  final duration = endDate.difference(startDate);
  final prevStartDate = startDate.subtract(duration);
  final prevEndDate = startDate;

  // Secilen tarih araligindaki siparisler
  final periodOrders = await supabase
      .from('orders')
      .select('id, total_amount, status, items, user_id, created_at')
      .eq('merchant_id', merchantId)
      .gte('created_at', startDate.toIso8601String())
      .lt('created_at', endDate.toIso8601String());

  // Onceki donem siparisleri (karsilastirma icin)
  final prevPeriodOrders = await supabase
      .from('orders')
      .select('id, total_amount, status, created_at')
      .eq('merchant_id', merchantId)
      .gte('created_at', prevStartDate.toIso8601String())
      .lt('created_at', prevEndDate.toIso8601String());

  // Reviews - secilen tarih araliginda
  final reviews = await supabase
      .from('reviews')
      .select('courier_rating, service_rating, taste_rating, created_at')
      .eq('merchant_id', merchantId)
      .gte('created_at', startDate.toIso8601String())
      .lt('created_at', endDate.toIso8601String());

  // Istatistikleri hesapla
  int totalOrders = 0;
  int cancelledOrders = 0;
  double totalRevenue = 0;
  Map<String, int> productSales = {};
  Map<String, double> productRevenue = {};
  Set<String> uniqueCustomers = {};
  Map<int, int> hourlyOrders = {};
  Map<String, double> dailyRevenue = {};
  Map<String, int> dailyOrders = {};

  // Haftalik siparis sayilari (4 hafta)
  List<int> weeklyOrderCounts = [0, 0, 0, 0];
  List<int> prevPeriodWeeklyOrderCounts = [0, 0, 0, 0];

  // Onceki donemdeki musterileri bul (tekrar eden musteri hesabi icin)
  Set<String> prevPeriodCustomers = {};
  for (var order in prevPeriodOrders) {
    final usersId = order['user_id'] as String?;
    if (usersId != null && order['status'] != 'cancelled') {
      prevPeriodCustomers.add(usersId);
    }
  }

  // Secilen donem siparislerini isle
  Set<String> newCustomers = {};
  for (var order in periodOrders) {
    final status = order['status'] as String? ?? '';
    final amount = ((order['total_amount'] ?? 0) as num).toDouble();
    final usersId = order['user_id'] as String?;
    final createdAt = DateTime.parse(order['created_at']);
    final items = order['items'] as List<dynamic>? ?? [];

    // Gunluk veriler icin
    final dayKey =
        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

    if (status != 'cancelled') {
      totalOrders++;
      totalRevenue += amount;

      // Gunluk toplam
      dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + amount;
      dailyOrders[dayKey] = (dailyOrders[dayKey] ?? 0) + 1;

      if (usersId != null) {
        uniqueCustomers.add(usersId);
        // Yeni musteri mi kontrol et (onceki donemde siparis vermemis)
        if (!prevPeriodCustomers.contains(usersId)) {
          newCustomers.add(usersId);
        }
      }

      // Saat bazinda dagilim
      final hour = createdAt.hour;
      hourlyOrders[hour] = (hourlyOrders[hour] ?? 0) + 1;

      // Haftalik dagilim (secilen donem icinde)
      final daysSinceStart = createdAt.difference(startDate).inDays;
      final weekIndex = (daysSinceStart / 7).floor();
      if (weekIndex >= 0 && weekIndex < 4) {
        weeklyOrderCounts[weekIndex]++;
      }

      // Urun satislari
      for (var item in items) {
        final itemName = item['name'] as String? ?? 'Bilinmeyen';
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        final itemPrice = ((item['price'] ?? 0) as num).toDouble();

        productSales[itemName] = (productSales[itemName] ?? 0) + quantity;
        productRevenue[itemName] =
            (productRevenue[itemName] ?? 0) + (itemPrice * quantity);
      }
    } else {
      cancelledOrders++;
    }
  }

  // Onceki donem haftalik dagilim (karsilastirma icin)
  for (var order in prevPeriodOrders) {
    if (order['status'] != 'cancelled') {
      final createdAt = DateTime.parse(order['created_at']);
      final daysSinceStart = createdAt.difference(prevStartDate).inDays;
      final weekIndex = (daysSinceStart / 7).floor();
      if (weekIndex >= 0 && weekIndex < 4) {
        prevPeriodWeeklyOrderCounts[weekIndex]++;
      }
    }
  }

  // Ortalama siparis degeri
  double averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

  // Iptal orani
  double cancellationRate =
      (totalOrders + cancelledOrders) > 0
          ? (cancelledOrders / (totalOrders + cancelledOrders) * 100)
          : 0;

  // En cok satan urunler
  var sortedProducts =
      productSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  List<TopProduct> topProducts =
      sortedProducts
          .take(5)
          .map(
            (e) => TopProduct(
              name: e.key,
              quantity: e.value,
              revenue: productRevenue[e.key] ?? 0,
            ),
          )
          .toList();

  // En cok satan urun
  String bestSellingProduct =
      topProducts.isNotEmpty ? topProducts.first.name : '-';
  int bestSellingQuantity =
      topProducts.isNotEmpty ? topProducts.first.quantity : 0;

  // Ortalama rating - calculate from courier, service, taste ratings
  double averageRating = 0;
  double avgCourierRating = 0;
  double avgServiceRating = 0;
  double avgTasteRating = 0;

  if (reviews.isNotEmpty) {
    double totalRating = 0;
    double totalCourier = 0;
    double totalService = 0;
    double totalTaste = 0;

    for (var review in reviews) {
      final courier = (review['courier_rating'] as num?)?.toDouble() ?? 0;
      final service = (review['service_rating'] as num?)?.toDouble() ?? 0;
      final taste = (review['taste_rating'] as num?)?.toDouble() ?? 0;
      totalRating += (courier + service + taste) / 3;
      totalCourier += courier;
      totalService += service;
      totalTaste += taste;
    }
    averageRating = totalRating / reviews.length;
    avgCourierRating = totalCourier / reviews.length;
    avgServiceRating = totalService / reviews.length;
    avgTasteRating = totalTaste / reviews.length;
  }

  // Tekrar eden musteri orani
  // Tekrar eden = onceki donemde de siparis vermis musteriler
  int repeatCustomers =
      uniqueCustomers.intersection(prevPeriodCustomers).length;
  double repeatCustomerRate =
      uniqueCustomers.isNotEmpty
          ? (repeatCustomers / uniqueCustomers.length * 100)
          : 0;

  // Ortalama siparis per musteri
  double avgOrdersPerCustomer =
      uniqueCustomers.isNotEmpty ? totalOrders / uniqueCustomers.length : 0;

  // Saatlik siparis dagilimi (10-22 arasi)
  List<int> hourlyDistribution = [];
  for (int h = 10; h <= 22; h += 2) {
    hourlyDistribution.add((hourlyOrders[h] ?? 0) + (hourlyOrders[h + 1] ?? 0));
  }

  // En yogun saat
  int peakHour = 12;
  int maxOrders = 0;
  hourlyOrders.forEach((hour, count) {
    if (count > maxOrders) {
      maxOrders = count;
      peakHour = hour;
    }
  });

  // Onceki donem toplam siparis sayisi
  int prevPeriodTotalOrders = 0;
  for (var order in prevPeriodOrders) {
    if (order['status'] != 'cancelled') {
      prevPeriodTotalOrders++;
    }
  }

  // Gunluk veriler listesi olustur
  List<DailyStat> dailyStats = [];
  for (var entry in dailyOrders.entries) {
    dailyStats.add(
      DailyStat(
        date: entry.key,
        orders: entry.value,
        revenue: dailyRevenue[entry.key] ?? 0,
      ),
    );
  }
  dailyStats.sort((a, b) => a.date.compareTo(b.date));

  return ReportsStats(
    totalOrders: totalOrders,
    totalRevenue: totalRevenue,
    averageOrderValue: averageOrderValue,
    bestSellingProduct: bestSellingProduct,
    bestSellingQuantity: bestSellingQuantity,
    cancellationRate: cancellationRate,
    cancelledOrders: cancelledOrders,
    weeklyOrderCounts: weeklyOrderCounts,
    prevPeriodWeeklyOrderCounts: prevPeriodWeeklyOrderCounts,
    prevPeriodTotalOrders: prevPeriodTotalOrders,
    topProducts: topProducts,
    hourlyDistribution: hourlyDistribution,
    peakHour: peakHour,
    totalCustomers: uniqueCustomers.length,
    newCustomersCount: newCustomers.length,
    repeatCustomerRate: repeatCustomerRate,
    averageRating: averageRating,
    avgCourierRating: avgCourierRating,
    avgServiceRating: avgServiceRating,
    avgTasteRating: avgTasteRating,
    avgOrdersPerCustomer: avgOrdersPerCustomer,
    dailyStats: dailyStats,
  );
});

class DailyStat {
  final String date;
  final int orders;
  final double revenue;

  DailyStat({required this.date, required this.orders, required this.revenue});

  double get averageOrderValue => orders > 0 ? revenue / orders : 0;
}

class ReportsStats {
  final int totalOrders;
  final double totalRevenue;
  final double averageOrderValue;
  final String bestSellingProduct;
  final int bestSellingQuantity;
  final double cancellationRate;
  final int cancelledOrders;
  final List<int> weeklyOrderCounts;
  final List<int> prevPeriodWeeklyOrderCounts;
  final int prevPeriodTotalOrders;
  final List<TopProduct> topProducts;
  final List<int> hourlyDistribution;
  final int peakHour;
  final int totalCustomers;
  final int newCustomersCount;
  final double repeatCustomerRate;
  final double averageRating;
  final double avgCourierRating;
  final double avgServiceRating;
  final double avgTasteRating;
  final double avgOrdersPerCustomer;
  final List<DailyStat> dailyStats;

  ReportsStats({
    required this.totalOrders,
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.bestSellingProduct,
    required this.bestSellingQuantity,
    required this.cancellationRate,
    required this.cancelledOrders,
    required this.weeklyOrderCounts,
    required this.prevPeriodWeeklyOrderCounts,
    required this.prevPeriodTotalOrders,
    required this.topProducts,
    required this.hourlyDistribution,
    required this.peakHour,
    required this.totalCustomers,
    required this.newCustomersCount,
    required this.repeatCustomerRate,
    required this.averageRating,
    required this.avgCourierRating,
    required this.avgServiceRating,
    required this.avgTasteRating,
    required this.avgOrdersPerCustomer,
    required this.dailyStats,
  });

  double get orderChangePercent {
    if (prevPeriodTotalOrders == 0) return totalOrders > 0 ? 100 : 0;
    return ((totalOrders - prevPeriodTotalOrders) /
        prevPeriodTotalOrders *
        100);
  }
}

class TopProduct {
  final String name;
  final int quantity;
  final double revenue;

  TopProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}
