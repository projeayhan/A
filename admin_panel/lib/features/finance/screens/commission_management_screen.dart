import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/commission_service.dart';

class CommissionManagementScreen extends ConsumerStatefulWidget {
  const CommissionManagementScreen({super.key});

  @override
  ConsumerState<CommissionManagementScreen> createState() => _CommissionManagementScreenState();
}

class _CommissionManagementScreenState extends ConsumerState<CommissionManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Komisyon Yönetimi', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Sektör oranları ve işletme bazlı özel oranlar', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Sektör Oranları'),
                    Tab(text: 'İşletme Özel Oranlar'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSectorRatesTab(),
                _buildMerchantOverridesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorRatesTab() {
    final ratesAsync = ref.watch(commissionRatesProvider);
    return ratesAsync.when(
      data: (rates) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sektör Komisyon Oranları', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Oranları düzenlemek için satıra tıklayın', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              if (rates.isEmpty)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Komisyon oranı tanımlı değil', style: TextStyle(color: AppColors.textMuted))))
              else
                DataTable(
                  columns: const [
                    DataColumn(label: Text('SEKTÖR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('ORAN (%)', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('MİN TUTAR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('MAX TUTAR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('DURUM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('İŞLEM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                  rows: rates.map((r) => DataRow(cells: [
                    DataCell(Text(_sectorLabel(r.sector), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                    DataCell(Text('%${(r.rate * 100).toStringAsFixed(1)}', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(Text(r.minAmount != null ? '₺${r.minAmount!.toStringAsFixed(0)}' : '-', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    DataCell(Text(r.maxAmount != null ? '₺${r.maxAmount!.toStringAsFixed(0)}' : '-', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: (r.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(r.isActive ? 'Aktif' : 'Pasif', style: TextStyle(color: r.isActive ? AppColors.success : AppColors.error, fontSize: 12)),
                    )),
                    DataCell(IconButton(icon: const Icon(Icons.edit, size: 18, color: AppColors.primary), onPressed: () => _showEditRateDialog(r))),
                  ])).toList(),
                ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
    );
  }

  Widget _buildMerchantOverridesTab() {
    final overridesAsync = ref.watch(merchantOverridesProvider);
    return overridesAsync.when(
      data: (overrides) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('İşletme Özel Oranlar', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                  ElevatedButton.icon(
                    onPressed: _showAddOverrideDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yeni Özel Oran'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (overrides.isEmpty)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Özel oran tanımlı değil', style: TextStyle(color: AppColors.textMuted))))
              else
                DataTable(
                  columns: const [
                    DataColumn(label: Text('İŞLETME', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('SEKTÖR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('ORAN (%)', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('NEDEN', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('TARİH', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('İŞLEM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                  rows: overrides.map((o) => DataRow(cells: [
                    DataCell(Text(o.merchantName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                    DataCell(Text(_sectorLabel(o.sector), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    DataCell(Text('%${(o.rate * 100).toStringAsFixed(1)}', style: const TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: Text(o.reason ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)))),
                    DataCell(Text(_dateFormat.format(o.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
                    DataCell(IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                      onPressed: () async {
                        await CommissionService.deleteMerchantOverride(o.id);
                        ref.invalidate(merchantOverridesProvider);
                      },
                    )),
                  ])).toList(),
                ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
    );
  }

  Future<void> _showEditRateDialog(CommissionRate rate) async {
    final rateCtrl = TextEditingController(text: (rate.rate * 100).toStringAsFixed(1));
    final minCtrl = TextEditingController(text: rate.minAmount?.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(text: rate.maxAmount?.toStringAsFixed(0) ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${_sectorLabel(rate.sector)} Komisyon Oranı', style: const TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Oran (%)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Tutar (opsiyonel)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Tutar (opsiyonel)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(rateCtrl.text);
              if (newRate == null) return;
              try {
                await CommissionService.updateCommissionRate(
                  id: rate.id,
                  rate: newRate / 100,
                  minAmount: double.tryParse(minCtrl.text),
                  maxAmount: double.tryParse(maxCtrl.text),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(commissionRatesProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oran güncellendi'), backgroundColor: AppColors.success));
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

  Future<void> _showAddOverrideDialog() async {
    final merchantIdCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final sectorCtrl = ValueNotifier<String>('food');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Yeni Özel Oran', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: merchantIdCtrl, decoration: const InputDecoration(labelText: 'İşletme ID', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: sectorCtrl,
                builder: (_, val, __) => DropdownButtonFormField<String>(
                  value: val,
                  decoration: const InputDecoration(labelText: 'Sektör', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'food', child: Text('Yemek')),
                    DropdownMenuItem(value: 'store', child: Text('Market')),
                    DropdownMenuItem(value: 'taxi', child: Text('Taksi')),
                    DropdownMenuItem(value: 'rental', child: Text('Kiralama')),
                  ],
                  onChanged: (v) => sectorCtrl.value = v ?? 'food',
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Oran (%)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Neden (opsiyonel)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final rate = double.tryParse(rateCtrl.text);
              if (rate == null || merchantIdCtrl.text.isEmpty) return;
              try {
                await CommissionService.createMerchantOverride(
                  merchantId: merchantIdCtrl.text,
                  sector: sectorCtrl.value,
                  rate: rate / 100,
                  reason: reasonCtrl.text.isNotEmpty ? reasonCtrl.text : null,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(merchantOverridesProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Özel oran eklendi'), backgroundColor: AppColors.success));
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
