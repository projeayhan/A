import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/accounting_service.dart';

class BalanceSheetScreen extends ConsumerStatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  ConsumerState<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends ConsumerState<BalanceSheetScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final bsAsync = ref.watch(balanceSheetProvider(BalanceSheetParams(_selectedMonth, _selectedYear)));

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
                    Text('Bilanço', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Varlıklar, borçlar ve öz kaynak', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
                ]),
              ],
            ),
            const SizedBox(height: 32),

            bsAsync.when(
              data: (bs) => _buildContent(bs),
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

  Widget _buildContent(BalanceSheetData bs) {
    return Column(
      children: [
        // Summary Cards
        Row(children: [
          _buildSummaryCard('Toplam Varlıklar', bs.totalAssets, Icons.account_balance_wallet, AppColors.success),
          const SizedBox(width: 16),
          _buildSummaryCard('Toplam Borçlar', bs.totalLiabilities, Icons.money_off, AppColors.error),
          const SizedBox(width: 16),
          _buildSummaryCard('Öz Kaynak', bs.equity, Icons.savings, AppColors.primary),
        ]),
        const SizedBox(height: 32),

        // Assets & Liabilities Tables
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSection('Varlıklar', bs.assets, AppColors.success)),
            const SizedBox(width: 24),
            Expanded(child: _buildSection('Borçlar', bs.liabilities, AppColors.error)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double value, IconData icon, Color color) {
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

  Widget _buildSection(String title, List<BalanceSheetItem> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Veri yok', style: TextStyle(color: AppColors.textMuted))))
          else
            ...items.map((item) => Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.category, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        if (item.prevAmount != null)
                          Text(
                            'Önceki dönem: ${_currencyFormat.format(item.prevAmount!)}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_currencyFormat.format(item.amount), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (item.prevAmount != null && item.prevAmount! > 0)
                        Text(
                          '${((item.amount - item.prevAmount!) / item.prevAmount! * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: item.amount >= item.prevAmount! ? AppColors.success : AppColors.error,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Toplam $title', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                Text(_currencyFormat.format(items.fold(0.0, (s, i) => s + i.amount)), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
