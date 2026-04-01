import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 0);
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
                      'Gelir ve komisyon raporlari',
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

            // Revenue Stat Cards
            financeAsync.when(
              data: (finance) => _buildRevenueStatCards(finance),
              loading: () => _buildStatsCardsLoading(),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),

            const SizedBox(height: 32),

            // Revenue Trend + Category Breakdown
            financeAsync.when(
              data: (finance) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildMonthlyRevenueTrend(finance),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: _buildRevenueByCategoryBreakdown(finance),
                  ),
                ],
              ),
              loading: () => Row(
                children: [
                  Expanded(flex: 3, child: _buildChartCardLoading()),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildChartCardLoading()),
                ],
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Payment Distribution + Top Earning Cars
            financeAsync.when(
              data: (finance) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPaymentMethodDistribution(finance),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: _buildTopEarningCars(finance),
                  ),
                ],
              ),
              loading: () => Row(
                children: [
                  Expanded(child: _buildChartCardLoading()),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildChartCardLoading()),
                ],
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Recent Transactions
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
    final periods = [
      {'label': '7 Gun', 'value': '7'},
      {'label': '30 Gun', 'value': '30'},
      {'label': '90 Gun', 'value': '90'},
      {'label': '1 Yıl', 'value': '365'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p['value'];
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = p['value']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                p['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRevenueStatCards(Map<String, dynamic> finance) {
    final totalRevenue = (finance['total_revenue'] as num?)?.toDouble() ?? 0;
    final netRevenue = (finance['net_revenue'] as num?)?.toDouble() ?? 0;
    final completedBookings = finance['completed_bookings'] as int? ?? 0;
    final avgBookingValue = (finance['avg_booking_value'] as num?)?.toDouble() ?? 0;

    // Calculate this month and last month from bookings
    final bookings = List<Map<String, dynamic>>.from(finance['bookings'] as List? ?? []);
    final now = DateTime.now();
    double thisMonth = 0;
    double lastMonth = 0;
    for (final b in bookings) {
      final status = b['status'] as String? ?? '';
      if (status != 'completed' && status != 'active') {
        continue;
      }
      final date = DateTime.tryParse(b['created_at'] as String? ?? '');
      if (date == null) {
        continue;
      }
      final amount = (b['total_amount'] as num?)?.toDouble() ?? 0;
      if (date.month == now.month && date.year == now.year) {
        thisMonth += amount;
      } else if ((date.month == now.month - 1 && date.year == now.year) ||
          (now.month == 1 && date.month == 12 && date.year == now.year - 1)) {
        lastMonth += amount;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            _buildStatCard('Toplam Gelir', _currencyFormat.format(totalRevenue), Icons.trending_up, AppColors.success),
            const SizedBox(width: 16),
            _buildStatCard('Bu Ay', _currencyFormat.format(thisMonth), Icons.calendar_today, AppColors.primary),
            const SizedBox(width: 16),
            _buildStatCard('Gecen Ay', _currencyFormat.format(lastMonth), Icons.history, AppColors.info),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard('Tamamlanan Rez.', completedBookings.toString(), Icons.check_circle, AppColors.success),
            const SizedBox(width: 16),
            _buildStatCard('Ortalama Deger', _currencyFormat.format(avgBookingValue), Icons.analytics, AppColors.warning),
            const SizedBox(width: 16),
            _buildStatCard('Net Gelir', _currencyFormat.format(netRevenue), Icons.savings, AppColors.primaryLight),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCardsLoading() {
    return Row(
      children: List.generate(3, (_) => Expanded(
        child: Container(
          height: 140,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      )),
    );
  }

  Widget _buildChartCardLoading() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildMonthlyRevenueTrend(Map<String, dynamic> finance) {
    final bookings = List<Map<String, dynamic>>.from(finance['bookings'] as List? ?? []);

    // Group by month
    final monthlyData = <int, double>{};
    for (final b in bookings) {
      final status = b['status'] as String? ?? '';
      if (status != 'completed' && status != 'active') {
        continue;
      }
      final date = DateTime.tryParse(b['created_at'] as String? ?? '');
      if (date == null) {
        continue;
      }
      final monthKey = date.month;
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + ((b['total_amount'] as num?)?.toDouble() ?? 0);
    }

    final months = ['Oca', 'Sub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Agu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final maxVal = monthlyData.values.isNotEmpty ? monthlyData.values.reduce((a, b) => a > b ? a : b) : 0.0;

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
          const Text('Aylık Gelir Trendi', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Aylık bazda gelir dağılımı', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (monthlyData.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))),
            )
          else
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  final monthValue = monthlyData[index + 1] ?? 0;
                  final barHeight = maxVal > 0 ? (monthValue / maxVal * 160) : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (monthValue > 0)
                            Tooltip(
                              message: '${months[index]}: ${_currencyFormat.format(monthValue)}',
                              child: Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: monthValue > 0 ? 0.8 : 0.2),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(months[index], style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRevenueByCategoryBreakdown(Map<String, dynamic> finance) {
    final bookings = List<Map<String, dynamic>>.from(finance['bookings'] as List? ?? []);

    // This is a placeholder since we don't have category in bookings directly
    // We group by payment_method as a proxy, or show total breakdown
    final statusCounts = <String, double>{};
    for (final b in bookings) {
      final status = b['status'] as String? ?? 'unknown';
      final amount = (b['total_amount'] as num?)?.toDouble() ?? 0;
      statusCounts[status] = (statusCounts[status] ?? 0) + amount;
    }

    final statusLabels = {
      'completed': 'Tamamlanan',
      'active': 'Aktif',
      'confirmed': 'Onaylanan',
      'pending': 'Bekleyen',
      'cancelled': 'İptal',
    };

    final statusColors = {
      'completed': AppColors.success,
      'active': AppColors.primary,
      'confirmed': AppColors.info,
      'pending': AppColors.warning,
      'cancelled': AppColors.error,
    };

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
          const Text('Gelir Dağılımı', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Durum bazında gelir', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (statusCounts.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))),
            )
          else
            ...statusCounts.entries.map((entry) {
              final label = statusLabels[entry.key] ?? entry.key;
              final color = statusColors[entry.key] ?? AppColors.textMuted;
              final total = statusCounts.values.fold(0.0, (a, b) => a + b);
              final percent = total > 0 ? (entry.value / total * 100) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(width: 8),
                            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                        Text(_currencyFormat.format(entry.value), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodDistribution(Map<String, dynamic> finance) {
    final bookings = List<Map<String, dynamic>>.from(finance['bookings'] as List? ?? []);

    final methodCounts = <String, int>{};
    for (final b in bookings) {
      final method = b['payment_method'] as String? ?? 'other';
      methodCounts[method] = (methodCounts[method] ?? 0) + 1;
    }

    final methodLabels = {
      'credit_card': 'Kredi Karti',
      'cash': 'Nakit',
      'bank_transfer': 'Havale/EFT',
      'other': 'Diğer',
    };

    final methodIcons = {
      'credit_card': Icons.credit_card,
      'cash': Icons.money,
      'bank_transfer': Icons.account_balance,
      'other': Icons.more_horiz,
    };

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
          const Text('Ödeme Yöntemleri', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Ödeme yöntemi dağılımı', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (methodCounts.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))),
            )
          else
            ...methodCounts.entries.map((entry) {
              final label = methodLabels[entry.key] ?? entry.key;
              final icon = methodIcons[entry.key] ?? Icons.payment;
              final total = methodCounts.values.fold(0, (a, b) => a + b);
              final percent = total > 0 ? (entry.value / total * 100).round() : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percent / 100,
                              backgroundColor: AppColors.surfaceLight,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$percent%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopEarningCars(Map<String, dynamic> finance) {
    final bookings = List<Map<String, dynamic>>.from(finance['bookings'] as List? ?? []);

    // Build car earnings map - we don't have car details in finance bookings,
    // so we use booking_number or similar as identifier placeholder
    // In real usage, the finance provider would need to join with rental_cars
    final carEarnings = <String, double>{};
    for (final b in bookings) {
      final status = b['status'] as String? ?? '';
      if (status != 'completed' && status != 'active') {
        continue;
      }
      final bookingRef = b['booking_number'] as String? ?? b['id']?.toString().substring(0, 8) ?? '?';
      carEarnings[bookingRef] = (carEarnings[bookingRef] ?? 0) + ((b['total_amount'] as num?)?.toDouble() ?? 0);
    }

    final sortedEntries = carEarnings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCars = sortedEntries.take(5).toList();

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
          const Text('En Cok Kazandiran', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('En yuksek gelir getiren rezervasyonlar', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (topCars.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))),
            )
          else
            ...topCars.asMap().entries.map((entry) {
              final index = entry.key;
              final carEntry = entry.value;
              final medals = [Icons.emoji_events, Icons.workspace_premium, Icons.military_tech];
              final medalColors = [AppColors.warning, AppColors.textMuted, const Color(0xFFCD7F32)];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: index < 3
                        ? medalColors[index].withValues(alpha: 0.05)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: index < 3
                          ? medalColors[index].withValues(alpha: 0.2)
                          : AppColors.surfaceLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (index < 3)
                        Icon(medals[index], color: medalColors[index], size: 22)
                      else
                        SizedBox(
                          width: 22,
                          child: Center(
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Rez. ${carEntry.key}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        _currencyFormat.format(carEntry.value),
                        style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
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
                DataColumn(label: Text('Gun', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
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
        label = 'Bekleyen';
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
        isPaid ? 'Odendi' : 'Bekliyor',
        style: TextStyle(
          color: isPaid ? AppColors.success : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
