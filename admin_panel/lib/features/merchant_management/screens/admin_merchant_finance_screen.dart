import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';

class AdminMerchantFinanceScreen extends ConsumerStatefulWidget {
  final String merchantId;
  const AdminMerchantFinanceScreen({super.key, required this.merchantId});

  @override
  ConsumerState<AdminMerchantFinanceScreen> createState() =>
      _AdminMerchantFinanceScreenState();
}

class _AdminMerchantFinanceScreenState
    extends ConsumerState<AdminMerchantFinanceScreen> {
  String _selectedPeriod = 'Bu Ay';
  final List<String> _periods = [
    'Bu Hafta',
    'Bu Ay',
    'Son 3 Ay',
    'Bu Yıl',
  ];

  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  String _periodToKey(String period) {
    switch (period) {
      case 'Bu Hafta':
        return 'week';
      case 'Bu Ay':
        return 'month';
      case 'Son 3 Ay':
        return 'quarter';
      case 'Bu Yıl':
        return 'year';
      default:
        return 'month';
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeParams = (
      merchantId: widget.merchantId,
      period: _periodToKey(_selectedPeriod),
    );
    final financeAsync = ref.watch(merchantFinanceProvider(financeParams));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
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
                      'Finansal Genel Bakış',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gelir, komisyon ve sipariş istatistikleri',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                // Period selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.surfaceLight.withOpacity(0.5),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                      items: _periods.map((period) {
                        return DropdownMenuItem(
                          value: period,
                          child: Text(period),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPeriod = value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: financeAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Finansal veriler yüklenirken hata oluştu',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          merchantFinanceProvider((
                            merchantId: widget.merchantId,
                            period: _periodToKey(_selectedPeriod),
                          )),
                        ),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
                data: (data) => _buildContent(data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final totalRevenue = (data['total_revenue'] as num?)?.toDouble() ?? 0;
    final totalCommission =
        (data['total_commission'] as num?)?.toDouble() ?? 0;
    final netRevenue = (data['net_revenue'] as num?)?.toDouble() ?? 0;
    final orderCount = (data['order_count'] as num?)?.toInt() ?? 0;
    final orders =
        List<Map<String, dynamic>>.from(data['orders'] as List? ?? []);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Toplam Gelir',
                  value: _currencyFormat.format(totalRevenue),
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Komisyon',
                  value: _currencyFormat.format(totalCommission),
                  icon: Icons.percent,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Net Gelir',
                  value: _currencyFormat.format(netRevenue),
                  icon: Icons.trending_up,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Sipariş Sayısı',
                  value: orderCount.toString(),
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Revenue Chart
          _buildRevenueChart(orders),
          const SizedBox(height: 24),

          // Recent Transactions Table
          _buildTransactionsTable(orders),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(List<Map<String, dynamic>> orders) {
    // Group orders by month
    final Map<String, double> monthlyRevenue = {};
    final monthFormat = DateFormat('MMM yy', 'tr_TR');

    for (final order in orders) {
      final createdAt = order['created_at'] as String?;
      if (createdAt == null) continue;
      final date = DateTime.tryParse(createdAt);
      if (date == null) continue;
      final monthKey = monthFormat.format(date);
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
      monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + amount;
    }

    if (monthlyRevenue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight.withOpacity(0.5)),
        ),
        child: const Center(
          child: Text(
            'Grafik için yeterli veri bulunmuyor',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final maxValue =
        monthlyRevenue.values.reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aylık Gelir',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthlyRevenue.entries.map((entry) {
                final barHeight = (entry.value / maxValue) * 170;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFormat.format(entry.value),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: barHeight.clamp(4, 170),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.key,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable(List<Map<String, dynamic>> orders) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Son İşlemler',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          orders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Henüz işlem bulunmuyor',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.surfaceLight.withOpacity(0.3),
                    ),
                    headingTextStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    dataTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Sipariş No')),
                      DataColumn(label: Text('Tutar'), numeric: true),
                      DataColumn(label: Text('Komisyon'), numeric: true),
                      DataColumn(label: Text('Tarih')),
                      DataColumn(label: Text('Durum')),
                    ],
                    rows: orders.take(20).map((order) {
                      final orderNumber =
                          order['order_number'] as String? ?? '-';
                      final amount =
                          (order['total_amount'] as num?)?.toDouble() ?? 0;
                      final commission =
                          (order['commission_amount'] as num?)?.toDouble() ?? 0;
                      final status = order['status'] as String? ?? 'unknown';
                      final createdAt = order['created_at'] as String?;
                      String dateStr = '-';
                      if (createdAt != null) {
                        final date = DateTime.tryParse(createdAt);
                        if (date != null) {
                          dateStr = dateFormat.format(date.toLocal());
                        }
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              orderNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _currencyFormat.format(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _currencyFormat.format(commission),
                              style: const TextStyle(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          DataCell(_buildOrderStatusBadge(status)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusBadge(String status) {
    final String label;
    final Color color;

    switch (status) {
      case 'completed':
        label = 'Tamamlandı';
        color = AppColors.success;
        break;
      case 'cancelled':
        label = 'İptal';
        color = AppColors.error;
        break;
      case 'pending':
        label = 'Beklemede';
        color = AppColors.warning;
        break;
      case 'processing':
        label = 'Hazırlanıyor';
        color = AppColors.info;
        break;
      default:
        label = status;
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
