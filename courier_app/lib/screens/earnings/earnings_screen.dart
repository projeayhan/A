import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/earnings_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/app_theme.dart';

// Courier invoices provider
final courierInvoicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUser?.id;
  if (userId == null) return [];
  final supabase = SupabaseService.client;
  // Kuryenin couriers kaydını bul
  final courier = await supabase.from('couriers').select('id').eq('user_id', userId).maybeSingle();
  if (courier == null) return [];
  final courierId = courier['id'] as String;
  final result = await supabase
      .from('invoices')
      .select('*, invoice_items(*)')
      .or('source_id.eq.$courierId,merchant_id.eq.$courierId')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(result);
});

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> with SingleTickerProviderStateMixin {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kazançlarım'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(earningsProvider);
              ref.invalidate(earningsHistoryProvider);
              ref.invalidate(courierInvoicesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Kazanç'),
            Tab(text: 'Faturalarım'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEarningsTab(),
          _buildInvoicesTab(),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    final invoicesAsync = ref.watch(courierInvoicesProvider);
    final currencyFmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
    final dateFmt = DateFormat('dd.MM.yyyy', 'tr');

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (invoices) {
        if (invoices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: AppColors.textSecondary.withAlpha(80)),
                const SizedBox(height: 16),
                Text('Henüz fatura bulunmuyor', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Komisyon faturaları burada görünecektir', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final inv = invoices[index];
            final isPaid = inv['payment_status'] == 'paid';
            final isOverdue = inv['payment_status'] == 'overdue';
            final total = (inv['total'] as num?)?.toDouble() ?? 0;
            final createdAt = DateTime.tryParse(inv['created_at'] as String? ?? '');
            final dueDate = inv['payment_due_date'] != null ? DateTime.tryParse(inv['payment_due_date'].toString()) : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning).withAlpha(30),
                  child: Icon(
                    isPaid ? Icons.check_circle : isOverdue ? Icons.warning : Icons.schedule,
                    color: isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning,
                  ),
                ),
                title: Text(inv['invoice_number'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv['invoice_period'] as String? ?? (createdAt != null ? dateFmt.format(createdAt) : '-')),
                    if (dueDate != null && !isPaid)
                      Text('Vade: ${dateFmt.format(dueDate)}', style: TextStyle(color: isOverdue ? AppColors.error : AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currencyFmt.format(total), style: TextStyle(fontWeight: FontWeight.bold, color: isPaid ? AppColors.success : AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning).withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPaid ? 'Ödendi' : isOverdue ? 'Gecikmiş' : 'Bekliyor',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning),
                      ),
                    ),
                    if (!isPaid) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _payInvoice(inv),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.credit_card, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Öde', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () => _showInvoiceDetail(context, inv, currencyFmt, dateFmt),
              ),
            );
          },
        );
      },
    );
  }

  void _showInvoiceDetail(BuildContext context, Map<String, dynamic> inv, NumberFormat currencyFmt, DateFormat dateFmt) {
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
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(inv['invoice_number'] as String? ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(inv['invoice_period'] as String? ?? (createdAt != null ? dateFmt.format(createdAt) : '-'), style: TextStyle(color: Colors.grey[600])),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: (isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning).withAlpha(30), borderRadius: BorderRadius.circular(8)),
                  child: Text(isPaid ? 'Ödendi' : isOverdue ? 'Gecikmiş' : 'Bekliyor', style: TextStyle(fontWeight: FontWeight.w600, color: isPaid ? AppColors.success : isOverdue ? AppColors.error : AppColors.warning)),
                ),
              ]),
              const SizedBox(height: 24),
              if (items.isNotEmpty) ...[
                const Text('Fatura Kalemleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
                  final itemTotal = (item['total'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(item['description']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
                      if (unitPrice > 0) Expanded(flex: 2, child: Text(currencyFmt.format(unitPrice), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                      Expanded(flex: 2, child: Text(currencyFmt.format(itemTotal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    ]),
                  );
                }),
                const Divider(),
              ],
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Ara Toplam'), Text(currencyFmt.format(subtotal))]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('KDV (%$kdvPercent)'), Text(currencyFmt.format(kdvAmount))]),
              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Genel Toplam', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(currencyFmt.format(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                if (pdfUrl != null && pdfUrl.isNotEmpty)
                  Expanded(child: OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(pdfUrl)), icon: const Icon(Icons.download, size: 18), label: const Text('PDF İndir'))),
                if (!isPaid) ...[
                  if (pdfUrl != null) const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _payInvoice(inv); }, icon: const Icon(Icons.credit_card, size: 18), label: const Text('Kartla Öde'))),
                ],
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payInvoice(Map<String, dynamic> inv) async {
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final invoiceNumber = inv['invoice_number'] as String? ?? '';
    final invoiceId = inv['id'] as String;
    final currentStatus = inv['payment_status'] as String?;
    final currencyFmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

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
        content: Text('$invoiceNumber numaralı faturayı kartla ödemek istiyor musunuz?\n\nTutar: ${currencyFmt.format(total)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ödemeye Geç')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await StripePaymentService.instance.processPayment(
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
      try {
        await Supabase.instance.client.rpc('mark_invoice_paid', params: {
          'p_invoice_id': invoiceId,
          'p_payment_method': 'card',
          'p_payment_note': 'Stripe ile ödendi',
          'p_payment_reference': result.paymentReference,
        });
      } catch (e) {
        debugPrint('mark_invoice_paid RPC failed (webhook will retry): $e');
      }

      ref.invalidate(courierInvoicesProvider);

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

  Widget _buildEarningsTab() {
    final earningsAsync = ref.watch(earningsProvider);
    final historyAsync = ref.watch(earningsHistoryProvider);

    return RefreshIndicator(
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
            earningsAsync.when(
              data: (data) => _buildSummaryCards(context, data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _buildErrorCard(context),
            ),
            const SizedBox(height: 24),
            earningsAsync.when(
              data: (data) => _buildStatsSection(context, data),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            Text('Kazanç Geçmişi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            historyAsync.when(
              data: (history) => _buildHistoryList(context, history),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _buildErrorCard(context),
            ),
            const SizedBox(height: 32),
          ],
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
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
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
                    'Bugünkü Kazanç',
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('d MMM', 'tr').format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '₺${todayEarnings.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
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
    final deliveries = data['month_deliveries'] as int? ?? 0;
    final avgRating = (data['avg_rating'] as num?)?.toDouble() ?? 0;
    final avgDeliveryTime = data['avg_delivery_time'] as int? ?? 0;

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
            'Bu Ay İstatistikleri',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.delivery_dining,
                  deliveries.toString(),
                  'Teslimat',
                  AppColors.primary,
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
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.timer,
                  '$avgDeliveryTime dk',
                  'Ort. Süre',
                  AppColors.info,
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
              'Teslimat yaptıkça kazançlarınız burada görünecek',
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
          final date = DateTime.tryParse(item['created_at'] ?? '');
          final dateText = date != null
              ? DateFormat('d MMM, HH:mm', 'tr').format(date)
              : '—';

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
                  child: Icon(Icons.check_circle, color: AppColors.success),
                ),
                title: Text(
                  item['order_number'] ?? 'Teslimat',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  dateText,
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
