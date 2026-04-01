import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/models/customer_360_model.dart';
import '../../../core/router/app_router.dart';
import 'package:support_panel/core/services/log_service.dart';
import '../../../shared/widgets/status_badge.dart';

class Customer360Screen extends ConsumerStatefulWidget {
  final String customerId;
  const Customer360Screen({super.key, required this.customerId});

  @override
  ConsumerState<Customer360Screen> createState() => _Customer360ScreenState();
}

class _Customer360ScreenState extends ConsumerState<Customer360Screen> with SingleTickerProviderStateMixin {
  Customer360? _data;
  bool _isLoading = true;
  String? _error;
  late TabController _tabCtrl;

  final _tabs = const ['Genel', 'Siparişler', 'Taksi', 'Kiralama', 'Emlak', 'Araç Satış', 'Yorumlar', 'Ticketlar'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final service = ref.read(customerServiceProvider);
      final data = await service.getCustomer360(widget.customerId);
      setState(() { _data = data; _isLoading = false; });
    } catch (e, st) {
      LogService.error('Failed to load customer 360', error: e, stackTrace: st, source: 'Customer360Screen:_load');
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Hata: $_error', style: TextStyle(color: AppColors.error)));
    if (_data == null) return Center(child: Text('Veri bulunamadı', style: TextStyle(color: textMuted)));

    final d = _data!;
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => context.go(AppRoutes.customers)),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  (d.user['full_name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.user['full_name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${d.user['phone'] ?? '-'} • ${d.user['email'] ?? '-'}', style: TextStyle(color: textMuted, fontSize: 13)),
                  ],
                ),
              ),

              // Quick stats
              _buildStatChip('Sipariş', '${d.orderCount}', AppColors.primary, cardColor, borderColor),
              const SizedBox(width: 8),
              _buildStatChip('Harcama', '₺${d.totalSpent.toStringAsFixed(0)}', AppColors.success, cardColor, borderColor),
              const SizedBox(width: 8),
              _buildStatChip('Ticket', '${d.ticketCount}', AppColors.warning, cardColor, borderColor),
            ],
          ),
        ),

        // Tabs
        Container(
          color: cardColor,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: textMuted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildOverviewTab(d, textPrimary, textMuted, cardColor, borderColor, df),
              _buildOrdersTab(d.orders, textPrimary, textMuted, cardColor, borderColor, df),
              _buildTaxiTab(d.taxiRides, textPrimary, textMuted, cardColor, borderColor, df),
              _buildRentalTab(d.rentalBookings, textPrimary, textMuted, cardColor, borderColor, df),
              _buildEmlakTab(d.properties, textPrimary, textMuted, cardColor, borderColor),
              _buildCarSalesTab(d.carListings, textPrimary, textMuted, cardColor, borderColor),
              _buildReviewsTab(d.reviews, textPrimary, textMuted, cardColor, borderColor, df),
              _buildTicketsTab(d.supportTickets, textPrimary, textMuted, cardColor, borderColor, df, context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Customer360 d, Color textPrimary, Color textMuted, Color cardColor, Color borderColor, DateFormat df) {
    final p = d.user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard('Profil Bilgileri', [
            _infoRow('Ad Soyad', p['full_name'] ?? '-', textPrimary, textMuted),
            _infoRow('Telefon', p['phone'] ?? '-', textPrimary, textMuted),
            _infoRow('E-posta', p['email'] ?? '-', textPrimary, textMuted),
            _infoRow('Kayıt Tarihi', p['created_at'] != null ? df.format(DateTime.parse(p['created_at']).toLocal()) : '-', textPrimary, textMuted),
          ], cardColor, borderColor, textPrimary),
          const SizedBox(height: 16),
          _buildCard('Özet İstatistikler', [
            _infoRow('Toplam Sipariş', '${d.orderCount}', textPrimary, textMuted),
            _infoRow('Toplam Harcama', '₺${d.totalSpent.toStringAsFixed(2)}', textPrimary, textMuted),
            _infoRow('Taksi Yolculuk', '${d.taxiRides.length}', textPrimary, textMuted),
            _infoRow('Kiralama Rez.', '${d.rentalBookings.length}', textPrimary, textMuted),
            _infoRow('Emlak İlan', '${d.properties.length}', textPrimary, textMuted),
            _infoRow('Araç İlan', '${d.carListings.length}', textPrimary, textMuted),
            _infoRow('Yorum', '${d.reviews.length}', textPrimary, textMuted),
            _infoRow('Destek Ticket', '${d.ticketCount}', textPrimary, textMuted),
          ], cardColor, borderColor, textPrimary),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(List<dynamic> orders, Color textPrimary, Color textMuted, Color cardColor, Color borderColor, DateFormat df) {
    if (orders.isEmpty) return _emptyState('Sipariş bulunamadı', textMuted);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final o = orders[i] as Map<String, dynamic>;
        final createdAt = DateTime.tryParse(o['created_at'] ?? '');
        return _listTile(
          title: '#${o['id'].toString().substring(0, 8)} - ${o['merchant_name'] ?? '-'}',
          subtitle: '${o['status'] ?? '-'} • ₺${o['total_amount'] ?? 0}',
          trailing: createdAt != null ? df.format(createdAt.toLocal()) : '',
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardColor: cardColor,
          borderColor: borderColor,
        );
      },
    );
  }

  Widget _buildTaxiTab(List<dynamic> rides, Color textPrimary, Color textMuted, Color cardColor, Color borderColor, DateFormat df) {
    if (rides.isEmpty) return _emptyState('Taksi yolculuğu bulunamadı', textMuted);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (context, i) {
        final r = rides[i] as Map<String, dynamic>;
        final createdAt = DateTime.tryParse(r['created_at'] ?? '');
        return _listTile(
          title: '${r['pickup_address'] ?? '-'} → ${r['dropoff_address'] ?? '-'}',
          subtitle: '${r['status'] ?? '-'} • ₺${r['fare_amount'] ?? 0}',
          trailing: createdAt != null ? df.format(createdAt.toLocal()) : '',
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardColor: cardColor,
          borderColor: borderColor,
        );
      },
    );
  }

  Widget _buildRentalTab(List<dynamic> bookings, Color textPrimary, Color textMuted, Color cardColor, Color borderColor, DateFormat df) {
    if (bookings.isEmpty) return _emptyState('Kiralama rezervasyonu bulunamadı', textMuted);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, i) {
        final b = bookings[i] as Map<String, dynamic>;
        return _listTile(
          title: '${b['vehicle_name'] ?? '-'}',
          subtitle: '${b['status'] ?? '-'} • ₺${b['total_price'] ?? 0}',
          trailing: '',
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardColor: cardColor,
          borderColor: borderColor,
        );
      },
    );
  }

  Widget _buildEmlakTab(List<dynamic> props, Color textPrimary, Color textMuted, Color cardColor, Color borderColor) {
    if (props.isEmpty) return _emptyState('Emlak ilanı bulunamadı', textMuted);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: props.length,
      itemBuilder: (context, i) {
        final p = props[i] as Map<String, dynamic>;
        return _listTile(
          title: p['title'] ?? '-',
          subtitle: '${p['status'] ?? '-'} • ₺${p['price'] ?? 0}',
          trailing: p['property_type'] ?? '',
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardColor: cardColor,
          borderColor: borderColor,
        );
      },
    );
  }

  Widget _buildCarSalesTab(List<dynamic> listings, Color textPrimary, Color textMuted, Color cardColor, Color borderColor) {
    if (listings.isEmpty) return _emptyState('Araç ilanı bulunamadı', textMuted);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listings.length,
      itemBuilder: (context, i) {
        final c = listings[i] as Map<String, dynamic>;
        return _listTile(
          title: '${c['brand'] ?? ''} ${c['model'] ?? ''} ${c['year'] ?? ''}',
          subtitle: '${c['status'] ?? '-'} • ₺${c['price'] ?? 0}',
          trailing: '',
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardColor: cardColor,
          borderColor: borderColor,
        );
      },
    );
  }

  Widget _buildReviewsTab(List<dynamic> reviews, Color textPrimary, Color textMuted, Color cardColor, Color borderColor, DateFormat df) {
    if (reviews.isEmpty) return _emptyState('Yorum bulunamadı', textMuted);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      itemBuilder: (context, i) {
        final r = reviews[i] as Map<String, dynamic>;
        final createdAt = DateTime.tryParse(r['created_at'] ?? '');
        return _listTile(
          title: '★ ${r['rating'] ?? '-'} - ${r['comment'] ?? 'Yorum yok'}',
          subtitle: r['merchant_name'] ?? '-',
          trailing: createdAt != null ? df.format(createdAt.toLocal()) : '',
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardColor: cardColor,
          borderColor: borderColor,
        );
      },
    );
  }

  Widget _buildTicketsTab(List<dynamic> tickets, Color textPrimary, Color textMuted, Color cardColor, Color borderColor, DateFormat df, BuildContext context) {
    if (tickets.isEmpty) return _emptyState('Destek ticketı bulunamadı', textMuted);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (ctx, i) {
        final t = tickets[i] as Map<String, dynamic>;
        final createdAt = DateTime.tryParse(t['created_at'] ?? '');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => context.go('${AppRoutes.tickets}/${t['id']}'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['subject'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        if (createdAt != null)
                          Text(df.format(createdAt.toLocal()), style: TextStyle(color: textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  StatusBadge.ticketStatus(t['status'] ?? 'open'),
                  const SizedBox(width: 8),
                  StatusBadge.priority(t['priority'] ?? 'normal'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(String title, List<Widget> children, Color cardColor, Color borderColor, Color textPrimary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color textPrimary, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: textMuted, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _listTile({required String title, required String subtitle, required String trailing, required Color textPrimary, required Color textMuted, required Color cardColor, required Color borderColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (trailing.isNotEmpty)
              Text(trailing, style: TextStyle(color: textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message, Color textMuted) {
    return Center(child: Text(message, style: TextStyle(color: textMuted)));
  }
}
