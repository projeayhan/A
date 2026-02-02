import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/taxi_service.dart';
import '../../core/theme/app_theme.dart';

// Earnings provider
final earningsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await TaxiService.getEarningsSummary();
});

// Earnings history provider
final earningsHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return await TaxiService.getEarningsHistory();
});

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsProvider);
    final historyAsync = ref.watch(earningsHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kazançlarım'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(earningsProvider);
              ref.invalidate(earningsHistoryProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(earningsProvider);
          ref.invalidate(earningsHistoryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              earningsAsync.when(
                data: (data) => _buildSummaryCards(context, data),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildErrorCard(context),
              ),

              const SizedBox(height: 24),

              // Stats
              earningsAsync.when(
                data: (data) => _buildStatsSection(context, data),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // History
              Text(
                'Kazanç Geçmişi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              historyAsync.when(
                data: (history) => _buildHistoryList(context, history),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildErrorCard(context),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, Map<String, dynamic> data) {
    final todayEarnings = (data['today'] as num?)?.toDouble() ?? 0;
    final weekEarnings = (data['week'] as num?)?.toDouble() ?? 0;
    final monthEarnings = (data['month'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        // Today's Earnings - Featured
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondary,
                AppColors.secondary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bugünkü Net Kazanç',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('d MMM', 'tr').format(DateTime.now()),
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '₺${(todayEarnings * (1 - ((data['commission_rate'] as double? ?? 20) / 100))).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Brüt: ₺${todayEarnings.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Week and Month
        Row(
          children: [
            Expanded(
              child: _buildMiniCard(
                context,
                'Bu Hafta',
                '₺${weekEarnings.toStringAsFixed(0)}',
                Icons.date_range,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniCard(
                context,
                'Bu Ay',
                '₺${monthEarnings.toStringAsFixed(0)}',
                Icons.calendar_month,
                AppColors.info,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, Map<String, dynamic> data) {
    final totalRides = data['total_rides'] as int? ?? 0;
    final avgRating = (data['avg_rating'] as num?)?.toDouble() ?? 0;
    final totalEarnings = (data['total'] as num?)?.toDouble() ?? 0;
    final commissionRate =
        (data['commission_rate'] as num?)?.toDouble() ?? 20.0;
    final commissionAmount =
        (data['commission_amount'] as num?)?.toDouble() ?? 0;
    final netEarnings = (data['net_earnings'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toplam İstatistikler',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.local_taxi,
                  totalRides.toString(),
                  'Yolculuk',
                  AppColors.secondary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.star,
                  avgRating.toStringAsFixed(1),
                  'Puan',
                  AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.account_balance_wallet,
                  '₺${totalEarnings.toStringAsFixed(0)}',
                  'Brüt Kazanç',
                  AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.percent,
                  '-₺${commissionAmount.toStringAsFixed(0)}',
                  'Komisyon (%${commissionRate.toStringAsFixed(0)})',
                  AppColors.error,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.wallet,
                  '₺${netEarnings.toStringAsFixed(0)}',
                  'Net Kazanç',
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<Map<String, dynamic>> history,
  ) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 48, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Henüz kazanç geçmişi yok',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Yolculuk tamamladıkça kazançlarınız burada görünecek',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: history.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final amount = (item['amount'] as num?)?.toDouble() ?? 0;
          final date =
              DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now();

          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_taxi, color: AppColors.success),
                ),
                title: Text(
                  item['ride_number'] ?? 'Yolculuk',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  DateFormat('d MMM, HH:mm', 'tr').format(date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Text(
                  '+₺${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (index < history.length - 1) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Veriler yüklenemedi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
