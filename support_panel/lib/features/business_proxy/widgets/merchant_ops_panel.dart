import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/business_proxy_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/status_badge.dart';

class MerchantOpsPanel extends ConsumerStatefulWidget {
  final String businessId;
  final Map<String, dynamic> data;
  const MerchantOpsPanel({super.key, required this.businessId, required this.data});

  @override
  ConsumerState<MerchantOpsPanel> createState() => _MerchantOpsPanelState();
}

class _MerchantOpsPanelState extends ConsumerState<MerchantOpsPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _menuCategories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _productCategories = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _workingHours = [];
  List<Map<String, dynamic>> _couriers = [];
  Map<String, dynamic>? _merchantSettings;
  bool _isLoading = true;
  String _reviewFilter = 'all';

  // Products tab state
  String _productFilter = 'all'; // all, low_stock, out_of_stock
  bool _bulkEditMode = false;
  final Map<String, TextEditingController> _bulkStockControllers = {};

  // Finance tab state
  String _financePeriod = 'month';
  Map<String, dynamic>? _financeData;
  bool _financeLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in _bulkStockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final service = ref.read(businessProxyServiceProvider);
    try {
      final results = await Future.wait([
        service.getMerchantOrders(widget.businessId),
        service.getMenuItems(widget.businessId),
        service.getMenuCategories(widget.businessId),
        service.getStoreProducts(widget.businessId),
        service.getProductCategories(widget.businessId),
        service.getMerchantReviews(widget.businessId),
        service.getMerchantWorkingHours(widget.businessId),
        service.getMerchantCouriers(widget.businessId),
        service.getMerchantSettings(widget.businessId),
      ]);
      setState(() {
        _orders = results[0] as List<Map<String, dynamic>>;
        _menuItems = results[1] as List<Map<String, dynamic>>;
        _menuCategories = results[2] as List<Map<String, dynamic>>;
        _products = results[3] as List<Map<String, dynamic>>;
        _productCategories = results[4] as List<Map<String, dynamic>>;
        _reviews = results[5] as List<Map<String, dynamic>>;
        _workingHours = results[6] as List<Map<String, dynamic>>;
        _couriers = results[7] as List<Map<String, dynamic>>;
        _merchantSettings = results[8] as Map<String, dynamic>?;
        _isLoading = false;
      });
      _loadFinance();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFinance() async {
    setState(() => _financeLoading = true);
    final now = DateTime.now();
    DateTime start;
    switch (_financePeriod) {
      case 'week':
        start = now.subtract(const Duration(days: 7));
        break;
      case '3months':
        start = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'year':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }
    try {
      final data = await ref.read(businessProxyServiceProvider).getMerchantFinance(widget.businessId, start, now);
      setState(() {
        _financeData = data;
        _financeLoading = false;
      });
    } catch (e) {
      setState(() => _financeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: textMuted,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Siparisler (${_orders.length})'),
            Tab(text: 'Menu (${_menuItems.length})'),
            Tab(text: 'Urunler (${_products.length})'),
            Tab(text: 'Degerlendirmeler (${_reviews.length})'),
            const Tab(text: 'Finans'),
            Tab(text: 'Kuryeler (${_couriers.length})'),
            const Tab(text: 'Ayarlar'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildOrdersTab(isDark),
              _buildMenuTab(isDark),
              _buildProductsTab(isDark),
              _buildReviewsTab(isDark),
              _buildFinanceTab(isDark),
              _buildCouriersTab(isDark),
              _buildSettingsTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ─── Orders Tab (Enhanced) ───
  // ═══════════════════════════════════════════

  Widget _buildOrdersTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final df = DateFormat('dd.MM.yyyy HH:mm');

    if (_orders.isEmpty) return Center(child: Text('Siparis yok', style: TextStyle(color: textMuted)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _orders.length,
      itemBuilder: (ctx, i) {
        final o = _orders[i];
        final createdAt = DateTime.tryParse(o['created_at'] ?? '');
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showOrderDetailDialog(o),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${(o['order_number'] ?? o['id'].toString().substring(0, 8))} - ${_currency(o['total_amount'])}',
                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${o['customer_name'] ?? 'Musteri'} ${createdAt != null ? '• ${df.format(createdAt.toLocal())}' : ''}',
                          style: TextStyle(color: textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  _buildOrderStatusDropdown(o),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderStatusDropdown(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    return PopupMenuButton<String>(
      onSelected: (newStatus) async {
        final service = ref.read(businessProxyServiceProvider);
        await service.updateOrderStatus(order['id'], newStatus, merchantId: widget.businessId);
        _loadData();
      },
      child: StatusBadge.ticketStatus(status),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'confirmed', child: Text('Onayla')),
        const PopupMenuItem(value: 'preparing', child: Text('Hazirlaniyor')),
        const PopupMenuItem(value: 'ready', child: Text('Hazir')),
        const PopupMenuItem(value: 'delivered', child: Text('Teslim Edildi')),
        const PopupMenuItem(value: 'cancelled', child: Text('Iptal')),
      ],
    );
  }

  void _showOrderDetailDialog(Map<String, dynamic> order) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final messageCtrl = TextEditingController();
    List<Map<String, dynamic>> messages = [];
    bool loadingMessages = true;
    Map<String, dynamic>? orderDetail;
    bool loadingDetail = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Load detail + messages on first build
          if (loadingDetail) {
            Future.microtask(() async {
              final service = ref.read(businessProxyServiceProvider);
              final results = await Future.wait([
                service.getOrderWithDetails(order['id']),
                service.getOrderMessages(order['id']),
              ]);
              if (ctx.mounted) {
                setDialogState(() {
                  orderDetail = results[0] as Map<String, dynamic>?;
                  messages = results[1] as List<Map<String, dynamic>>;
                  loadingDetail = false;
                  loadingMessages = false;
                });
              }
            });
          }

          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
          final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
          final o = orderDetail ?? order;
          final items = o['items'] as List<dynamic>? ?? [];
          final courier = o['couriers'] as Map<String, dynamic>?;
          final phone = o['customer_phone'] ?? '';
          final maskedPhone = phone.length >= 4 ? '${phone.substring(0, 4)} *** **${phone.substring(phone.length - 2)}' : phone;

          return AlertDialog(
            title: Row(
              children: [
                Text('Siparis #${o['order_number'] ?? o['id'].toString().substring(0, 8)}', style: const TextStyle(fontSize: 16)),
                const Spacer(),
                StatusBadge.ticketStatus(o['status'] ?? 'pending'),
              ],
            ),
            content: SizedBox(
              width: 600,
              height: 500,
              child: loadingDetail
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: AppColors.primary,
                            unselectedLabelColor: textMuted,
                            tabs: const [
                              Tab(text: 'Detay'),
                              Tab(text: 'Mesajlar'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Detail tab
                                SingleChildScrollView(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Items
                                      Text('Urunler', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      ...items.map((item) {
                                        final it = item is Map ? item : <String, dynamic>{};
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            children: [
                                              Text('${it['quantity'] ?? 1}x ', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                              Expanded(child: Text(it['name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 12))),
                                              Text(_currency(it['price']), style: TextStyle(color: textMuted, fontSize: 12)),
                                            ],
                                          ),
                                        );
                                      }),
                                      const Divider(height: 20),
                                      // Customer
                                      Text('Musteri', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      _detailRow('Ad', o['customer_name'] ?? '-', textPrimary, textMuted),
                                      _detailRow('Telefon', maskedPhone, textPrimary, textMuted),
                                      _detailRow('Adres', o['delivery_address'] ?? '-', textPrimary, textMuted),
                                      const Divider(height: 20),
                                      // Payment
                                      Text('Odeme', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      _detailRow('Yontem', _paymentMethodLabel(o['payment_method']), textPrimary, textMuted),
                                      _detailRow('Durum', o['payment_status'] ?? '-', textPrimary, textMuted),
                                      _detailRow('Toplam', _currency(o['total_amount']), textPrimary, textMuted),
                                      if ((o['delivery_fee'] as num?) != null && (o['delivery_fee'] as num) > 0)
                                        _detailRow('Teslimat', _currency(o['delivery_fee']), textPrimary, textMuted),
                                      const Divider(height: 20),
                                      // Courier
                                      Text('Kurye', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      if (courier != null) ...[
                                        _detailRow('Ad', courier['full_name'] ?? '-', textPrimary, textMuted),
                                        _detailRow('Telefon', courier['phone'] ?? '-', textPrimary, textMuted),
                                        _detailRow('Arac', '${courier['vehicle_type'] ?? '-'} ${courier['vehicle_plate'] ?? ''}', textPrimary, textMuted),
                                      ] else
                                        Text('Henuz atanmadi', style: TextStyle(color: textMuted, fontSize: 12)),
                                      const Divider(height: 20),
                                      // Timeline
                                      Text('Zaman Cizelgesi', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      _timelineRow('Olusturuldu', o['created_at'], df, textPrimary, textMuted),
                                      _timelineRow('Onaylandi', o['confirmed_at'], df, textPrimary, textMuted),
                                      _timelineRow('Hazirlandi', o['prepared_at'], df, textPrimary, textMuted),
                                      _timelineRow('Teslim alindi', o['picked_up_at'], df, textPrimary, textMuted),
                                      _timelineRow('Teslim edildi', o['delivered_at'], df, textPrimary, textMuted),
                                      if (o['cancelled_at'] != null) ...[
                                        _timelineRow('Iptal', o['cancelled_at'], df, AppColors.error, textMuted),
                                        if (o['cancellation_reason'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16),
                                            child: Text('Sebep: ${o['cancellation_reason']}', style: TextStyle(color: AppColors.error, fontSize: 11)),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Messages tab
                                Column(
                                  children: [
                                    Expanded(
                                      child: loadingMessages
                                          ? const Center(child: CircularProgressIndicator())
                                          : messages.isEmpty
                                              ? Center(child: Text('Henuz mesaj yok', style: TextStyle(color: textMuted)))
                                              : ListView.builder(
                                                  padding: const EdgeInsets.all(8),
                                                  itemCount: messages.length,
                                                  itemBuilder: (_, mi) {
                                                    final m = messages[mi];
                                                    final isSupport = m['sender_type'] == 'support' || m['sender_type'] == 'merchant';
                                                    return Align(
                                                      alignment: isSupport ? Alignment.centerRight : Alignment.centerLeft,
                                                      child: Container(
                                                        margin: const EdgeInsets.only(bottom: 6),
                                                        padding: const EdgeInsets.all(10),
                                                        constraints: const BoxConstraints(maxWidth: 350),
                                                        decoration: BoxDecoration(
                                                          color: isSupport ? AppColors.primary.withValues(alpha: 0.1) : (isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9)),
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(m['sender_name'] ?? m['sender_type'] ?? '-', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                                                            const SizedBox(height: 2),
                                                            Text(m['message'] ?? '', style: TextStyle(color: textPrimary, fontSize: 12)),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              DateTime.tryParse(m['created_at'] ?? '') != null
                                                                  ? df.format(DateTime.parse(m['created_at']).toLocal())
                                                                  : '',
                                                              style: TextStyle(color: textMuted, fontSize: 9),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: messageCtrl,
                                              decoration: const InputDecoration(
                                                hintText: 'Mesaj yaz (isletme adina)...',
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                border: OutlineInputBorder(),
                                              ),
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.send, color: AppColors.primary),
                                            onPressed: () async {
                                              if (messageCtrl.text.trim().isEmpty) return;
                                              await ref.read(businessProxyServiceProvider).sendOrderMessage(
                                                    order['id'],
                                                    widget.businessId,
                                                    messageCtrl.text.trim(),
                                                  );
                                              messageCtrl.clear();
                                              final msgs = await ref.read(businessProxyServiceProvider).getOrderMessages(order['id']);
                                              setDialogState(() => messages = msgs);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            actions: [
              if (o['status'] != 'cancelled' && o['status'] != 'delivered') ...[
                TextButton.icon(
                  onPressed: () => _showRejectOrderDialog(ctx, order),
                  icon: const Icon(Icons.cancel, size: 16, color: AppColors.error),
                  label: const Text('Reddet', style: TextStyle(color: AppColors.error)),
                ),
                if (courier == null)
                  TextButton.icon(
                    onPressed: () => _showAssignCourierDialog(ctx, order),
                    icon: const Icon(Icons.delivery_dining, size: 16),
                    label: const Text('Kurye Ata'),
                  ),
              ],
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
            ],
          );
        },
      ),
    );
  }

  void _showRejectOrderDialog(BuildContext parentCtx, Map<String, dynamic> order) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        title: const Text('Siparisi Reddet'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Red sebebi *'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.isEmpty) return;
              await ref.read(businessProxyServiceProvider).rejectOrder(order['id'], reasonCtrl.text, merchantId: widget.businessId);
              if (ctx.mounted) Navigator.pop(ctx);
              if (parentCtx.mounted) Navigator.pop(parentCtx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  void _showAssignCourierDialog(BuildContext parentCtx, Map<String, dynamic> order) {
    showDialog(
      context: parentCtx,
      builder: (ctx) {
        final availableCouriers = _couriers.where((c) => c['is_online'] == true && c['is_busy'] != true).toList();
        return AlertDialog(
          title: const Text('Kurye Ata'),
          content: SizedBox(
            width: 350,
            height: 300,
            child: availableCouriers.isEmpty
                ? const Center(child: Text('Musait kurye yok'))
                : ListView.builder(
                    itemCount: availableCouriers.length,
                    itemBuilder: (_, i) {
                      final c = availableCouriers[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.delivery_dining, size: 20),
                        title: Text(c['full_name'] ?? '-', style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${c['vehicle_type'] ?? '-'} • ${c['vehicle_plate'] ?? '-'}', style: const TextStyle(fontSize: 11)),
                        onTap: () async {
                          await ref.read(businessProxyServiceProvider).assignCourierToOrder(order['id'], c['id'], merchantId: widget.businessId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (parentCtx.mounted) Navigator.pop(parentCtx);
                          _loadData();
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, Color textPrimary, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: textMuted, fontSize: 12))),
          Expanded(child: Text(value, style: TextStyle(color: textPrimary, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _timelineRow(String label, String? dateStr, DateFormat df, Color textPrimary, Color textMuted) {
    final dt = dateStr != null ? DateTime.tryParse(dateStr) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(dt != null ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: dt != null ? AppColors.success : textMuted),
          const SizedBox(width: 6),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: textPrimary, fontSize: 12))),
          Text(dt != null ? df.format(dt.toLocal()) : '-', style: TextStyle(color: textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Menu Tab (CRUD) ───
  // ═══════════════════════════════════════════

  Widget _buildMenuTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showMenuItemDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni Menu Ogesi'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showCategoryManagerDialog('menu'),
                icon: const Icon(Icons.category, size: 16),
                label: const Text('Kategoriler'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _menuItems.isEmpty
              ? Center(child: Text('Menu ogesi yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _menuItems.length,
                  itemBuilder: (ctx, i) {
                    final item = _menuItems[i];
                    final isAvailable = item['is_available'] ?? true;
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        leading: item['image_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(item['image_url'], width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 24)),
                              )
                            : null,
                        title: Text(item['name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('${_currency(item['price'])}${item['discounted_price'] != null ? ' -> ${_currency(item['discounted_price'])}' : ''}', style: TextStyle(color: textMuted, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isAvailable,
                              activeThumbColor: AppColors.success,
                              onChanged: (val) async {
                                final service = ref.read(businessProxyServiceProvider);
                                await service.updateMenuItem(item['id'], {'is_available': val}, merchantId: widget.businessId);
                                _loadData();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () => _showMenuItemDialog(existing: item),
                              tooltip: 'Duzenle',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                              onPressed: () => _showDeleteConfirmDialog(
                                title: 'Menu Ogesini Sil',
                                message: '${item['name']} silinsin mi?',
                                onConfirm: () async {
                                  await ref.read(businessProxyServiceProvider).deleteMenuItem(item['id'], merchantId: widget.businessId);
                                  _loadData();
                                },
                              ),
                              tooltip: 'Sil',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showMenuItemDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(text: existing?['price']?.toString() ?? '');
    final discountCtrl = TextEditingController(text: existing?['discounted_price']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final imageUrlCtrl = TextEditingController(text: existing?['image_url'] ?? '');
    String? selectedCategoryId = existing?['category_id'];
    bool isPopular = existing?['is_popular'] ?? false;
    Uint8List? imageBytes;
    String? imageName;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Menu Ogesi Duzenle' : 'Yeni Menu Ogesi'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Isim *')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Fiyat *'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: discountCtrl, decoration: const InputDecoration(labelText: 'Indirimli Fiyat'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Aciklama'), maxLines: 2),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Kategori Yok')),
                      ..._menuCategories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? '-'))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: imageUrlCtrl, decoration: const InputDecoration(labelText: 'Gorsel URL'))),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await ref.read(storageServiceProvider).pickImage();
                          if (result != null) {
                            setDialogState(() { imageBytes = result.bytes; imageName = result.name; imageUrlCtrl.text = '(yuklenecek: ${result.name})'; });
                          }
                        },
                        icon: const Icon(Icons.upload, size: 16),
                        label: const Text('Yukle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Populer', style: TextStyle(fontSize: 13)),
                    value: isPopular,
                    onChanged: (v) => setDialogState(() => isPopular = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                setDialogState(() => isSaving = true);
                try {
                  String? imageUrl = existing?['image_url'];
                  if (imageBytes != null && imageName != null) {
                    imageUrl = await ref.read(storageServiceProvider).uploadImage('menu_items', imageBytes!, imageName!);
                  } else if (imageUrlCtrl.text.isNotEmpty && !imageUrlCtrl.text.startsWith('(')) {
                    imageUrl = imageUrlCtrl.text;
                  }

                  final data = {
                    'name': nameCtrl.text,
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                    'description': descCtrl.text.isEmpty ? null : descCtrl.text,
                    'category_id': selectedCategoryId,
                    'image_url': imageUrl,
                    'is_popular': isPopular,
                    if (discountCtrl.text.isNotEmpty) 'discounted_price': double.tryParse(discountCtrl.text),
                  };

                  final service = ref.read(businessProxyServiceProvider);
                  if (existing != null) {
                    await service.updateMenuItemFull(existing['id'], data, merchantId: widget.businessId);
                  } else {
                    await service.createMenuItem(widget.businessId, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(existing != null ? 'Guncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Products Tab (Enhanced with filters & bulk) ───
  // ═══════════════════════════════════════════

  Widget _buildProductsTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    // Filter products
    List<Map<String, dynamic>> filtered;
    switch (_productFilter) {
      case 'low_stock':
        filtered = _products.where((p) {
          final stock = (p['stock'] as num?)?.toInt() ?? 0;
          final threshold = (p['low_stock_threshold'] as num?)?.toInt() ?? 5;
          return stock > 0 && stock <= threshold;
        }).toList();
        break;
      case 'out_of_stock':
        filtered = _products.where((p) => ((p['stock'] as num?)?.toInt() ?? 0) == 0).toList();
        break;
      default:
        filtered = _products;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showProductDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni Urun'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showCategoryManagerDialog('product'),
                icon: const Icon(Icons.category, size: 16),
                label: const Text('Kategoriler'),
              ),
              const SizedBox(width: 8),
              if (_bulkEditMode)
                ElevatedButton.icon(
                  onPressed: _saveBulkStock,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Hepsini Kaydet'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _bulkEditMode = true;
                      _bulkStockControllers.clear();
                      for (final p in _products) {
                        _bulkStockControllers[p['id']] = TextEditingController(text: '${(p['stock'] as num?)?.toInt() ?? 0}');
                      }
                    });
                  },
                  icon: const Icon(Icons.inventory, size: 16),
                  label: const Text('Toplu Guncelle'),
                ),
              if (_bulkEditMode) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _bulkEditMode = false;
                    _bulkStockControllers.clear();
                  }),
                  child: const Text('Vazgec'),
                ),
              ],
            ],
          ),
        ),
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildProductFilterChip('Tumu', 'all', _products.length),
              const SizedBox(width: 8),
              _buildProductFilterChip('Dusuk Stok', 'low_stock', _products.where((p) {
                final stock = (p['stock'] as num?)?.toInt() ?? 0;
                final threshold = (p['low_stock_threshold'] as num?)?.toInt() ?? 5;
                return stock > 0 && stock <= threshold;
              }).length),
              const SizedBox(width: 8),
              _buildProductFilterChip('Stok Bitmis', 'out_of_stock', _products.where((p) => ((p['stock'] as num?)?.toInt() ?? 0) == 0).length),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Urun yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final stock = (p['stock'] as num?)?.toInt() ?? 0;
                    final threshold = (p['low_stock_threshold'] as num?)?.toInt() ?? 5;
                    final isLowStock = stock > 0 && stock <= threshold;
                    final isOutOfStock = stock == 0;

                    Color itemCardColor = cardColor;
                    if (isOutOfStock) {
                      itemCardColor = AppColors.error.withValues(alpha: isDark ? 0.1 : 0.05);
                    } else if (isLowStock) {
                      itemCardColor = AppColors.warning.withValues(alpha: isDark ? 0.1 : 0.05);
                    }

                    return Card(
                      color: itemCardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        leading: p['image_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(p['image_url'], width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 24)),
                              )
                            : null,
                        title: Text(p['name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('${_currency(p['price'])} ${isOutOfStock ? '• STOK BITMIS' : isLowStock ? '• DUSUK STOK' : '• Stok: $stock'}', style: TextStyle(color: isOutOfStock ? AppColors.error : isLowStock ? AppColors.warning : textMuted, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 32,
                              child: TextField(
                                controller: _bulkEditMode
                                    ? _bulkStockControllers[p['id']]
                                    : TextEditingController(text: '$stock'),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: const OutlineInputBorder(),
                                  labelText: 'Stok',
                                  labelStyle: const TextStyle(fontSize: 10),
                                  fillColor: _bulkEditMode ? AppColors.primary.withValues(alpha: 0.05) : null,
                                  filled: _bulkEditMode,
                                ),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                onSubmitted: _bulkEditMode ? null : (val) async {
                                  final newStock = int.tryParse(val);
                                  if (newStock != null) {
                                    await ref.read(businessProxyServiceProvider).updateProductStock(p['id'], newStock, merchantId: widget.businessId);
                                    _loadData();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () => _showProductDialog(existing: p),
                              tooltip: 'Duzenle',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                              onPressed: () => _showDeleteConfirmDialog(
                                title: 'Urunu Sil',
                                message: '${p['name']} silinsin mi?',
                                onConfirm: () async {
                                  await ref.read(businessProxyServiceProvider).deleteProduct(p['id'], merchantId: widget.businessId);
                                  _loadData();
                                },
                              ),
                              tooltip: 'Sil',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductFilterChip(String label, String value, int count) {
    final isSelected = _productFilter == value;
    return ChoiceChip(
      label: Text('$label ($count)', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: value == 'out_of_stock' ? AppColors.error : value == 'low_stock' ? AppColors.warning : AppColors.primary,
      onSelected: (_) => setState(() => _productFilter = value),
    );
  }

  Future<void> _saveBulkStock() async {
    final updates = <Map<String, dynamic>>[];
    for (final entry in _bulkStockControllers.entries) {
      final newStock = int.tryParse(entry.value.text);
      if (newStock != null) {
        updates.add({'id': entry.key, 'stock': newStock});
      }
    }
    if (updates.isEmpty) return;
    await ref.read(businessProxyServiceProvider).bulkUpdateStock(updates, merchantId: widget.businessId);
    setState(() {
      _bulkEditMode = false;
      _bulkStockControllers.clear();
    });
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updates.length} urunun stoku guncellendi'), backgroundColor: AppColors.success));
    }
  }

  void _showProductDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(text: existing?['price']?.toString() ?? '');
    final origPriceCtrl = TextEditingController(text: existing?['original_price']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final skuCtrl = TextEditingController(text: existing?['sku'] ?? '');
    final barcodeCtrl = TextEditingController(text: existing?['barcode'] ?? '');
    final brandCtrl = TextEditingController(text: existing?['brand'] ?? '');
    final stockCtrl = TextEditingController(text: existing?['stock']?.toString() ?? '0');
    final lowStockCtrl = TextEditingController(text: existing?['low_stock_threshold']?.toString() ?? '5');
    final imageUrlCtrl = TextEditingController(text: existing?['image_url'] ?? '');
    String? selectedCategoryId = existing?['category_id'];
    bool isFeatured = existing?['is_featured'] ?? false;
    Uint8List? imageBytes;
    String? imageName;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Urun Duzenle' : 'Yeni Urun'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Isim *')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Marka'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Barkod'))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Aciklama'), maxLines: 2),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Kategori Yok')),
                      ..._productCategories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? '-'))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Fiyat *'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: origPriceCtrl, decoration: const InputDecoration(labelText: 'Orijinal Fiyat'), keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stok'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: lowStockCtrl, decoration: const InputDecoration(labelText: 'Dusuk Stok Esigi'), keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: imageUrlCtrl, decoration: const InputDecoration(labelText: 'Gorsel URL'))),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await ref.read(storageServiceProvider).pickImage();
                        if (result != null) {
                          setDialogState(() { imageBytes = result.bytes; imageName = result.name; imageUrlCtrl.text = '(yuklenecek: ${result.name})'; });
                        }
                      },
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text('Yukle'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('One Cikan', style: TextStyle(fontSize: 13)),
                    value: isFeatured,
                    onChanged: (v) => setDialogState(() => isFeatured = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                setDialogState(() => isSaving = true);
                try {
                  String? imageUrl = existing?['image_url'];
                  if (imageBytes != null && imageName != null) {
                    imageUrl = await ref.read(storageServiceProvider).uploadImage('products', imageBytes!, imageName!);
                  } else if (imageUrlCtrl.text.isNotEmpty && !imageUrlCtrl.text.startsWith('(')) {
                    imageUrl = imageUrlCtrl.text;
                  }

                  final data = {
                    'name': nameCtrl.text,
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                    'description': descCtrl.text.isEmpty ? null : descCtrl.text,
                    'category_id': selectedCategoryId,
                    'image_url': imageUrl,
                    'is_featured': isFeatured,
                    'stock': int.tryParse(stockCtrl.text) ?? 0,
                    'low_stock_threshold': int.tryParse(lowStockCtrl.text) ?? 5,
                    if (origPriceCtrl.text.isNotEmpty) 'original_price': double.tryParse(origPriceCtrl.text),
                    if (skuCtrl.text.isNotEmpty) 'sku': skuCtrl.text,
                    if (barcodeCtrl.text.isNotEmpty) 'barcode': barcodeCtrl.text,
                    if (brandCtrl.text.isNotEmpty) 'brand': brandCtrl.text,
                  };

                  final service = ref.read(businessProxyServiceProvider);
                  if (existing != null) {
                    await service.updateProductFull(existing['id'], data, merchantId: widget.businessId);
                  } else {
                    await service.createProduct(widget.businessId, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(existing != null ? 'Guncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Reviews Tab ───
  // ═══════════════════════════════════════════

  Widget _buildReviewsTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildFilterChip('Tumu', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Yanitlanmamis', 'unreplied'),
              const SizedBox(width: 8),
              _buildFilterChip('Yanitlanmis', 'replied'),
            ],
          ),
        ),
        Expanded(
          child: _reviews.isEmpty
              ? Center(child: Text('Degerlendirme yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _reviews.length,
                  itemBuilder: (ctx, i) {
                    final r = _reviews[i];
                    final rating = r['rating'] ?? 0;
                    final hasReply = r['merchant_reply'] != null;
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ...List.generate(5, (j) => Icon(j < rating ? Icons.star : Icons.star_border, color: AppColors.warning, size: 16)),
                                const SizedBox(width: 8),
                                Text(r['customer_name'] ?? 'Anonim', style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                                const Spacer(),
                                if (!hasReply)
                                  TextButton.icon(
                                    onPressed: () => _showReplyDialog(r),
                                    icon: const Icon(Icons.reply, size: 14),
                                    label: const Text('Yanitla', style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                            if (r['comment'] != null) ...[
                              const SizedBox(height: 4),
                              Text(r['comment'], style: TextStyle(color: textMuted, fontSize: 12)),
                            ],
                            if (hasReply) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.store, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(r['merchant_reply'], style: TextStyle(color: textPrimary, fontSize: 12, fontStyle: FontStyle.italic))),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _reviewFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      onSelected: (_) async {
        setState(() => _reviewFilter = value);
        final service = ref.read(businessProxyServiceProvider);
        final reviews = await service.getMerchantReviews(widget.businessId, statusFilter: value == 'all' ? null : value);
        setState(() => _reviews = reviews);
      },
    );
  }

  void _showReplyDialog(Map<String, dynamic> review) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yanitla'),
        content: TextField(controller: replyCtrl, decoration: const InputDecoration(labelText: 'Yanitiniz'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () async {
              if (replyCtrl.text.isEmpty) return;
              await ref.read(businessProxyServiceProvider).replyToReview(review['id'], replyCtrl.text, merchantId: widget.businessId);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Gonder'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Finance Tab (NEW) ───
  // ═══════════════════════════════════════════

  Widget _buildFinanceTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [
              _buildPeriodChip('Bu Hafta', 'week'),
              const SizedBox(width: 8),
              _buildPeriodChip('Bu Ay', 'month'),
              const SizedBox(width: 8),
              _buildPeriodChip('Son 3 Ay', '3months'),
              const SizedBox(width: 8),
              _buildPeriodChip('Bu Yil', 'year'),
            ],
          ),
          const SizedBox(height: 16),
          if (_financeLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_financeData != null) ...[
            // Summary cards
            Row(
              children: [
                Expanded(child: _buildFinanceCard('Toplam Gelir', _currency(_financeData!['total_revenue']), AppColors.success, cardColor, borderColor, textPrimary, textMuted)),
                const SizedBox(width: 12),
                Expanded(child: _buildFinanceCard('Komisyon', _currency(_financeData!['total_commission']), AppColors.warning, cardColor, borderColor, textPrimary, textMuted)),
                const SizedBox(width: 12),
                Expanded(child: _buildFinanceCard('Net Gelir', _currency(_financeData!['net_revenue']), AppColors.primary, cardColor, borderColor, textPrimary, textMuted)),
              ],
            ),
            const SizedBox(height: 16),
            // Payment breakdown + order stats
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Odeme Dagilimi', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 12),
                          _detailRow('Kart', _currency(_financeData!['card_revenue']), textPrimary, textMuted),
                          _detailRow('Nakit', _currency(_financeData!['cash_revenue']), textPrimary, textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Siparis Istatistikleri', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 12),
                          _detailRow('Tamamlanan', '${_financeData!['completed_orders']}', textPrimary, textMuted),
                          _detailRow('Iptal', '${_financeData!['cancelled_orders']}', AppColors.error, textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Transactions list
            Text('Son Islemler', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...(_financeData!['transactions'] as List<dynamic>).take(20).map((t) {
              final tx = t as Map<String, dynamic>;
              final createdAt = DateTime.tryParse(tx['created_at'] ?? '');
              final isCancelled = tx['status'] == 'cancelled';
              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: borderColor)),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isCancelled ? Icons.cancel : Icons.receipt_long,
                    size: 18,
                    color: isCancelled ? AppColors.error : AppColors.success,
                  ),
                  title: Text(
                    '#${tx['order_number'] ?? tx['id'].toString().substring(0, 8)}',
                    style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500, decoration: isCancelled ? TextDecoration.lineThrough : null),
                  ),
                  subtitle: Text(createdAt != null ? df.format(createdAt.toLocal()) : '', style: TextStyle(color: textMuted, fontSize: 10)),
                  trailing: Text(
                    _currency(tx['total_amount']),
                    style: TextStyle(color: isCancelled ? AppColors.error : textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _financePeriod == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      onSelected: (_) {
        setState(() => _financePeriod = value);
        _loadFinance();
      },
    );
  }

  Widget _buildFinanceCard(String title, String value, Color accentColor, Color cardColor, Color borderColor, Color textPrimary, Color textMuted) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: textMuted, fontSize: 11)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Couriers Tab (NEW) ───
  // ═══════════════════════════════════════════

  Widget _buildCouriersTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    final onlineCount = _couriers.where((c) => c['is_online'] == true).length;
    final busyCount = _couriers.where((c) => c['is_busy'] == true).length;

    return Column(
      children: [
        // Summary bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildCourierStat('Toplam', '${_couriers.length}', AppColors.primary, cardColor, borderColor, textPrimary, textMuted),
              const SizedBox(width: 8),
              _buildCourierStat('Online', '$onlineCount', AppColors.success, cardColor, borderColor, textPrimary, textMuted),
              const SizedBox(width: 8),
              _buildCourierStat('Mesgul', '$busyCount', AppColors.warning, cardColor, borderColor, textPrimary, textMuted),
            ],
          ),
        ),
        Expanded(
          child: _couriers.isEmpty
              ? Center(child: Text('Bu isletmeye atanmis kurye yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _couriers.length,
                  itemBuilder: (ctx, i) {
                    final c = _couriers[i];
                    final isOnline = c['is_online'] == true;
                    final isBusy = c['is_busy'] == true;
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isOnline ? AppColors.success.withValues(alpha: 0.15) : (isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9)),
                          child: Icon(Icons.delivery_dining, size: 18, color: isOnline ? AppColors.success : textMuted),
                        ),
                        title: Text(c['full_name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          '${c['vehicle_type'] ?? '-'} • ${c['vehicle_plate'] ?? '-'} • ${c['total_deliveries'] ?? 0} teslimat',
                          style: TextStyle(color: textMuted, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c['rating'] != null) ...[
                              const Icon(Icons.star, size: 14, color: AppColors.warning),
                              const SizedBox(width: 2),
                              Text('${(c['rating'] as num).toStringAsFixed(1)}', style: TextStyle(color: textMuted, fontSize: 11)),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isBusy
                                    ? AppColors.warning.withValues(alpha: 0.15)
                                    : isOnline
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : (isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isBusy ? 'Mesgul' : isOnline ? 'Musait' : 'Offline',
                                style: TextStyle(
                                  color: isBusy ? AppColors.warning : isOnline ? AppColors.success : textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCourierStat(String label, String value, Color color, Color cardColor, Color borderColor, Color textPrimary, Color textMuted) {
    return Expanded(
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: textMuted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Settings Tab (Enhanced) ───
  // ═══════════════════════════════════════════

  Widget _buildSettingsTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final days = ['Pazar', 'Pazartesi', 'Sali', 'Carsamba', 'Persembe', 'Cuma', 'Cumartesi'];

    final settings = _merchantSettings ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Open/Close toggle - prominent
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
            child: SwitchListTile(
              title: Text('Isletme Durumu', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text((widget.data['is_open'] ?? false) ? 'ACIK' : 'KAPALI',
                  style: TextStyle(color: (widget.data['is_open'] ?? false) ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
              value: widget.data['is_open'] ?? false,
              activeThumbColor: AppColors.success,
              onChanged: (val) async {
                await ref.read(businessProxyServiceProvider).toggleMerchantOpen(widget.businessId, val);
                setState(() => widget.data['is_open'] = val);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Business info (editable)
          _buildEditableBusinessInfo(cardColor, borderColor, textPrimary, textMuted),
          const SizedBox(height: 16),

          // Delivery settings
          _buildDeliverySettings(settings, cardColor, borderColor, textPrimary, textMuted),
          const SizedBox(height: 16),

          // Notification preferences
          _buildNotificationSettings(settings, cardColor, borderColor, textPrimary, textMuted),
          const SizedBox(height: 16),

          // Working hours
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Calisma Saatleri', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showWorkingHoursDialog,
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Duzenle', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(7, (dayIdx) {
                    final wh = _workingHours.where((h) => h['day_of_week'] == dayIdx).toList();
                    final isOpen = wh.isNotEmpty && (wh.first['is_open'] ?? false);
                    final open = wh.isNotEmpty ? wh.first['open_time'] ?? '-' : '-';
                    final close = wh.isNotEmpty ? wh.first['close_time'] ?? '-' : '-';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 100, child: Text(days[dayIdx], style: TextStyle(color: textPrimary, fontSize: 13))),
                          if (isOpen)
                            Text('$open - $close', style: TextStyle(color: textMuted, fontSize: 13))
                          else
                            Text('Kapali', style: TextStyle(color: AppColors.error, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableBusinessInfo(Color cardColor, Color borderColor, Color textPrimary, Color textMuted) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Isletme Bilgileri', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showEditBusinessInfoDialog(),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Duzenle', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Isletme Adi', widget.data['business_name'] ?? '-', textPrimary, textMuted),
            _infoRow('Tip', widget.data['business_type'] ?? widget.data['type'] ?? '-', textPrimary, textMuted),
            _infoRow('Telefon', widget.data['phone'] ?? '-', textPrimary, textMuted),
            _infoRow('Email', widget.data['email'] ?? '-', textPrimary, textMuted),
            _infoRow('Adres', widget.data['address'] ?? '-', textPrimary, textMuted),
            if (widget.data['description'] != null)
              _infoRow('Aciklama', widget.data['description'], textPrimary, textMuted),
          ],
        ),
      ),
    );
  }

  void _showEditBusinessInfoDialog() {
    final nameCtrl = TextEditingController(text: widget.data['business_name'] ?? '');
    final phoneCtrl = TextEditingController(text: widget.data['phone'] ?? '');
    final emailCtrl = TextEditingController(text: widget.data['email'] ?? '');
    final addressCtrl = TextEditingController(text: widget.data['address'] ?? '');
    final descCtrl = TextEditingController(text: widget.data['description'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Isletme Bilgilerini Duzenle'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Isletme Adi')),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon')),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Adres'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Aciklama'), maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                try {
                  final data = <String, dynamic>{};
                  if (nameCtrl.text.isNotEmpty) data['business_name'] = nameCtrl.text;
                  if (phoneCtrl.text.isNotEmpty) data['phone'] = phoneCtrl.text;
                  if (emailCtrl.text.isNotEmpty) data['email'] = emailCtrl.text;
                  if (addressCtrl.text.isNotEmpty) data['address'] = addressCtrl.text;
                  data['description'] = descCtrl.text.isEmpty ? null : descCtrl.text;

                  await ref.read(businessProxyServiceProvider).updateMerchantInfo(widget.businessId, data);
                  setState(() {
                    if (data.containsKey('business_name')) widget.data['business_name'] = data['business_name'];
                    if (data.containsKey('phone')) widget.data['phone'] = data['phone'];
                    if (data.containsKey('email')) widget.data['email'] = data['email'];
                    if (data.containsKey('address')) widget.data['address'] = data['address'];
                    widget.data['description'] = data['description'];
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySettings(Map<String, dynamic> settings, Color cardColor, Color borderColor, Color textPrimary, Color textMuted) {
    final deliveryEnabled = settings['delivery_enabled'] ?? true;
    final pickupEnabled = settings['pickup_enabled'] ?? true;

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Teslimat Ayarlari', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showEditDeliverySettingsDialog(settings),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Duzenle', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Teslimat', deliveryEnabled ? 'Acik' : 'Kapali', textPrimary, textMuted),
            _infoRow('Gel-Al', pickupEnabled ? 'Acik' : 'Kapali', textPrimary, textMuted),
            _infoRow('Min Siparis', _currency(settings['min_order_amount'] ?? 50), textPrimary, textMuted),
            _infoRow('Teslimat Ucreti', _currency(settings['delivery_fee'] ?? 15), textPrimary, textMuted),
            _infoRow('Ucretsiz Esik', _currency(settings['free_delivery_threshold'] ?? 150), textPrimary, textMuted),
            _infoRow('Hazirlama', '${settings['min_preparation_time'] ?? 20}-${settings['max_preparation_time'] ?? 45} dk', textPrimary, textMuted),
          ],
        ),
      ),
    );
  }

  void _showEditDeliverySettingsDialog(Map<String, dynamic> settings) {
    bool deliveryEnabled = settings['delivery_enabled'] ?? true;
    bool pickupEnabled = settings['pickup_enabled'] ?? true;
    final minOrderCtrl = TextEditingController(text: '${(settings['min_order_amount'] as num?)?.toInt() ?? 50}');
    final deliveryFeeCtrl = TextEditingController(text: '${(settings['delivery_fee'] as num?)?.toInt() ?? 15}');
    final freeThresholdCtrl = TextEditingController(text: '${(settings['free_delivery_threshold'] as num?)?.toInt() ?? 150}');
    final minPrepCtrl = TextEditingController(text: '${settings['min_preparation_time'] ?? 20}');
    final maxPrepCtrl = TextEditingController(text: '${settings['max_preparation_time'] ?? 45}');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Teslimat Ayarlari'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Teslimat', style: TextStyle(fontSize: 13)),
                    value: deliveryEnabled,
                    onChanged: (v) => setDialogState(() => deliveryEnabled = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Gel-Al', style: TextStyle(fontSize: 13)),
                    value: pickupEnabled,
                    onChanged: (v) => setDialogState(() => pickupEnabled = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: minOrderCtrl, decoration: const InputDecoration(labelText: 'Min Siparis Tutari'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: deliveryFeeCtrl, decoration: const InputDecoration(labelText: 'Teslimat Ucreti'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: freeThresholdCtrl, decoration: const InputDecoration(labelText: 'Ucretsiz Teslimat Esigi'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: minPrepCtrl, decoration: const InputDecoration(labelText: 'Min Hazirlama (dk)'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: maxPrepCtrl, decoration: const InputDecoration(labelText: 'Max Hazirlama (dk)'), keyboardType: TextInputType.number)),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                try {
                  final data = {
                    'delivery_enabled': deliveryEnabled,
                    'pickup_enabled': pickupEnabled,
                    'min_order_amount': double.tryParse(minOrderCtrl.text) ?? 50,
                    'delivery_fee': double.tryParse(deliveryFeeCtrl.text) ?? 15,
                    'free_delivery_threshold': double.tryParse(freeThresholdCtrl.text) ?? 150,
                    'min_preparation_time': int.tryParse(minPrepCtrl.text) ?? 20,
                    'max_preparation_time': int.tryParse(maxPrepCtrl.text) ?? 45,
                  };
                  await ref.read(businessProxyServiceProvider).updateMerchantSettings(widget.businessId, data);
                  setState(() => _merchantSettings = {...?_merchantSettings, ...data});
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings(Map<String, dynamic> settings, Color cardColor, Color borderColor, Color textPrimary, Color textMuted) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bildirim Tercihleri', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _notifToggle('Yeni siparis', 'notify_new_order', settings['notify_new_order'] ?? true, textPrimary),
            _notifToggle('Siparis iptali', 'notify_order_cancel', settings['notify_order_cancel'] ?? true, textPrimary),
            _notifToggle('Bildirim sesi', 'notify_sound_enabled', settings['notify_sound_enabled'] ?? true, textPrimary),
            _notifToggle('Yeni degerlendirme', 'notify_new_review', settings['notify_new_review'] ?? true, textPrimary),
            _notifToggle('Dusuk stok', 'notify_low_stock', settings['notify_low_stock'] ?? true, textPrimary),
            _notifToggle('Haftalik rapor', 'notify_weekly_report', settings['notify_weekly_report'] ?? false, textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _notifToggle(String label, String field, bool value, Color textPrimary) {
    return SwitchListTile(
      title: Text(label, style: TextStyle(color: textPrimary, fontSize: 13)),
      value: value,
      onChanged: (v) async {
        await ref.read(businessProxyServiceProvider).updateMerchantSettings(widget.businessId, {field: v});
        setState(() {
          _merchantSettings = {...?_merchantSettings, field: v};
        });
      },
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _infoRow(String label, String value, Color textPrimary, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: textMuted, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: textPrimary, fontSize: 13))),
        ],
      ),
    );
  }

  void _showWorkingHoursDialog() {
    final days = ['Pazar', 'Pazartesi', 'Sali', 'Carsamba', 'Persembe', 'Cuma', 'Cumartesi'];
    final hours = List.generate(7, (i) {
      final existing = _workingHours.where((h) => h['day_of_week'] == i).toList();
      return {
        'day_of_week': i,
        'is_open': existing.isNotEmpty ? (existing.first['is_open'] ?? false) : false,
        'open_time': existing.isNotEmpty ? (existing.first['open_time'] ?? '09:00') : '09:00',
        'close_time': existing.isNotEmpty ? (existing.first['close_time'] ?? '22:00') : '22:00',
      };
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Calisma Saatleri'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 90, child: Text(days[i], style: const TextStyle(fontSize: 13))),
                      Switch(
                        value: hours[i]['is_open'] as bool,
                        onChanged: (v) => setDialogState(() => hours[i]['is_open'] = v),
                      ),
                      if (hours[i]['is_open'] as bool) ...[
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: TextEditingController(text: hours[i]['open_time'] as String),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (v) => hours[i]['open_time'] = v,
                          ),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('-')),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: TextEditingController(text: hours[i]['close_time'] as String),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (v) => hours[i]['close_time'] = v,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
            ElevatedButton(
              onPressed: () async {
                await ref.read(businessProxyServiceProvider).updateMerchantWorkingHours(widget.businessId, hours);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Shared: Category Manager Dialog ───
  // ═══════════════════════════════════════════

  void _showCategoryManagerDialog(String type) {
    final categories = type == 'menu' ? _menuCategories : _productCategories;
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(type == 'menu' ? 'Menu Kategorileri' : 'Urun Kategorileri'),
          content: SizedBox(
            width: 400,
            height: 350,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Yeni kategori adi', isDense: true))),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppColors.primary),
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) return;
                        final service = ref.read(businessProxyServiceProvider);
                        if (type == 'menu') {
                          await service.createMenuCategory(widget.businessId, nameCtrl.text);
                        } else {
                          await service.createProductCategory(widget.businessId, nameCtrl.text);
                        }
                        nameCtrl.clear();
                        await _loadData();
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (ctx, i) {
                      final cat = categories[i];
                      return ListTile(
                        dense: true,
                        title: Text(cat['name'] ?? '-', style: const TextStyle(fontSize: 13)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () {
                                final editCtrl = TextEditingController(text: cat['name']);
                                showDialog(
                                  context: ctx,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Kategori Duzenle'),
                                    content: TextField(controller: editCtrl),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Iptal')),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final service = ref.read(businessProxyServiceProvider);
                                          if (type == 'menu') {
                                            await service.updateMenuCategory(cat['id'], editCtrl.text, merchantId: widget.businessId);
                                          } else {
                                            await service.updateProductCategory(cat['id'], editCtrl.text, merchantId: widget.businessId);
                                          }
                                          if (c.mounted) Navigator.pop(c);
                                          await _loadData();
                                          setDialogState(() {});
                                        },
                                        child: const Text('Kaydet'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                              onPressed: () async {
                                final service = ref.read(businessProxyServiceProvider);
                                if (type == 'menu') {
                                  await service.deleteMenuCategory(cat['id'], merchantId: widget.businessId);
                                } else {
                                  await service.deleteProductCategory(cat['id'], merchantId: widget.businessId);
                                }
                                await _loadData();
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Shared: Delete Confirm Dialog ───
  // ═══════════════════════════════════════════

  void _showDeleteConfirmDialog({required String title, required String message, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Helpers ───
  // ═══════════════════════════════════════════

  String _currency(dynamic amount) {
    if (amount == null) return '₺0';
    final num val = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
    if (val == val.toInt()) return '₺${val.toInt()}';
    return '₺${val.toStringAsFixed(2)}';
  }

  String _paymentMethodLabel(String? method) {
    switch (method) {
      case 'cash': return 'Nakit';
      case 'card': return 'Kart';
      case 'eft': case 'transfer': return 'EFT/Havale';
      default: return method ?? '-';
    }
  }
}
