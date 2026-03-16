import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/accounting_service.dart';

class TaxReportScreen extends ConsumerStatefulWidget {
  const TaxReportScreen({super.key});

  @override
  ConsumerState<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends ConsumerState<TaxReportScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final kdvAsync = ref.watch(kdvSummaryProvider(BalanceSheetParams(_selectedMonth, _selectedYear)));

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
                    Text('Vergi Raporu', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('KDV hesapları ve vergi dağılımı', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
                Row(children: [
                  _buildMonthYearSelector(),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Excel'),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 32),

            kdvAsync.when(
              data: (kdv) => _buildContent(kdv),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    return Row(children: [
      DropdownButton<int>(
        value: _selectedMonth,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary),
        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat.MMMM('tr').format(DateTime(2024, i + 1))))),
        onChanged: (v) => setState(() => _selectedMonth = v!),
      ),
      const SizedBox(width: 8),
      DropdownButton<int>(
        value: _selectedYear,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary),
        items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - i, child: Text('${DateTime.now().year - i}'))),
        onChanged: (v) => setState(() => _selectedYear = v!),
      ),
    ]);
  }

  Widget _buildContent(KdvSummary kdv) {
    return Column(
      children: [
        // KDV Summary Cards
        Row(children: [
          _buildKdvCard('Toplanan KDV', kdv.totalKdvCollected, Icons.arrow_downward, AppColors.success),
          const SizedBox(width: 16),
          _buildKdvCard('Ödenen KDV', kdv.totalKdvPaid, Icons.arrow_upward, AppColors.error),
          const SizedBox(width: 16),
          _buildKdvCard('Net KDV', kdv.netKdv, Icons.balance, kdv.netKdv >= 0 ? AppColors.success : AppColors.error),
        ]),

        const SizedBox(height: 32),

        // Sector Distribution
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildSectorTable(kdv)),
            const SizedBox(width: 24),
            Expanded(child: _buildSectorPieChart(kdv)),
          ],
        ),
      ],
    );
  }

  Widget _buildKdvCard(String title, double value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(_currencyFormat.format(value), style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorTable(KdvSummary kdv) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sektör Bazlı KDV', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (kdv.sectorKdv.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Veri yok', style: TextStyle(color: AppColors.textMuted))))
          else
            DataTable(
              columns: const [
                DataColumn(label: Text('SEKTÖR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('KDV ORANI', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('TOPLANAN', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('ÖDENEN', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('NET', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
              ],
              rows: kdv.sectorKdv.map((s) => DataRow(cells: [
                DataCell(Text(_sectorLabel(s.sector), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                DataCell(Text('%${(s.kdvRate * 100).toInt()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                DataCell(Text(_currencyFormat.format(s.kdvCollected), style: const TextStyle(color: AppColors.success, fontSize: 13))),
                DataCell(Text(_currencyFormat.format(s.kdvPaid), style: const TextStyle(color: AppColors.error, fontSize: 13))),
                DataCell(Text(
                  _currencyFormat.format(s.kdvCollected - s.kdvPaid),
                  style: TextStyle(color: s.kdvCollected - s.kdvPaid >= 0 ? AppColors.success : AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                )),
              ])).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSectorPieChart(KdvSummary kdv) {
    final total = kdv.sectorKdv.fold(0.0, (sum, s) => sum + s.kdvCollected);
    final colors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.info, AppColors.error];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('KDV Dağılımı', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          if (total == 0)
            const SizedBox(height: 200, child: Center(child: Text('Veri yok', style: TextStyle(color: AppColors.textMuted))))
          else
            SizedBox(
              height: 200,
              child: PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: kdv.sectorKdv.asMap().entries.map((e) {
                  final pct = (e.value.kdvCollected / total * 100).round();
                  return PieChartSectionData(
                    value: e.value.kdvCollected,
                    title: '$pct%',
                    color: colors[e.key % colors.length],
                    radius: 40,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  );
                }).toList(),
              )),
            ),
          const SizedBox(height: 16),
          ...kdv.sectorKdv.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key % colors.length], borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Text(_sectorLabel(e.value.sector), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          )),
        ],
      ),
    );
  }

  String _sectorLabel(String s) {
    switch (s) {
      case 'food': return 'Yemek';
      case 'store': return 'Market/Mağaza';
      case 'taxi': return 'Taksi';
      case 'rental': return 'Kiralama';
      default: return s;
    }
  }
}
