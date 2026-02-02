import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

// Driver Earnings Provider
final driverEarningsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('driver_earnings')
      .select('*, drivers(*)')
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(response);
});

// Partner Earnings Provider
final partnerEarningsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('partner_earnings')
      .select('*, partners(*)')
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(response);
});

// Driver Payouts Provider
final driverPayoutsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('driver_payouts')
      .select('*, drivers(*)')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(response);
});

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'week';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kazanc Yonetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Surucu ve kurye kazanclarini takip edin',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'day', label: Text('Gun')),
                        ButtonSegment(value: 'week', label: Text('Hafta')),
                        ButtonSegment(value: 'month', label: Text('Ay')),
                      ],
                      selected: {_selectedPeriod},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() => _selectedPeriod = selection.first);
                      },
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showPayoutDialog(),
                      icon: const Icon(Icons.payments, size: 18),
                      label: const Text('Toplu Odeme Yap'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'Taksi Suruculeri'),
                Tab(text: 'Kuryeler'),
                Tab(text: 'Odeme Gecmisi'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDriverEarningsTab(),
                _buildCourierEarningsTab(),
                _buildPayoutsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverEarningsTab() {
    final earningsAsync = ref.watch(driverEarningsProvider);

    return earningsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (earnings) {
        final totalGross = earnings.fold<double>(0, (sum, e) => sum + (double.tryParse(e['gross_amount']?.toString() ?? '0') ?? 0));
        final totalCommission = earnings.fold<double>(0, (sum, e) => sum + (double.tryParse(e['commission_amount']?.toString() ?? '0') ?? 0));
        final totalNet = earnings.fold<double>(0, (sum, e) => sum + (double.tryParse(e['net_amount']?.toString() ?? '0') ?? 0));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Stats and Chart Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Column
                  Expanded(
                    child: Column(
                      children: [
                        _buildStatCard('Toplam Hasilat', '${totalGross.toStringAsFixed(2)} TL', Icons.account_balance_wallet, AppColors.primary),
                        const SizedBox(height: 12),
                        _buildStatCard('Platform Komisyonu', '${totalCommission.toStringAsFixed(2)} TL', Icons.percent, AppColors.warning),
                        const SizedBox(height: 12),
                        _buildStatCard('Net Kazanc', '${totalNet.toStringAsFixed(2)} TL', Icons.payments, AppColors.success),
                        const SizedBox(height: 12),
                        _buildStatCard('Bekleyen Odeme', '${(totalNet * 0.3).toStringAsFixed(2)} TL', Icons.hourglass_empty, AppColors.info),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Chart
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kazanc Trendi', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: 1000,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: AppColors.surfaceLight,
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 50,
                                        getTitlesWidget: (value, meta) => Text(
                                          '${(value / 1000).toStringAsFixed(0)}K',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final days = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
                                          if (value.toInt() < days.length) {
                                            return Text(days[value.toInt()], style: const TextStyle(fontSize: 10, color: AppColors.textMuted));
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: const [
                                        FlSpot(0, 2500),
                                        FlSpot(1, 3200),
                                        FlSpot(2, 2800),
                                        FlSpot(3, 4100),
                                        FlSpot(4, 3800),
                                        FlSpot(5, 5200),
                                        FlSpot(6, 4500),
                                      ],
                                      isCurved: true,
                                      color: AppColors.primary,
                                      barWidth: 3,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Table
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Kazanc Detaylari', style: Theme.of(context).textTheme.titleMedium),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('Excel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: DataTable2(
                            columnSpacing: 12,
                            columns: const [
                              DataColumn2(label: Text('Surucu'), size: ColumnSize.M),
                              DataColumn2(label: Text('Tarih'), size: ColumnSize.S),
                              DataColumn2(label: Text('Tip'), size: ColumnSize.S),
                              DataColumn2(label: Text('Brut'), size: ColumnSize.S),
                              DataColumn2(label: Text('Komisyon'), size: ColumnSize.S),
                              DataColumn2(label: Text('Net'), size: ColumnSize.S),
                              DataColumn2(label: Text('Durum'), size: ColumnSize.S),
                            ],
                            rows: earnings.map((e) {
                              return DataRow2(
                                cells: [
                                  DataCell(Text(e['drivers']?['full_name'] ?? e['driver_id']?.toString().substring(0, 8) ?? '-')),
                                  DataCell(Text(_formatDate(e['earning_date'] ?? e['created_at']))),
                                  DataCell(_buildTypeBadge(e['type'])),
                                  DataCell(Text('${e['gross_amount']} TL')),
                                  DataCell(Text('${e['commission_amount']} TL', style: const TextStyle(color: AppColors.warning))),
                                  DataCell(Text('${e['net_amount']} TL', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
                                  DataCell(_buildStatusBadge(e['status'])),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourierEarningsTab() {
    final earningsAsync = ref.watch(partnerEarningsProvider);

    return earningsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (earnings) {
        final totalGross = earnings.fold<double>(0, (sum, e) => sum + (double.tryParse(e['gross_amount']?.toString() ?? '0') ?? 0));
        final totalCommission = earnings.fold<double>(0, (sum, e) => sum + (double.tryParse(e['commission_amount']?.toString() ?? '0') ?? 0));
        final totalNet = earnings.fold<double>(0, (sum, e) => sum + (double.tryParse(e['net_amount']?.toString() ?? '0') ?? 0));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Stats Row
              Row(
                children: [
                  _buildStatCardCompact('Toplam Hasilat', '${totalGross.toStringAsFixed(2)} TL', Icons.account_balance_wallet, AppColors.primary),
                  const SizedBox(width: 16),
                  _buildStatCardCompact('Platform Komisyonu', '${totalCommission.toStringAsFixed(2)} TL', Icons.percent, AppColors.warning),
                  const SizedBox(width: 16),
                  _buildStatCardCompact('Net Kazanc', '${totalNet.toStringAsFixed(2)} TL', Icons.payments, AppColors.success),
                  const SizedBox(width: 16),
                  _buildStatCardCompact('Aktif Kurye', '${_getUniquePartners(earnings)}', Icons.delivery_dining, AppColors.info),
                ],
              ),
              const SizedBox(height: 16),

              // Table
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DataTable2(
                      columnSpacing: 12,
                      columns: const [
                        DataColumn2(label: Text('Kurye'), size: ColumnSize.M),
                        DataColumn2(label: Text('Tarih'), size: ColumnSize.S),
                        DataColumn2(label: Text('Siparis'), size: ColumnSize.S),
                        DataColumn2(label: Text('Tip'), size: ColumnSize.S),
                        DataColumn2(label: Text('Brut'), size: ColumnSize.S),
                        DataColumn2(label: Text('Komisyon'), size: ColumnSize.S),
                        DataColumn2(label: Text('Net'), size: ColumnSize.S),
                        DataColumn2(label: Text('Durum'), size: ColumnSize.S),
                        DataColumn2(label: Text('Islem'), size: ColumnSize.S),
                      ],
                      rows: earnings.map((e) {
                        return DataRow2(
                          cells: [
                            DataCell(Text(e['partners']?['full_name'] ?? e['partner_id']?.toString().substring(0, 8) ?? '-')),
                            DataCell(Text(_formatDate(e['created_at']))),
                            DataCell(Text('#${e['order_id']?.toString().substring(0, 6) ?? '-'}')),
                            DataCell(_buildTypeBadge(e['earning_type'])),
                            DataCell(Text('${e['gross_amount']} TL')),
                            DataCell(Text('${e['commission_amount']} TL')),
                            DataCell(Text('${e['net_amount']} TL', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
                            DataCell(_buildStatusBadge(e['status'])),
                            DataCell(IconButton(
                              icon: const Icon(Icons.payments, size: 18),
                              onPressed: e['status'] == 'pending' ? () => _payEarning(e) : null,
                              tooltip: 'Ode',
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayoutsTab() {
    final payoutsAsync = ref.watch(driverPayoutsProvider);

    return payoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (payouts) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // Stats Row
            Row(
              children: [
                _buildStatCardCompact(
                  'Toplam Odeme',
                  '${payouts.fold<double>(0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)} TL',
                  Icons.payments,
                  AppColors.success,
                ),
                const SizedBox(width: 16),
                _buildStatCardCompact(
                  'Bekleyen',
                  payouts.where((p) => p['status'] == 'pending').length.toString(),
                  Icons.hourglass_empty,
                  AppColors.warning,
                ),
                const SizedBox(width: 16),
                _buildStatCardCompact(
                  'Tamamlanan',
                  payouts.where((p) => p['status'] == 'completed').length.toString(),
                  Icons.check_circle,
                  AppColors.info,
                ),
                const SizedBox(width: 16),
                _buildStatCardCompact(
                  'Reddedilen',
                  payouts.where((p) => p['status'] == 'rejected').length.toString(),
                  Icons.cancel,
                  AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DataTable2(
                    columnSpacing: 12,
                    columns: const [
                      DataColumn2(label: Text('ID'), size: ColumnSize.S),
                      DataColumn2(label: Text('Surucu'), size: ColumnSize.M),
                      DataColumn2(label: Text('Tutar'), size: ColumnSize.S),
                      DataColumn2(label: Text('Banka'), size: ColumnSize.M),
                      DataColumn2(label: Text('IBAN'), size: ColumnSize.L),
                      DataColumn2(label: Text('Tarih'), size: ColumnSize.S),
                      DataColumn2(label: Text('Durum'), size: ColumnSize.S),
                      DataColumn2(label: Text('Islemler'), size: ColumnSize.S),
                    ],
                    rows: payouts.map((payout) {
                      return DataRow2(
                        cells: [
                          DataCell(Text('#${payout['id']?.toString().substring(0, 6) ?? ''}')),
                          DataCell(Text(payout['drivers']?['full_name'] ?? '-')),
                          DataCell(Text('${payout['amount']} TL', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(payout['bank_name'] ?? '-')),
                          DataCell(Text(payout['iban'] ?? '-')),
                          DataCell(Text(_formatDate(payout['created_at']))),
                          DataCell(_buildPayoutStatusBadge(payout['status'])),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (payout['status'] == 'pending') ...[
                                IconButton(
                                  icon: const Icon(Icons.check, size: 18, color: AppColors.success),
                                  onPressed: () => _approvePayment(payout),
                                  tooltip: 'Onayla',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                                  onPressed: () => _rejectPayment(payout),
                                  tooltip: 'Reddet',
                                ),
                              ],
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardCompact(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String? type) {
    Color color;
    String label;
    switch (type) {
      case 'ride':
      case 'delivery':
        color = AppColors.primary;
        label = type == 'ride' ? 'Yolculuk' : 'Teslimat';
        break;
      case 'tip':
        color = AppColors.success;
        label = 'Bahsis';
        break;
      case 'bonus':
        color = AppColors.warning;
        label = 'Bonus';
        break;
      default:
        color = AppColors.textMuted;
        label = type ?? '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
      case 'paid':
        color = AppColors.success;
        label = 'Odendi';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Bekliyor';
        break;
      default:
        color = AppColors.textMuted;
        label = status ?? '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _buildPayoutStatusBadge(String? status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = AppColors.success;
        label = 'Tamamlandi';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Bekliyor';
        break;
      case 'processing':
        color = AppColors.info;
        label = 'Isleniyor';
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'Reddedildi';
        break;
      default:
        color = AppColors.textMuted;
        label = status ?? '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  int _getUniquePartners(List<Map<String, dynamic>> earnings) {
    return earnings.map((e) => e['partner_id']).toSet().length;
  }

  void _showPayoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu Odeme'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bekleyen tum odemeleri toplu olarak onayla'),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildPayoutSummaryRow('Taksi Suruculeri', '15', '45,320.00 TL'),
                    const Divider(),
                    _buildPayoutSummaryRow('Kuryeler', '23', '28,150.00 TL'),
                    const Divider(),
                    _buildPayoutSummaryRow('Toplam', '38', '73,470.00 TL', isBold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Toplu odeme islemi basladi')),
              );
            },
            child: const Text('Tum Odemeleri Onayla'),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutSummaryRow(String label, String count, String amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          Text('$count kisi', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 24),
          Text(
            amount,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payEarning(Map<String, dynamic> earning) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('partner_earnings').update({
      'status': 'paid',
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', earning['id']);
    ref.invalidate(partnerEarningsProvider);
  }

  Future<void> _approvePayment(Map<String, dynamic> payout) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('driver_payouts').update({
      'status': 'completed',
    }).eq('id', payout['id']);
    ref.invalidate(driverPayoutsProvider);
  }

  Future<void> _rejectPayment(Map<String, dynamic> payout) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('driver_payouts').update({
      'status': 'rejected',
    }).eq('id', payout['id']);
    ref.invalidate(driverPayoutsProvider);
  }
}
