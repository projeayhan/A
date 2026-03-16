import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/rental_management_providers.dart';

class AdminRentalFinanceScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminRentalFinanceScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminRentalFinanceScreen> createState() => _AdminRentalFinanceScreenState();
}

class _AdminRentalFinanceScreenState extends ConsumerState<AdminRentalFinanceScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  final _dateFormat = DateFormat('dd.MM.yyyy');
  String _selectedPeriod = '30';

  @override
  Widget build(BuildContext context) {
    final financeParams = (companyId: widget.companyId, period: _selectedPeriod);
    final financeAsync = ref.watch(rentalCompanyFinanceProvider(financeParams));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finans',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gelir ve komisyon raporları',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(rentalCompanyFinanceProvider(financeParams)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Stats Cards
            financeAsync.when(
              data: (finance) => _buildStatsCards(finance),
              loading: () => _buildStatsCardsLoading(),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),

            const SizedBox(height: 32),

            // Charts Row
            financeAsync.when(
              data: (finance) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildChartCard(
                      'Aylık Gelir',
                      'Gelir trendi',
                      _buildRevenueChart(finance),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildChartCard(
                      'Gelir Dağılımı',
                      'Komisyon vs Net',
                      _buildDistributionChart(finance),
                    ),
                  ),
                ],
              ),
              loading: () => Row(
                children: [
                  Expanded(flex: 2, child: _buildChartCardLoading()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildChartCardLoading()),
                ],
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Recent Bookings Table
            financeAsync.when(
              data: (finance) => _buildRecentBookingsCard(finance),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _selectedPeriod = value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: '7', child: Text('Son 7 Gün')),
        PopupMenuItem(value: '30', child: Text('Bu Ay')),
        PopupMenuItem(value: '90', child: Text('Son 3 Ay')),
        PopupMenuItem(value: '365', child: Text('Bu Yıl')),
      ],
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
              _selectedPeriod == '7' ? 'Son 7 Gün' :
              _selectedPeriod == '30' ? 'Bu Ay' :
              _selectedPeriod == '90' ? 'Son 3 Ay' : 'Bu Yıl',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> finance) {
    final totalRevenue = (finance['total_revenue'] as num?)?.toDouble() ?? 0;
    final commission = (finance['commission'] as num?)?.toDouble() ?? 0;
    final commissionRate = (finance['commission_rate'] as num?)?.toDouble() ?? 0;
    final netRevenue = (finance['net_revenue'] as num?)?.toDouble() ?? 0;
    final completedBookings = finance['completed_bookings'] as int? ?? 0;
    final totalRentalDays = finance['total_rental_days'] as int? ?? 0;
    final avgBookingValue = (finance['avg_booking_value'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        Row(
          children: [
            _buildFinanceCard('Toplam Gelir', _currencyFormat.format(totalRevenue), Icons.trending_up, AppColors.success),
            const SizedBox(width: 24),
            _buildFinanceCard('Komisyon (%${commissionRate.toStringAsFixed(0)})', _currencyFormat.format(commission), Icons.account_balance, AppColors.warning),
            const SizedBox(width: 24),
            _buildFinanceCard('Net Gelir', _currencyFormat.format(netRevenue), Icons.savings, AppColors.primary),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildFinanceCard('Tamamlanan Rez.', completedBookings.toString(), Icons.check_circle, AppColors.success),
            const SizedBox(width: 24),
            _buildFinanceCard('Toplam Kiralama Günü', totalRentalDays.toString(), Icons.calendar_month, AppColors.info),
            const SizedBox(width: 24),
            _buildFinanceCard('Ort. Rez. Tutarı', _currencyFormat.format(avgBookingValue), Icons.analytics, AppColors.primaryLight),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCardsLoading() {
    return Row(
      children: List.generate(3, (_) => Expanded(
        child: Container(
          height: 140,
          margin: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      )),
    );
  }

  Widget _buildFinanceCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
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

  Widget _buildChartCardLoading() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildRevenueChart(Map<String, dynamic> finance) {
    final bookings = List<Map<String, dynamic>>.from(finance['bookings'] as List? ?? []);

    // Group by month
    final monthlyData = <int, double>{};
    for (final b in bookings) {
      final status = b['status'] as String? ?? '';
      if (status != 'completed' && status != 'active') continue;
      final date = DateTime.tryParse(b['created_at'] as String? ?? '');
      if (date == null) continue;
      final monthKey = date.month;
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + ((b['total_amount'] as num?)?.toDouble() ?? 0);
    }

    if (monthlyData.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))),
      );
    }

    final months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final maxVal = monthlyData.values.isNotEmpty ? monthlyData.values.reduce((a, b) => a > b ? a : b) : 0.0;
    final chartMax = maxVal > 0 ? (maxVal * 1.2).ceilToDouble() : 1000.0;

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
                final month = months[group.x.clamp(0, 11)];
                return BarTooltipItem(
                  '$month\n${_currencyFormat.format(rod.toY)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  '${(value / 1000).toInt()}K',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < 12) {
                    return Text(months[idx], style: const TextStyle(color: AppColors.textMuted, fontSize: 11));
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
            horizontalInterval: chartMax > 0 ? chartMax / 5 : 200,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: monthlyData.entries.map((entry) {
            return BarChartGroupData(
              x: entry.key - 1,
              barRods: [
                BarChartRodData(
                  toY: entry.value,
                  color: AppColors.primary,
                  width: 16,
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

  Widget _buildDistributionChart(Map<String, dynamic> finance) {
    final totalRevenue = (finance['total_revenue'] as num?)?.toDouble() ?? 0;
    final commission = (finance['commission'] as num?)?.toDouble() ?? 0;
    final netRevenue = (finance['net_revenue'] as num?)?.toDouble() ?? 0;

    if (totalRevenue == 0) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))),
      );
    }

    final commissionPercent = (commission / totalRevenue * 100).round();
    final netPercent = (netRevenue / totalRevenue * 100).round();

    return SizedBox(
      height: 300,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: commission,
                    title: '$commissionPercent%',
                    color: AppColors.warning,
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: netRevenue,
                    title: '$netPercent%',
                    color: AppColors.success,
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Komisyon', AppColors.warning),
              const SizedBox(width: 16),
              _buildLegendItem('Net Gelir', AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildRecentBookingsCard(Map<String, dynamic> finance) {
    final bookings = List<Map<String, dynamic>>.from(finance['bookings'] as List? ?? []);
    final recentBookings = bookings.take(10).toList();

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
          const Text(
            'Son İşlemler',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (recentBookings.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Henüz işlem yok', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background.withValues(alpha: 0.5)),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              columns: const [
                DataColumn(label: Text('Tarih', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Durum', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Ödeme', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Gün', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Tutar', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
              ],
              rows: recentBookings.map((b) {
                final date = DateTime.tryParse(b['created_at'] as String? ?? '');
                final status = b['status'] as String? ?? '';
                final paymentStatus = b['payment_status'] as String? ?? '';
                final rentalDays = b['rental_days']?.toString() ?? '-';
                final totalAmount = (b['total_amount'] as num?)?.toDouble() ?? 0;

                return DataRow(cells: [
                  DataCell(Text(date != null ? _dateFormat.format(date) : '-', style: const TextStyle(color: AppColors.textSecondary))),
                  DataCell(_buildStatusBadge(status)),
                  DataCell(_buildPaymentBadge(paymentStatus)),
                  DataCell(Text(rentalDays, style: const TextStyle(color: AppColors.textSecondary))),
                  DataCell(Text(_currencyFormat.format(totalAmount), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
                ]);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Beklemede';
        break;
      case 'confirmed':
        color = AppColors.info;
        label = 'Onaylandı';
        break;
      case 'active':
        color = AppColors.primary;
        label = 'Aktif';
        break;
      case 'completed':
        color = AppColors.success;
        label = 'Tamamlandı';
        break;
      case 'cancelled':
        color = AppColors.error;
        label = 'İptal';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPaymentBadge(String paymentStatus) {
    final isPaid = paymentStatus == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPaid ? 'Ödendi' : 'Bekliyor',
        style: TextStyle(
          color: isPaid ? AppColors.success : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
