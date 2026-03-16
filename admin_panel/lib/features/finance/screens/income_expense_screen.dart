import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';
import '../services/accounting_service.dart';
import '../../invoices/screens/web_download_helper.dart' if (dart.library.io) '../../invoices/screens/io_download_helper.dart';

class IncomeExpenseScreen extends ConsumerStatefulWidget {
  const IncomeExpenseScreen({super.key});

  @override
  ConsumerState<IncomeExpenseScreen> createState() => _IncomeExpenseScreenState();
}

class _IncomeExpenseScreenState extends ConsumerState<IncomeExpenseScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');
  String? _filterType;
  String? _filterSource;
  int _currentPage = 0;
  static const _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(financeEntriesProvider(FinanceEntryParams(
      type: _filterType,
      source: _filterSource,
      page: _currentPage,
      pageSize: _pageSize,
    )));

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
                    Text('Gelir / Gider', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Tüm finansal hareketler', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAddEntryDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Manuel Giriş'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _exportExcel,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Excel'),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // Filters
            _buildFilters(),
            const SizedBox(height: 24),

            // Data Table
            entriesAsync.when(
              data: (entries) => _buildDataTable(entries),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(label: const Text('Tümü'), selected: _filterType == null, onSelected: (_) => setState(() { _filterType = null; _currentPage = 0; })),
        FilterChip(label: const Text('Gelir'), selected: _filterType == 'income', onSelected: (_) => setState(() { _filterType = _filterType == 'income' ? null : 'income'; _currentPage = 0; })),
        FilterChip(label: const Text('Gider'), selected: _filterType == 'expense', onSelected: (_) => setState(() { _filterType = _filterType == 'expense' ? null : 'expense'; _currentPage = 0; })),
        const SizedBox(width: 16),
        FilterChip(label: const Text('Yemek'), selected: _filterSource == 'food', onSelected: (_) => setState(() { _filterSource = _filterSource == 'food' ? null : 'food'; _currentPage = 0; })),
        FilterChip(label: const Text('Market'), selected: _filterSource == 'store', onSelected: (_) => setState(() { _filterSource = _filterSource == 'store' ? null : 'store'; _currentPage = 0; })),
        FilterChip(label: const Text('Taksi'), selected: _filterSource == 'taxi', onSelected: (_) => setState(() { _filterSource = _filterSource == 'taxi' ? null : 'taxi'; _currentPage = 0; })),
        FilterChip(label: const Text('Kiralama'), selected: _filterSource == 'rental', onSelected: (_) => setState(() { _filterSource = _filterSource == 'rental' ? null : 'rental'; _currentPage = 0; })),
      ],
    );
  }

  Widget _buildDataTable(List<FinanceEntry> entries) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        children: [
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Kayıt bulunamadı', style: TextStyle(color: AppColors.textMuted))))
          else
            DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('TARİH', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('TİP', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('KATEGORİ', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('AÇIKLAMA', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('KAYNAK', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('TUTAR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
              ],
              rows: entries.map((e) {
                final isIncome = e.type == 'income';
                return DataRow(cells: [
                  DataCell(Text(_dateFormat.format(e.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isIncome ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isIncome ? 'Gelir' : 'Gider', style: TextStyle(color: isIncome ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Text(e.category, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                  DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text(e.description, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)))),
                  DataCell(Text(e.source.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
                  DataCell(Text(
                    '${isIncome ? '+' : '-'}${_currencyFormat.format(e.amount)}',
                    style: TextStyle(color: isIncome ? AppColors.success : AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                  )),
                ]);
              }).toList(),
            ),
          const SizedBox(height: 16),
          // Pagination
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Sayfa ${_currentPage + 1}', style: const TextStyle(color: AppColors.textSecondary)),
              IconButton(
                onPressed: entries.length == _pageSize ? () => setState(() => _currentPage++) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEntryDialog() async {
    final typeCtrl = ValueNotifier<String>('income');
    final categoryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final sourceCtrl = ValueNotifier<String>('manual');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Manuel Giriş', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: typeCtrl,
                builder: (_, val, __) => SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'income', label: Text('Gelir')),
                    ButtonSegment(value: 'expense', label: Text('Gider')),
                  ],
                  selected: {val},
                  onSelectionChanged: (s) => typeCtrl.value = s.first,
                ),
              ),
              const SizedBox(height: 16),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tutar (₺)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: sourceCtrl,
                builder: (_, val, __) => DropdownButtonFormField<String>(
                  value: val,
                  decoration: const InputDecoration(labelText: 'Kaynak', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'manual', child: Text('Manuel')),
                    DropdownMenuItem(value: 'food', child: Text('Yemek')),
                    DropdownMenuItem(value: 'store', child: Text('Market')),
                    DropdownMenuItem(value: 'taxi', child: Text('Taksi')),
                    DropdownMenuItem(value: 'rental', child: Text('Kiralama')),
                  ],
                  onChanged: (v) => sourceCtrl.value = v ?? 'manual',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || categoryCtrl.text.isEmpty) return;
              try {
                await AccountingService.createFinanceEntry(
                  type: typeCtrl.value,
                  category: categoryCtrl.text,
                  description: descCtrl.text,
                  amount: amount,
                  source: sourceCtrl.value,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(financeEntriesProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıt eklendi'), backgroundColor: AppColors.success));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel hazırlanıyor...'), backgroundColor: AppColors.info));
      final supabase = ref.read(supabaseProvider);
      final result = await supabase.rpc('get_recent_transactions', params: {'p_limit': 1000});
      final data = result != null ? (result as List).map((e) => e as Map<String, dynamic>).toList() : <Map<String, dynamic>>[];
      final bytes = await InvoiceService.exportFinanceToExcel(data);
      downloadFile(Uint8List.fromList(bytes), 'gelir_gider_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel indirildi'), backgroundColor: AppColors.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
    }
  }
}
