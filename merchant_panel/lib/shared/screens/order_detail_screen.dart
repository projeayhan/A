import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/merchant_models.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_dialogs.dart';
import 'couriers_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return orders.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Hata: $error'))),
      data: (orderList) {
        final order = orderList.where((o) => o.id == orderId).firstOrNull;

        if (order != null) {
          return _buildOrderScaffold(context, order, ref);
        }

        // Sipariş listede yoksa (örn: realtime senkronizasyon sorunu), tekil olarak çek
        return FutureBuilder<Order?>(
          future: _fetchSingleOrder(ref, orderId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              return _buildOrderScaffold(context, snapshot.data!, ref);
            }

            // Hata detayını göster
            final errorMessage =
                snapshot.error?.toString() ?? 'Sipariş verisi alınamadı';

            return Scaffold(
              appBar: AppBar(title: const Text('Sipariş Detayı')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sipariş bulunamadı',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Hata mesajını daha belirgin göster
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Teknik Detay: $errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // Geri dön
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/orders');
                          }
                        },
                        child: const Text('Geri Dön'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Order?> _fetchSingleOrder(WidgetRef ref, String orderId) async {
    final supabase = ref.read(supabaseProvider);

    try {
      // 1. Deneme: Detaylı veri (Join ile)
      final response =
          await supabase
              .from('orders')
              .select(
                '*, users:user_id(full_name, phone, avatar_url), courier:courier_id(full_name)',
              )
              .eq('id', orderId)
              .maybeSingle();

      if (response == null) {
        throw 'Sipariş veritabanında bulunamadı (Detaylı Sorgu)';
      }
      return Order.fromJson(response);
    } catch (e) {
      debugPrint('!!! Deep fetch failed (Join Failure): $e');
      debugPrint('!!! Switching to simple fetch strategy...');

      try {
        // 2. Deneme: Basit veri (Join olmadan)
        final response =
            await supabase
                .from('orders')
                .select()
                .eq('id', orderId)
                .maybeSingle();

        if (response == null) {
          throw 'Sipariş veritabanında bulunamadı (Basit Sorgu - ID: $orderId) - RLS veya Veri Yok';
        }
        return Order.fromJson(response);
      } catch (e2) {
        debugPrint('!!! Simple fetch also failed: $e2');
        throw e2.toString();
      }
    }
  }

  Widget _buildOrderScaffold(BuildContext context, Order order, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Siparis #${order.orderNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // Print order
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // More options
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column - Order Details
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildStatusCard(context, order, ref),
                  const SizedBox(height: 24),
                  _buildItemsCard(context, order),
                  const SizedBox(height: 24),
                  _buildPaymentCard(context, order),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Right Column - Customer & Timeline
            Expanded(
              child: Column(
                children: [
                  _buildCustomerCard(context, order),
                  const SizedBox(height: 24),
                  _buildCourierCard(context, order, ref),
                  const SizedBox(height: 24),
                  _buildMessagesCard(context, order, ref),
                  const SizedBox(height: 24),
                  _buildTimelineCard(context, order),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, Order order, WidgetRef ref) {
    // Kurye atandıysa ve sipariş ready durumundaysa, kontrol kuryeye geçti
    final isCourierInControl =
        order.hasCourierAssigned &&
        (order.status == OrderStatus.ready ||
            order.status == OrderStatus.pickedUp ||
            order.status == OrderStatus.delivering);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: order.status.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(order.status.icon, color: order.status.color),
                    const SizedBox(width: 8),
                    Text(
                      order.status.displayName,
                      style: TextStyle(
                        color: order.status.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM yyyy, HH:mm').format(order.createdAt),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          // Kurye kontrolünde ise uyarı göster
          if (isCourierInControl) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(Icons.delivery_dining, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Siparis kuryeye atandi. Durum degisiklikleri artik kurye tarafindan yapilacak.',
                      style: TextStyle(color: AppColors.info, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Kurye kontrolünde değilse ve sipariş tamamlanmamışsa durum güncelleme göster
          if (!isCourierInControl &&
              order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled)
            _buildStatusUpdateSection(context, order, ref),
        ],
      ),
    );
  }

  Widget _buildStatusUpdateSection(
    BuildContext context,
    Order order,
    WidgetRef ref,
  ) {
    // Restoranın kuryesi var mı kontrol et
    final merchantCouriers = ref.watch(merchantCouriersProvider);
    final hasCouriers =
        merchantCouriers.whenData((list) => list.isNotEmpty).value ?? false;

    final nextOptions = _getNextStatusOptions(order, hasCouriers);

    if (nextOptions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Text(
            'Siparisi Guncelle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                nextOptions.map((status) {
                  return ElevatedButton.icon(
                    onPressed: () {
                      ref
                          .read(ordersProvider.notifier)
                          .updateOrderStatus(order.id, status);
                    },
                    icon: Icon(status.icon, size: 18),
                    label: Text(status.displayName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status.color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      );
    } else if (order.status == OrderStatus.ready && !order.hasCourierAssigned) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withAlpha(50)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Siparis hazir. Devam etmek icin kurye atamasi yapilmasi gerekiyor.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  List<OrderStatus> _getNextStatusOptions(
    Order order,
    bool merchantHasCouriers,
  ) {
    // Kurye atandıysa, sadece preparing -> ready geçişine izin ver
    // ready'den sonraki tüm durumlar kurye tarafından kontrol edilir
    if (order.hasCourierAssigned) {
      switch (order.status) {
        case OrderStatus.pending:
          return [OrderStatus.confirmed, OrderStatus.cancelled];
        case OrderStatus.confirmed:
          return [OrderStatus.preparing, OrderStatus.cancelled];
        case OrderStatus.preparing:
          return [OrderStatus.ready]; // Sadece ready'e geçebilir
        case OrderStatus.ready:
        case OrderStatus.pickedUp:
        case OrderStatus.delivering:
          return []; // Kurye kontrolünde, restoran değiştiremez
        default:
          return [];
      }
    }

    // Restoranın kuryesi varsa, ready'den sonra kurye ataması gerekli
    if (merchantHasCouriers) {
      switch (order.status) {
        case OrderStatus.pending:
          return [OrderStatus.confirmed, OrderStatus.cancelled];
        case OrderStatus.confirmed:
          return [OrderStatus.preparing, OrderStatus.cancelled];
        case OrderStatus.preparing:
          return [OrderStatus.ready];
        case OrderStatus.ready:
          return []; // Kurye ataması gerekli
        default:
          return [];
      }
    }

    // Restoranın kuryesi yoksa, tüm akışı restoran kontrol eder
    switch (order.status) {
      case OrderStatus.pending:
        return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [OrderStatus.preparing, OrderStatus.cancelled];
      case OrderStatus.preparing:
        return [OrderStatus.ready];
      case OrderStatus.ready:
        return [OrderStatus.pickedUp]; // Restoran kendisi alıyor
      case OrderStatus.pickedUp:
        return [OrderStatus.delivering];
      case OrderStatus.delivering:
        return [OrderStatus.delivered];
      default:
        return [];
    }
  }

  Widget _buildItemsCard(BuildContext context, Order order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Siparis Icerigi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        item.imageUrl != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                            : const Icon(
                              Icons.fastfood,
                              color: AppColors.textMuted,
                            ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (item.notes != null)
                          Text(
                            item.notes!,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'x${item.quantity}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${item.total.toStringAsFixed(2)} TL',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ara Toplam',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text('${order.subtotal.toStringAsFixed(2)} TL'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Teslimat Ucreti',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text('${order.deliveryFee.toStringAsFixed(2)} TL'),
            ],
          ),
          if (order.discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Indirim', style: TextStyle(color: AppColors.success)),
                Text(
                  '-${order.discount.toStringAsFixed(2)} TL',
                  style: const TextStyle(color: AppColors.success),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Toplam', style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${order.total.toStringAsFixed(2)} TL',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, Order order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Odeme Bilgileri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  order.paymentMethod == 'card'
                      ? Icons.credit_card
                      : Icons.money,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.paymentMethod == 'card' ? 'Kredi Karti' : 'Nakit',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order.paymentStatus == 'paid'
                          ? 'Odendi'
                          : 'Odeme Bekliyor',
                      style: TextStyle(
                        color:
                            order.paymentStatus == 'paid'
                                ? AppColors.success
                                : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, Order order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Musteri Bilgileri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withAlpha(30),
                child: Text(
                  order.customerName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (order.customerPhone != null)
                      Text(
                        order.customerPhone!,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: AppColors.textMuted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Teslimat Adresi',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.deliveryAddress,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.deliveryInstructions != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teslimat Notu',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.deliveryInstructions!,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Call customer
                  },
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Ara'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Message customer
                  },
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('Mesaj'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourierCard(BuildContext context, Order order, WidgetRef ref) {
    final merchantCouriers = ref.watch(merchantCouriersProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Kurye Atama',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (order.status == OrderStatus.ready ||
                  order.status == OrderStatus.preparing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Kurye Bekleniyor',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Show assigned courier or assignment options
          if (order.status == OrderStatus.pickedUp ||
              order.status == OrderStatus.delivering ||
              order.status == OrderStatus.delivered) ...[
            // Courier is assigned - show info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.success.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.delivery_dining,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kurye Atandi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Siparis teslim surecinde',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (order.status == OrderStatus.pending ||
              order.status == OrderStatus.confirmed ||
              order.status == OrderStatus.preparing ||
              order.status == OrderStatus.ready) ...[
            // Show courier assignment options
            merchantCouriers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, __) {
                debugPrint('merchantCouriers error: $err');
                return const Text('Kuryeler yuklenemedi');
              },
              data: (couriers) {
                debugPrint('merchantCouriers data: $couriers');
                // Online olan kuryeleri filtrele (meşgul olsalar bile göster - restoran kuryesine her zaman atanabilir)
                final onlineCouriers =
                    couriers.where((c) => c['is_online'] == true).toList();
                final availableCouriers =
                    onlineCouriers.where((c) => c['is_busy'] != true).toList();
                debugPrint('onlineCouriers: $onlineCouriers');

                return Column(
                  children: [
                    // My Couriers Button - Restoran kuryelerine her zaman sipariş atanabilir
                    _CourierOptionButton(
                      icon: Icons.person,
                      title: 'Kendi Kuryem',
                      subtitle:
                          onlineCouriers.isNotEmpty
                              ? '${onlineCouriers.length} kurye online${availableCouriers.length < onlineCouriers.length ? ' (${onlineCouriers.length - availableCouriers.length} teslimatta)' : ''}'
                              : 'Online kurye yok',
                      color:
                          onlineCouriers.isNotEmpty
                              ? AppColors.primary
                              : AppColors.textMuted,
                      onTap:
                          onlineCouriers.isNotEmpty
                              ? () => _showMyCouriersDialog(
                                context,
                                ref,
                                order,
                                onlineCouriers,
                              )
                              : null,
                    ),
                    const SizedBox(height: 12),

                    // Platform Couriers Button
                    _CourierOptionButton(
                      icon: Icons.public,
                      title: 'Platform Kuryesi',
                      subtitle: 'Yakin kuryelere teklif gonder',
                      color: AppColors.info,
                      onTap:
                          () =>
                              _broadcastToPlatformCouriers(context, ref, order),
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            // Order is cancelled or in a state where courier can't be assigned
            Center(
              child: Text(
                'Bu siparis icin kurye atanamaz',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMyCouriersDialog(
    BuildContext context,
    WidgetRef ref,
    Order order,
    List<Map<String, dynamic>> couriers,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kurye Sec'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    couriers.map((courier) {
                      // Kurye direkt olarak couriers tablosundan geliyor
                      final isOnline = courier['is_online'] == true;
                      final isBusy = courier['is_busy'] == true;
                      final fullName =
                          courier['full_name'] as String? ?? 'Kurye';

                      // Restoran kuryesi için: online ise her zaman atanabilir (meşgul olsa bile)
                      // Meşgul kurye zaten bir siparişi var ama yeni sipariş de atanabilir
                      final canAssign = isOnline;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            fullName.isNotEmpty
                                ? fullName.substring(0, 1).toUpperCase()
                                : 'K',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                        title: Text(fullName),
                        subtitle: Row(
                          children: [
                            Text(
                              isOnline ? 'Online' : 'Cevrimdisi',
                              style: TextStyle(
                                color:
                                    isOnline
                                        ? AppColors.success
                                        : AppColors.textMuted,
                              ),
                            ),
                            if (isBusy) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Teslimatta',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        enabled: canAssign,
                        onTap:
                            canAssign
                                ? () {
                                  Navigator.pop(context);
                                  _assignCourier(
                                    context,
                                    ref,
                                    order,
                                    courier['id'],
                                    'restaurant',
                                  );
                                }
                                : null,
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Iptal'),
              ),
            ],
          ),
    );
  }

  Future<void> _assignCourier(
    BuildContext context,
    WidgetRef ref,
    Order order,
    String? courierId,
    String courierType,
  ) async {
    if (courierId == null) return;

    final supabase = ref.read(supabaseProvider);

    try {
      await supabase
          .from('orders')
          .update({
            'courier_id': courierId,
            'courier_type': courierType,
            'delivery_status': 'assigned',
            'courier_assigned_at': DateTime.now().toIso8601String(),
          })
          .eq('id', order.id);

      // Restoran kuryesi için is_busy güncelleme - birden fazla sipariş alabilir
      // Platform kuryesi için is_busy: true olarak ayarla
      if (courierType == 'platform') {
        await supabase
            .from('couriers')
            .update({'is_busy': true, 'current_order_id': order.id})
            .eq('id', courierId);
      }
      // Restoran kuryesi için is_busy güncellemiyoruz - her zaman yeni sipariş alabilir

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kurye atandi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppDialogs.showError(context, 'Hata: $e');
      }
    }
  }

  Future<void> _broadcastToPlatformCouriers(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final supabase = ref.read(supabaseProvider);

    // Platform kurye ücretini hesapla (koordinatlar varsa)
    Map<String, dynamic>? feeData;
    if (order.deliveryLat != null && order.deliveryLng != null) {
      try {
        final feeResult = await supabase.rpc('calculate_platform_delivery_fee', params: {
          'p_merchant_id': order.merchantId,
          'p_customer_lat': order.deliveryLat,
          'p_customer_lon': order.deliveryLng,
        });
        if (feeResult != null && (feeResult as List).isNotEmpty) {
          feeData = feeResult[0] as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Platform fee calculation error: $e');
      }
    }

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Platform Kuryesi Çağır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sipariş: #${order.orderNumber}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (order.deliveryAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                order.deliveryAddress,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
            if (feeData != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _feeRow('Mesafe', '${feeData['distance_km']} km'),
                    const SizedBox(height: 6),
                    _feeRow('Tahmini Süre', '~${feeData['estimated_duration_min']} dk'),
                    const SizedBox(height: 6),
                    _feeRow('Teslimat Ücreti', '${(feeData['final_fee'] as num).toStringAsFixed(2)} TL',
                        bold: true),
                    if ((feeData['multiplier_reason'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      _feeRow('Çarpan', '${feeData['multiplier_reason']} x${feeData['multiplier']}'),
                    ],
                    const Divider(height: 16),
                    _feeRow('Kurye Kazancı', '${(feeData['courier_earning'] as num).toStringAsFixed(2)} TL'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'En yakın müsait kuryeye teklif gönderilecek. '
              '30sn içinde kabul edilmezse sıradaki kuryeye geçilecek.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kurye Çağır'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await supabase.rpc('start_sequential_courier_assignment', params: {
        'p_order_id': order.id,
        'p_max_distance_km': 10.0,
      });

      if (context.mounted) {
        final success = result['success'] as bool? ?? false;
        if (success) {
          final totalCouriers = result['total_couriers'] as int? ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'En yakın kuryeye teklif gönderildi. '
                '($totalCouriers kurye sırada)',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final error = result['error'] as String? ?? 'Bilinmeyen hata';
          AppDialogs.showWarning(context, error);
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppDialogs.showError(context, 'Hata: $e');
      }
    }
  }

  static Widget _feeRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: bold ? AppColors.primary : Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesCard(BuildContext context, Order order, WidgetRef ref) {
    return _OrderMessagesCard(orderId: order.id, merchantId: order.merchantId);
  }

  Widget _buildTimelineCard(BuildContext context, Order order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Siparis Gecmisi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          _TimelineItem(
            title: 'Siparis Olusturuldu',
            time: DateFormat('HH:mm').format(order.createdAt),
            isCompleted: true,
            isFirst: true,
          ),
          if (order.confirmedAt != null)
            _TimelineItem(
              title: 'Onaylandi',
              time: DateFormat('HH:mm').format(order.confirmedAt!),
              isCompleted: true,
            ),
          if (order.preparedAt != null)
            _TimelineItem(
              title: 'Hazirlandi',
              time: DateFormat('HH:mm').format(order.preparedAt!),
              isCompleted: true,
            ),
          if (order.pickedUpAt != null)
            _TimelineItem(
              title: 'Kurye Aldi',
              time: DateFormat('HH:mm').format(order.pickedUpAt!),
              isCompleted: true,
            ),
          if (order.deliveredAt != null)
            _TimelineItem(
              title: 'Teslim Edildi',
              time: DateFormat('HH:mm').format(order.deliveredAt!),
              isCompleted: true,
              isLast: true,
            ),
          if (order.cancelledAt != null)
            _TimelineItem(
              title: 'Iptal Edildi',
              subtitle: order.cancellationReason,
              time: DateFormat('HH:mm').format(order.cancelledAt!),
              isCompleted: true,
              isLast: true,
              color: AppColors.error,
            ),
        ],
      ),
    );
  }
}

class _CourierOptionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _CourierOptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String time;
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;
  final Color? color;

  const _TimelineItem({
    required this.title,
    this.subtitle,
    required this.time,
    required this.isCompleted,
    this.isFirst = false,
    this.isLast = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.success;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? activeColor : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child:
                  isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color:
                    isCompleted ? activeColor.withAlpha(100) : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          isCompleted
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
              SizedBox(height: isLast ? 0 : 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sipariş mesajları kartı - realtime ile güncellenir
class _OrderMessagesCard extends ConsumerStatefulWidget {
  final String orderId;
  final String merchantId;

  const _OrderMessagesCard({
    required this.orderId,
    required this.merchantId,
  });

  @override
  ConsumerState<_OrderMessagesCard> createState() => _OrderMessagesCardState();
}

class _OrderMessagesCardState extends ConsumerState<_OrderMessagesCard> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  dynamic _subscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final messages = await supabase
          .from('order_messages')
          .select('*')
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(messages);
          _isLoading = false;
        });
        _scrollToBottom();

        // Okunmamış mesajları okundu olarak işaretle
        _markMessagesAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading messages: $e');
    }
  }

  void _setupRealtimeSubscription() {
    final supabase = ref.read(supabaseProvider);
    _subscription = supabase
        .channel('order_messages_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _messages.add(payload.newRecord);
              });
              _scrollToBottom();
              _markMessagesAsRead();
            }
          },
        )
        .subscribe();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final supabase = ref.read(supabaseProvider);
      // Sadece müşteriden gelen okunmamış mesajları işaretle
      await supabase
          .from('order_messages')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('order_id', widget.orderId)
          .eq('sender_type', 'customer')
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    try {
      final supabase = ref.read(supabaseProvider);
      final merchant = ref.read(currentMerchantProvider).value;

      await supabase.from('order_messages').insert({
        'order_id': widget.orderId,
        'merchant_id': widget.merchantId,
        'sender_type': 'merchant',
        'sender_name': merchant?.businessName ?? 'Restoran',
        'message': message,
      });
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Mesaj gönderilemedi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _messages.where((m) =>
      m['sender_type'] == 'customer' && m['is_read'] != true
    ).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Müşteri Mesajları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount yeni',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Messages list
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz mesaj yok',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isFromMerchant = msg['sender_type'] == 'merchant';
                          final time = DateTime.tryParse(msg['created_at'] ?? '');
                          final timeStr = time != null
                              ? DateFormat('HH:mm').format(time.toLocal())
                              : '';

                          return Align(
                            alignment: isFromMerchant
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.6,
                              ),
                              decoration: BoxDecoration(
                                color: isFromMerchant
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isFromMerchant)
                                    Text(
                                      msg['sender_name'] ?? 'Müşteri',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  Text(
                                    msg['message'] ?? '',
                                    style: TextStyle(
                                      color: isFromMerchant
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isFromMerchant
                                          ? Colors.white70
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),

          // Message input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yazın...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
