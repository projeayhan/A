import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/promotion_admin_service.dart';
import '../../../core/theme/app_theme.dart';

class PromotionRequestsScreen extends ConsumerStatefulWidget {
  const PromotionRequestsScreen({super.key});

  @override
  ConsumerState<PromotionRequestsScreen> createState() => _PromotionRequestsScreenState();
}

class _PromotionRequestsScreenState extends ConsumerState<PromotionRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _sectorTabController;
  String _statusFilter = 'active';

  final List<_SectorTab> _sectors = const [
    _SectorTab(key: 'carSales', label: 'Araç Satış', icon: Icons.directions_car_rounded),
    _SectorTab(key: 'realEstate', label: 'Emlak', icon: Icons.home_work_rounded),
    _SectorTab(key: 'jobs', label: 'İş İlanları', icon: Icons.work_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _sectorTabController = TabController(length: _sectors.length, vsync: this);
    _sectorTabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sectorTabController.dispose();
    super.dispose();
  }

  String get _currentSector => _sectors[_sectorTabController.index].key;

  // "sector:statusFilter" — Riverpod family key (String has value equality)
  String get _queryKey => '$_currentSector:$_statusFilter';

  void _refresh() {
    ref.invalidate(promotionRequestsProvider(_queryKey));
    ref.invalidate(promotionStatsProvider(null));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF3B9EFF), size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Öne Çıkan İlanlar',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Aktif promosyonlar ve gelir özeti',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                      )),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Yenile',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Stats cards ──────────────────────────────────────────
        ref.watch(promotionStatsProvider(null)).when(
          loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const SizedBox.shrink(),
          data: (stats) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _StatCard(
                  label: 'Aktif İlan',
                  value: stats.totalActive.toString(),
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF3B9EFF),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Premium',
                  value: stats.totalPremium.toString(),
                  icon: Icons.star_rounded,
                  color: const Color(0xFFFFB300),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Bu Hafta Bitiyor',
                  value: stats.expiringSoon.toString(),
                  icon: Icons.timer_rounded,
                  color: Colors.orange,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Toplam Gelir',
                  value: fmt.format(stats.totalRevenue),
                  icon: Icons.payments_rounded,
                  color: Colors.green,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Sector tabs ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _sectorTabController,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? AppColors.textMuted : const Color(0xFF64748B),
            dividerColor: Colors.transparent,
            tabs: _sectors
                .map((s) => Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(s.icon, size: 16),
                          const SizedBox(width: 6),
                          Text(s.label, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),

        const SizedBox(height: 12),

        // ── Status filter chips ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 8,
            children: [
              _filterChip('active', 'Aktif', Icons.check_circle_outline_rounded, isDark),
              _filterChip('expired', 'Sona Erdi', Icons.timer_off_rounded, isDark),
              _filterChip('cancelled', 'İptal', Icons.cancel_outlined, isDark),
              _filterChip('all', 'Tümü', Icons.list_rounded, isDark),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Content ──────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _sectorTabController,
            children: _sectors.map((_) => _buildList()).toList(),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label, IconData icon, bool isDark) {
    final selected = _statusFilter == value;
    return FilterChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label)],
      ),
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : (isDark ? AppColors.textSecondary : const Color(0xFF475569)),
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  Widget _buildList() {
    final asyncData = ref.watch(promotionRequestsProvider(_queryKey));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Yüklenemedi: $e'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_outlined,
                    size: 64,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textMuted
                        : const Color(0xFFCBD5E1)),
                const SizedBox(height: 16),
                const Text('Kayıt bulunamadı',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: _PromotionTable(
            items: items,
            onCancel: _confirmCancel,
          ),
        );
      },
    );
  }

  void _confirmCancel(PromotionRequest req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promosyonu Sonlandır'),
        content: Text('"${req.listingTitle}" için aktif promosyonu erken sonlandırmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await PromotionAdminService.cancelPromotion(req.id, req.sector);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${req.listingTitle}" sonlandırıldı'), backgroundColor: Colors.orange),
                );
                _refresh();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Sonlandır'),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF1E293B),
                    )),
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data table ────────────────────────────────────────────────────────────────

class _PromotionTable extends StatelessWidget {
  final List<PromotionRequest> items;
  final void Function(PromotionRequest) onCancel;

  const _PromotionTable({required this.items, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
    final dateFmt = DateFormat('dd.MM.yy', 'tr_TR');
    final now = DateTime.now();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? AppColors.surfaceLight : const Color(0xFFF8FAFC),
          ),
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('İlan', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Satıcı', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Tür', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Süre', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Ödenen', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Başladı', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Bitiyor', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Durum', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: items.map((req) {
            final expiresAt = req.approvedAt?.add(Duration(days: req.durationDays));
            final daysLeft = expiresAt?.difference(now).inDays;
            final expiringSoon = daysLeft != null && daysLeft >= 0 && daysLeft <= 7;

            return DataRow(cells: [
              DataCell(SizedBox(
                width: 160,
                child: Text(req.listingTitle, overflow: TextOverflow.ellipsis, maxLines: 2,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              )),
              DataCell(SizedBox(
                width: 120,
                child: Text(req.merchantName, overflow: TextOverflow.ellipsis),
              )),
              DataCell(_TypeBadge(type: req.promotionType)),
              DataCell(Text('${req.durationDays} gün')),
              DataCell(Text(fmt.format(req.amount),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green))),
              DataCell(Text(
                req.approvedAt != null ? dateFmt.format(req.approvedAt!) : '-',
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(
                expiresAt != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(dateFmt.format(expiresAt), style: const TextStyle(fontSize: 12)),
                          if (daysLeft != null && daysLeft >= 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: expiringSoon
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$daysLeft g',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: expiringSoon ? Colors.orange : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : const Text('-', style: TextStyle(fontSize: 12)),
              ),
              DataCell(_StatusBadge(status: req.status)),
              DataCell(
                req.status == 'active'
                    ? IconButton(
                        onPressed: () => onCancel(req),
                        icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error, size: 20),
                        tooltip: 'Sonlandır',
                        visualDensity: VisualDensity.compact,
                      )
                    : const SizedBox.shrink(),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isPremium = type == 'premium';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPremium
            ? const Color(0xFFFFB300).withValues(alpha: 0.15)
            : const Color(0xFF3B9EFF).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPremium ? '⭐ Premium' : '⚡ Öne Çıkan',
        style: TextStyle(
          color: isPremium ? const Color(0xFFFFB300) : const Color(0xFF3B9EFF),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'Aktif';
        break;
      case 'cancelled':
        color = Colors.grey;
        label = 'İptal';
        break;
      case 'expired':
        color = Colors.blueGrey;
        label = 'Sona Erdi';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

class _SectorTab {
  final String key;
  final String label;
  final IconData icon;
  const _SectorTab({required this.key, required this.label, required this.icon});
}
