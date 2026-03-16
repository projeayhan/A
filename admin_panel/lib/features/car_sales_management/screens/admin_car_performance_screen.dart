import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/car_sales_management_providers.dart';

class AdminCarPerformanceScreen extends ConsumerStatefulWidget {
  final String dealerId;
  final String? dealerName;

  const AdminCarPerformanceScreen({
    super.key,
    required this.dealerId,
    this.dealerName,
  });

  @override
  ConsumerState<AdminCarPerformanceScreen> createState() => _AdminCarPerformanceScreenState();
}

class _AdminCarPerformanceScreenState extends ConsumerState<AdminCarPerformanceScreen> {
  String _selectedPeriod = 'this_month';
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
  final _numberFormat = NumberFormat('#,###', 'tr_TR');

  final List<Map<String, String>> _periods = [
    {'key': 'this_week', 'label': 'Bu Hafta'},
    {'key': 'this_month', 'label': 'Bu Ay'},
    {'key': 'last_3_months', 'label': 'Son 3 Ay'},
    {'key': 'this_year', 'label': 'Bu Yıl'},
  ];

  @override
  Widget build(BuildContext context) {
    final params = (dealerId: widget.dealerId, period: _selectedPeriod);
    final performanceAsync = ref.watch(dealerPerformanceProvider(params));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: performanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Hata: $e', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(dealerPerformanceProvider(params)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (data) => _buildContent(data),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final topListings = List<Map<String, dynamic>>.from(data['top_listings'] ?? []);
    final allListings = List<Map<String, dynamic>>.from(data['listings'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    tooltip: 'Geri',
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.dealerName != null
                            ? '${widget.dealerName} - Performans'
                            : 'Galeri Performans',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Galeri ilan ve etkileşim istatistikleri',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      final params = (dealerId: widget.dealerId, period: _selectedPeriod);
                      ref.invalidate(dealerPerformanceProvider(params));
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Yenile'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Summary Cards - Row 1
          Row(
            children: [
              _buildSummaryCard(
                'Toplam İlan',
                '${data['total_listings'] ?? 0}',
                Icons.directions_car,
                AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Aktif',
                '${data['active_count'] ?? 0}',
                Icons.check_circle,
                AppColors.success,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Satılan',
                '${data['sold_count'] ?? 0}',
                Icons.sell,
                AppColors.info,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Beklemede',
                '${data['pending_count'] ?? 0}',
                Icons.pending,
                AppColors.warning,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Summary Cards - Row 2
          Row(
            children: [
              _buildSummaryCard(
                'Görüntülenme',
                _numberFormat.format(data['total_views'] ?? 0),
                Icons.visibility,
                AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Favori',
                _numberFormat.format(data['total_favorites'] ?? 0),
                Icons.favorite,
                AppColors.error,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'İletişim',
                _numberFormat.format(data['total_contacts'] ?? 0),
                Icons.phone,
                AppColors.success,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Ort. Satış Süresi',
                '${data['avg_sell_days'] ?? 0} gün',
                Icons.timer,
                AppColors.warning,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Bar Chart - Top 10 by views
          if (topListings.isNotEmpty) ...[
            _buildChartCard(
              'En Çok Görüntülenen İlanlar',
              'Görüntülenme sayısına göre ilk 10',
              _buildTopListingsBarChart(topListings),
            ),
            const SizedBox(height: 32),
          ],

          // Performance Table
          _buildPerformanceTable(allListings),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final currentLabel = _periods.firstWhere(
      (p) => p['key'] == _selectedPeriod,
      orElse: () => _periods[1],
    )['label']!;

    return PopupMenuButton<String>(
      onSelected: (period) {
        setState(() => _selectedPeriod = period);
      },
      itemBuilder: (context) => _periods.map((p) {
        return PopupMenuItem(
          value: p['key'],
          child: Text(p['label']!),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              currentLabel,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
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
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, String subtitle, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          chart,
        ],
      ),
    );
  }

  Widget _buildTopListingsBarChart(List<Map<String, dynamic>> topListings) {
    if (topListings.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    final maxViews = topListings
        .map((l) => ((l['view_count'] as num?) ?? 0).toDouble())
        .reduce((a, b) => a > b ? a : b);
    final chartMax = maxViews > 0 ? (maxViews * 1.2).ceilToDouble() : 100.0;

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMax,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (groupIndex < topListings.length) {
                  final listing = topListings[groupIndex];
                  final brand = listing['brand_name'] ?? '';
                  final model = listing['model_name'] ?? '';
                  final year = listing['year']?.toString() ?? '';
                  return BarTooltipItem(
                    '$brand $model $year\n${rod.toY.toInt()} görüntülenme',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }
                return null;
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : '${value.toInt()}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < topListings.length) {
                    final brand = (topListings[index]['brand_name'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        brand.length > 8 ? '${brand.substring(0, 8)}.' : brand,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMax > 0 ? chartMax / 5 : 20,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: topListings.asMap().entries.map((entry) {
            final views = ((entry.value['view_count'] as num?) ?? 0).toDouble();
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: views,
                  color: AppColors.primary,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPerformanceTable(List<Map<String, dynamic>> listings) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performans Tablosu',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tüm ilanların detaylı performans verileri',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('İLAN', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('FİYAT', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('GÖRÜNTÜLENME', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('FAVORİ', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('İLETİŞİM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('DURUM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('ŞEHİR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (listings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Henüz ilan yok', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ...listings.map((listing) => _buildPerformanceRow(listing)),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(Map<String, dynamic> listing) {
    final brand = listing['brand_name'] ?? '';
    final model = listing['model_name'] ?? '';
    final year = listing['year']?.toString() ?? '';
    final title = listing['title'] ?? '$brand $model $year';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$brand $model $year',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              listing['price'] != null ? _currencyFormat.format(listing['price']) : '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.visibility, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  _numberFormat.format(listing['view_count'] ?? 0),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.favorite, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  _numberFormat.format(listing['favorite_count'] ?? 0),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.phone, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  _numberFormat.format(listing['contact_count'] ?? 0),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(child: _buildStatusBadge(listing['status'] ?? 'pending')),
          Expanded(
            child: Text(
              listing['city'] ?? '-',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'active':
        color = AppColors.success;
        text = 'Aktif';
        break;
      case 'pending':
        color = AppColors.warning;
        text = 'Beklemede';
        break;
      case 'sold':
        color = AppColors.info;
        text = 'Satıldı';
        break;
      case 'reserved':
        color = AppColors.primary;
        text = 'Rezerve';
        break;
      case 'expired':
        color = AppColors.textMuted;
        text = 'Süresi Doldu';
        break;
      case 'rejected':
        color = AppColors.error;
        text = 'Reddedildi';
        break;
      default:
        color = AppColors.textMuted;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
