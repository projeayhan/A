import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/payment_service.dart';

// ── Merchant Invoices Provider ──
final merchantInvoicesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, merchantId) async {
  final supabase = ref.read(supabaseClientProvider);
  final result = await supabase
      .from('invoices')
      .select('*, invoice_items(*)')
      .or('merchant_id.eq.$merchantId,source_id.eq.$merchantId')
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(result);
});

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> with SingleTickerProviderStateMixin {
  String _selectedPeriod = 'Bu Ay';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Genel Bakış'),
              Tab(text: 'Faturalarım'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildInvoicesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab() {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    if (merchant == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final invoicesAsync = ref.watch(merchantInvoicesProvider(merchant.id));
    final currencyFmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
    final dateFmt = DateFormat('dd.MM.yyyy', 'tr');

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: TextStyle(color: AppColors.error))),
      data: (invoices) {
        if (invoices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: AppColors.textSecondary.withAlpha(80)),
                const SizedBox(height: 16),
                const Text('Henüz fatura bulunmuyor', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Aylık komisyon faturaları burada görünecektir', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        final pending = invoices.where((i) => i['payment_status'] != 'paid' && i['status'] != 'cancelled').toList();
        final paid = invoices.where((i) => i['payment_status'] == 'paid').toList();
        final pendingTotal = pending.fold<double>(0, (s, i) => s + ((i['total'] as num?)?.toDouble() ?? 0));
        final paidTotal = paid.fold<double>(0, (s, i) => s + ((i['total'] as num?)?.toDouble() ?? 0));

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              Row(
                children: [
                  _invoiceStatCard('Toplam Fatura', '${invoices.length}', Icons.receipt_long, AppColors.primary),
                  const SizedBox(width: 12),
                  _invoiceStatCard('Ödenmemiş', currencyFmt.format(pendingTotal), Icons.schedule, AppColors.warning),
                  const SizedBox(width: 12),
                  _invoiceStatCard('Ödenmiş', currencyFmt.format(paidTotal), Icons.check_circle, AppColors.success),
                ],
              ),
              const SizedBox(height: 24),

              // Ödenmemiş faturalar
              if (pending.isNotEmpty) ...[
                const Text('Ödenmemiş Faturalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...pending.map((inv) => _invoiceCard(inv, currencyFmt, dateFmt)),
                const SizedBox(height: 24),
              ],

              // Ödenmiş faturalar
              if (paid.isNotEmpty) ...[
                const Text('Ödenmiş Faturalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                ...paid.map((inv) => _invoiceCard(inv, currencyFmt, dateFmt)),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _invoiceStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> inv, NumberFormat currencyFmt, DateFormat dateFmt) {
    final isPaid = inv['payment_status'] == 'paid';
    final isOverdue = inv['payment_status'] == 'overdue';
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final createdAt = DateTime.tryParse(inv['created_at'] as String? ?? '');
    final dueDate = inv['payment_due_date'] != null ? DateTime.tryParse(inv['payment_due_date'].toString()) : null;
    final pdfUrl = inv['pdf_url'] as String?;

    return InkWell(
      onTap: () => _showInvoiceDetail(inv, currencyFmt, dateFmt),
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverdue ? AppColors.error.withAlpha(80) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning).withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaid ? Icons.check_circle : isOverdue ? Icons.warning : Icons.schedule,
              color: isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv['invoice_number'] as String? ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  inv['invoice_period'] as String? ?? (createdAt != null ? dateFmt.format(createdAt) : '-'),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (dueDate != null && !isPaid)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Vade: ${dateFmt.format(dueDate)}',
                      style: TextStyle(fontSize: 11, color: isOverdue ? AppColors.error : AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFmt.format(total),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? 'Ödendi' : isOverdue ? 'Gecikmiş' : 'Bekliyor',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          if (pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              tooltip: 'PDF İndir',
              onPressed: () => launchUrl(Uri.parse(pdfUrl)),
            ),
          if (!isPaid)
            const SizedBox(width: 8),
          if (!isPaid)
            ElevatedButton.icon(
              onPressed: () => _payInvoice(inv),
              icon: const Icon(Icons.credit_card, size: 16),
              label: const Text('Öde'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    ),
    );
  }

  void _showInvoiceDetail(Map<String, dynamic> inv, NumberFormat currencyFmt, DateFormat dateFmt) {
    final items = (inv['invoice_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
    final kdvAmount = (inv['kdv_amount'] as num?)?.toDouble() ?? 0;
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final kdvRate = (inv['kdv_rate'] as num?)?.toDouble() ?? 20;
    final kdvPercent = kdvRate >= 1 ? kdvRate.round() : (kdvRate * 100).round();
    final isPaid = inv['payment_status'] == 'paid';
    final isOverdue = inv['payment_status'] == 'overdue';
    final createdAt = DateTime.tryParse(inv['created_at'] as String? ?? '');
    final pdfUrl = inv['pdf_url'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv['invoice_number'] as String? ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(inv['invoice_period'] as String? ?? (createdAt != null ? dateFmt.format(createdAt) : '-'), style: TextStyle(color: AppColors.textSecondary)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isPaid ? 'Ödendi' : isOverdue ? 'Gecikmiş' : 'Bekliyor',
                      style: TextStyle(fontWeight: FontWeight.w600, color: isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Kalem detayları
              if (items.isNotEmpty) ...[
                const Text('Fatura Kalemleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    // Tablo başlığı
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                      child: Row(children: [
                        const Expanded(flex: 4, child: Text('Açıklama', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Tutar', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text('Komisyon', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                      ]),
                    ),
                    ...items.map((item) {
                      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
                      final itemTotal = (item['total'] as num?)?.toDouble() ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border.withAlpha(80)))),
                        child: Row(children: [
                          Expanded(flex: 4, child: Text(item['description']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(unitPrice > 0 ? currencyFmt.format(unitPrice) : '-', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(currencyFmt.format(itemTotal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        ]),
                      );
                    }),
                  ]),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text('Fatura Detayı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
              ],

              // Toplamlar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  _detailRow('Ara Toplam', currencyFmt.format(subtotal)),
                  const SizedBox(height: 8),
                  _detailRow('KDV (%$kdvPercent)', currencyFmt.format(kdvAmount)),
                  const Divider(height: 20),
                  _detailRow('Genel Toplam', currencyFmt.format(total), bold: true, large: true),
                ]),
              ),
              const SizedBox(height: 24),

              // Aksiyonlar
              Row(children: [
                if (pdfUrl != null && pdfUrl.isNotEmpty)
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(pdfUrl)),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('PDF İndir'),
                  )),
                if (!isPaid) ...[
                  if (pdfUrl != null) const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _payInvoice(inv); },
                    icon: const Icon(Icons.credit_card, size: 18),
                    label: const Text('Kartla Öde'),
                  )),
                ],
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false, bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: large ? 16 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: large ? 18 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }

  Future<void> _payInvoice(Map<String, dynamic> inv) async {
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final invoiceNumber = inv['invoice_number'] as String? ?? '';
    final invoiceId = inv['id'] as String;
    final currentStatus = inv['payment_status'] as String?;

    // İdempotency: zaten ödenmişse Stripe çağırma
    if (currentStatus == 'paid') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu fatura zaten ödenmiş'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fatura Ödemesi'),
        content: Text(
          '$invoiceNumber numaralı faturayı kartla ödemek istiyor musunuz?\n\n'
          'Tutar: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2).format(total)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ödemeye Geç')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await activePaymentService.processPayment(
      amount: total,
      description: 'Fatura ödemesi - $invoiceNumber',
      metadata: {
        'type': 'invoice',
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
      },
    );

    if (!mounted) return;

    if (result.success) {
      // RPC ile güncelle (RLS-safe, trigger'ları tetikler)
      try {
        await Supabase.instance.client.rpc('mark_invoice_paid', params: {
          'p_invoice_id': invoiceId,
          'p_payment_method': 'card',
          'p_payment_note': 'Stripe ile ödendi',
          'p_payment_reference': result.paymentReference,
        });
      } catch (e) {
        // Webhook safety net yakalayacak
        debugPrint('mark_invoice_paid RPC failed (webhook will retry): $e');
      }

      ref.invalidate(merchantInvoicesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura başarıyla ödendi!'), backgroundColor: Colors.green),
      );
    } else if (!result.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme hatası: ${result.errorMessage}'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildOverviewTab() {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final financeStats =
        merchant != null
            ? ref.watch(
              financeStatsProvider(
                FinanceQuery(
                  merchantId: merchant.id,
                  period: _selectedPeriod,
                  merchantType: merchant.type,
                ),
              ),
            )
            : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  isDense: true,
                  items:
                      ['Bu Hafta', 'Bu Ay', 'Son 3 Ay', 'Bu Yil']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedPeriod = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Loading or Error State
          if (financeStats == null || financeStats.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (financeStats.hasError)
            Center(
              child: Text(
                'Veri yuklenirken hata olustu',
                style: TextStyle(color: AppColors.error),
              ),
            )
          else ...[
            // Summary Cards
            _buildSummaryCards(financeStats.value!),
            const SizedBox(height: 24),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Revenue Chart
                Expanded(
                  flex: 2,
                  child: _buildRevenueChart(context, financeStats.value!),
                ),
                const SizedBox(width: 24),
                // Payment Breakdown
                Expanded(
                  child: _buildPaymentBreakdown(context, financeStats.value!),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Transactions Table
            _buildTransactionsTable(context, financeStats.value!),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards(FinanceStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Toplam Gelir',
            '${stats.totalRevenue.toStringAsFixed(2)} TL',
            '+${stats.completedOrders} siparis',
            Icons.trending_up,
            AppColors.success,
            true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Komisyon Kesintisi',
            '${stats.commission.toStringAsFixed(2)} TL',
            '%${stats.commissionRate.toStringAsFixed(0)}',
            Icons.account_balance,
            AppColors.warning,
            false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Net Kazanc',
            '${stats.netRevenue.toStringAsFixed(2)} TL',
            stats.totalRevenue > 0
                ? '+${((stats.netRevenue / stats.totalRevenue) * 100).toStringAsFixed(1)}%'
                : '0%',
            Icons.account_balance_wallet,
            AppColors.primary,
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String change,
    IconData icon,
    Color color,
    bool showPercentage,
  ) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (showPercentage)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        change.startsWith('+')
                            ? AppColors.success.withAlpha(30)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    change,
                    style: TextStyle(
                      color:
                          change.startsWith('+')
                              ? AppColors.success
                              : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Text(
                  change,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context, FinanceStats stats) {
    // Gunluk verileri bar chart icin hazirla
    final sortedDays =
        stats.dailyRevenue.keys.toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    List<BarChartGroupData> barGroups = [];
    double maxY = 1000;

    for (int i = 0; i < sortedDays.length && i < 7; i++) {
      final day = sortedDays[i];
      final revenue = stats.dailyRevenue[day] ?? 0;
      final netRevenue = stats.dailyNetRevenue[day] ?? 0;

      if (revenue > maxY) maxY = revenue;

      barGroups.add(_buildBarGroup(i, revenue, netRevenue));
    }

    // Veri yoksa bos grafik
    if (barGroups.isEmpty) {
      barGroups = List.generate(7, (i) => _buildBarGroup(i, 0, 0));
    }

    maxY = ((maxY / 1000).ceil() * 1000).toDouble();
    if (maxY < 1000) maxY = 1000;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gelir Gecmisi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget:
                          (value, meta) => Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(0)}K'
                                : value.toInt().toString(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < sortedDays.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              sortedDays[value.toInt()],
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine:
                      (value) =>
                          FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppColors.primary, label: 'Gelir'),
              const SizedBox(width: 24),
              _LegendItem(color: AppColors.success, label: 'Net Kazanc'),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double revenue, double net) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: revenue,
          color: AppColors.primary,
          width: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
        BarChartRodData(
          toY: net,
          color: AppColors.success,
          width: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdown(BuildContext context, FinanceStats stats) {
    final hasData = stats.totalRevenue > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Odeme Yontemleri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          if (!hasData)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henuz veri yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    if (stats.cardPercentage > 0)
                      PieChartSectionData(
                        value: stats.cardPercentage,
                        color: AppColors.primary,
                        title: '${stats.cardPercentage.round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 40,
                      ),
                    if (stats.cashPercentage > 0)
                      PieChartSectionData(
                        value: stats.cashPercentage,
                        color: AppColors.success,
                        title: '${stats.cashPercentage.round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 40,
                      ),
                    if (stats.transferPercentage > 0)
                      PieChartSectionData(
                        value: stats.transferPercentage,
                        color: AppColors.warning,
                        title: '${stats.transferPercentage.round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 40,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _PaymentMethodItem(
              icon: Icons.credit_card,
              color: AppColors.primary,
              label: 'Kredi Karti',
              amount: '${stats.cardRevenue.toStringAsFixed(2)} TL',
            ),
            const SizedBox(height: 12),
            _PaymentMethodItem(
              icon: Icons.money,
              color: AppColors.success,
              label: 'Nakit',
              amount: '${stats.cashRevenue.toStringAsFixed(2)} TL',
            ),
            const SizedBox(height: 12),
            _PaymentMethodItem(
              icon: Icons.account_balance,
              color: AppColors.warning,
              label: 'Havale/EFT',
              amount: '${stats.transferRevenue.toStringAsFixed(2)} TL',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsTable(BuildContext context, FinanceStats stats) {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'tr');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son Islemler',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Excel Indir'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (stats.transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henuz islem yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  children: [
                    _TableHeader('Islem'),
                    _TableHeader('Tarih'),
                    _TableHeader('Tutar'),
                    _TableHeader('Durum'),
                    _TableHeader('Islem No'),
                  ],
                ),
                ...stats.transactions.map(
                  (transaction) => _buildTransactionRow(
                    transaction.description,
                    dateFormat.format(transaction.date),
                    '${transaction.isIncome ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} TL',
                    transaction.status,
                    '#${transaction.id}',
                    transaction.isIncome,
                  ),
                ),
              ],
            ),
          if (stats.transactions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Tum Islemleri Gor'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TableRow _buildTransactionRow(
    String description,
    String date,
    String amount,
    String status,
    String transactionId,
    bool isIncome,
  ) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withAlpha(100)),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      isIncome
                          ? AppColors.success.withAlpha(30)
                          : AppColors.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: isIncome ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Text(description),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(date, style: TextStyle(color: AppColors.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isIncome ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  status == 'Iptal'
                      ? AppColors.warning.withAlpha(30)
                      : AppColors.success.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color:
                    status == 'Iptal' ? AppColors.warning : AppColors.success,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            transactionId,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PaymentMethodItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String amount;

  const _PaymentMethodItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
