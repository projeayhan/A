import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../services/accounting_service.dart';

// Payment tracking providers
final _paymentListProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, status) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    var query = supabase.from('invoices').select();
    if (status != 'all') {
      query = query.eq('status', status);
    }
    final result = await query.order('created_at', ascending: false).limit(100);
    return (result as List).map((e) => e as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

class PaymentTrackingScreen extends ConsumerStatefulWidget {
  const PaymentTrackingScreen({super.key});

  @override
  ConsumerState<PaymentTrackingScreen> createState() => _PaymentTrackingScreenState();
}

class _PaymentTrackingScreenState extends ConsumerState<PaymentTrackingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');
  final Set<String> _selectedIds = {};

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
    final agingAsync = ref.watch(agingReportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ödeme Takip', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Bekleyen, ödenen ve geciken ödemeler', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                    if (_selectedIds.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _markSelectedPaid,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text('${_selectedIds.length} Ödemeyi Onayla'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // Aging Cards
                agingAsync.when(
                  data: (aging) => _buildAgingCards(aging),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Bekleyen'),
                    Tab(text: 'Ödenen'),
                    Tab(text: 'Geciken'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentList('pending'),
                _buildPaymentList('paid'),
                _buildPaymentList('overdue'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingCards(AgingReport aging) {
    return Row(children: [
      _buildAgingCard('Güncel', aging.current, AppColors.success),
      const SizedBox(width: 12),
      _buildAgingCard('0-30 Gün', aging.days30, AppColors.info),
      const SizedBox(width: 12),
      _buildAgingCard('30-60 Gün', aging.days60, AppColors.warning),
      const SizedBox(width: 12),
      _buildAgingCard('60-90 Gün', aging.days90, AppColors.error),
      const SizedBox(width: 12),
      _buildAgingCard('90+ Gün', aging.days90Plus, const Color(0xFFDC2626)),
    ]);
  }

  Widget _buildAgingCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_currencyFormat.format(amount), style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentList(String status) {
    final paymentsAsync = ref.watch(_paymentListProvider(status));
    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(child: Text('Kayıt bulunamadı', style: TextStyle(color: AppColors.textMuted)));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
            child: DataTable(
              columns: [
                if (status == 'pending') const DataColumn(label: Text('')),
                const DataColumn(label: Text('FATURA NO', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                const DataColumn(label: Text('ALICI', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                const DataColumn(label: Text('TARİH', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                const DataColumn(label: Text('TUTAR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                const DataColumn(label: Text('DURUM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                if (status == 'pending') const DataColumn(label: Text('İŞLEM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
              rows: payments.map((p) {
                final id = p['id'] as String? ?? '';
                final invoiceNumber = p['invoice_number'] as String? ?? '';
                final buyerName = p['buyer_name'] as String? ?? '';
                final createdAt = DateTime.tryParse(p['created_at'] as String? ?? '');
                final total = (p['total'] as num?)?.toDouble() ?? 0;
                final pStatus = p['status'] as String? ?? 'pending';

                return DataRow(
                  selected: _selectedIds.contains(id),
                  cells: [
                    if (status == 'pending')
                      DataCell(Checkbox(
                        value: _selectedIds.contains(id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        }),
                      )),
                    DataCell(Text(invoiceNumber, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
                    DataCell(Text(buyerName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    DataCell(Text(createdAt != null ? _dateFormat.format(createdAt) : '-', style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
                    DataCell(Text(_currencyFormat.format(total), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(_buildStatusBadge(pStatus)),
                    if (status == 'pending')
                      DataCell(IconButton(
                        icon: const Icon(Icons.check_circle_outline, size: 20, color: AppColors.success),
                        onPressed: () async {
                          await AccountingService.markPaymentPaid(id);
                          ref.invalidate(_paymentListProvider);
                          ref.invalidate(agingReportProvider);
                        },
                      )),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = switch (status) {
      'paid' => AppColors.success,
      'overdue' => AppColors.error,
      _ => AppColors.warning,
    };
    final label = switch (status) {
      'paid' => 'Ödendi',
      'overdue' => 'Gecikmiş',
      'issued' => 'Bekliyor',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _markSelectedPaid() async {
    if (_selectedIds.isEmpty) return;
    try {
      await AccountingService.markPaymentsPaidBulk(_selectedIds.toList());
      setState(() => _selectedIds.clear());
      ref.invalidate(_paymentListProvider);
      ref.invalidate(agingReportProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödemeler onaylandı'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}
