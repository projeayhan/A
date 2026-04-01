import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/commission_service.dart';

// ─── Sector meta ──────────────────────────────────────────────────────────────

class _SectorMeta {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _SectorMeta(this.key, this.label, this.icon, this.color);
}

const _sectors = [
  _SectorMeta('food',        'Yemek',       Icons.restaurant_rounded,    Color(0xFFF59E0B)),
  _SectorMeta('store',       'Mağaza',       Icons.storefront_rounded,    Color(0xFF3B82F6)),
  _SectorMeta('market',      'Market',       Icons.shopping_basket_rounded,Color(0xFF22C55E)),
  _SectorMeta('taxi',        'Taksi',        Icons.local_taxi_rounded,    Color(0xFF8B5CF6)),
  _SectorMeta('rental',      'Kiralama',     Icons.directions_car_rounded, Color(0xFF14B8A6)),
  _SectorMeta('car_sales',   'Galeri',       Icons.car_rental_rounded,    Color(0xFFEC4899)),
  _SectorMeta('real_estate', 'Emlak',        Icons.home_work_rounded,     Color(0xFF6366F1)),
  _SectorMeta('jobs',        'İş İlanları',  Icons.work_rounded,          Color(0xFFEF4444)),
];

// merchants.type → sector key mapping
String _merchantTypeToSector(String type) {
  switch (type) {
    case 'restaurant': return 'food';
    case 'market': return 'market';
    case 'store': return 'store';
    default: return type;
  }
}

_SectorMeta _metaOf(String key) {
  final mapped = _merchantTypeToSector(key);
  return _sectors.firstWhere(
    (s) => s.key == mapped,
    orElse: () => _SectorMeta(mapped, mapped, Icons.category_rounded, AppColors.primary),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CommissionManagementScreen extends ConsumerStatefulWidget {
  const CommissionManagementScreen({super.key});

  @override
  ConsumerState<CommissionManagementScreen> createState() =>
      _CommissionManagementScreenState();
}

class _CommissionManagementScreenState
    extends ConsumerState<CommissionManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');
  String _overrideSearch = '';

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
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Komisyon Yönetimi',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sektör oranları ve işletme bazlı özel komisyon ayarları',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: const [
                    Tab(icon: Icon(Icons.tune_rounded, size: 16), text: 'Sektör Oranları'),
                    Tab(icon: Icon(Icons.business_rounded, size: 16), text: 'İşletme Özel Oranlar'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildSectorTab(), _buildOverridesTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: Sector Rates ──────────────────────────────────────────────────

  Widget _buildSectorTab() {
    final ratesAsync = ref.watch(commissionRatesProvider);
    return ratesAsync.when(
      data: (rates) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary banner
            _buildSectorSummary(rates),
            const SizedBox(height: 24),
            // Grid cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
              ),
              itemCount: rates.length,
              itemBuilder: (_, i) => _buildSectorCard(rates[i]),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
    );
  }

  Widget _buildSectorSummary(List<CommissionRate> rates) {
    if (rates.isEmpty) return const SizedBox.shrink();
    final avgRate = rates.fold(0.0, (s, r) => s + r.rate * 100) / rates.length;
    final maxRate = rates.map((r) => r.rate * 100).reduce((a, b) => a > b ? a : b);
    final minRate = rates.map((r) => r.rate * 100).reduce((a, b) => a < b ? a : b);
    final activeCount = rates.where((r) => r.isActive).length;

    return Row(
      children: [
        _summaryChip(Icons.percent_rounded, 'Ortalama Oran', '%${avgRate.toStringAsFixed(1)}', AppColors.primary),
        const SizedBox(width: 12),
        _summaryChip(Icons.arrow_upward_rounded, 'En Yüksek', '%${maxRate.toStringAsFixed(1)}', AppColors.error),
        const SizedBox(width: 12),
        _summaryChip(Icons.arrow_downward_rounded, 'En Düşük', '%${minRate.toStringAsFixed(1)}', AppColors.success),
        const SizedBox(width: 12),
        _summaryChip(Icons.check_circle_rounded, 'Aktif Sektör', '$activeCount / ${rates.length}', AppColors.info),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorCard(CommissionRate rate) {
    final meta = _metaOf(rate.sector);
    final pct = rate.rate * 100;
    // Progress bar: 0–30% range (max commission)
    final barRatio = (pct / 30.0).clamp(0.0, 1.0);
    final barColor = pct <= 10 ? AppColors.success : pct <= 15 ? AppColors.warning : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    meta.label,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (rate.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      rate.isActive ? 'Aktif' : 'Pasif',
                      style: TextStyle(
                        color: rate.isActive ? AppColors.success : AppColors.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showEditRateDialog(rate),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            '%${pct.toStringAsFixed(1)}',
            style: TextStyle(color: barColor, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: barRatio,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          if (rate.minAmount != null || rate.maxAmount != null) ...[
            const SizedBox(height: 6),
            Text(
              '${rate.minAmount != null ? "Min ₺${rate.minAmount!.toStringAsFixed(0)}" : ""}${rate.minAmount != null && rate.maxAmount != null ? " · " : ""}${rate.maxAmount != null ? "Max ₺${rate.maxAmount!.toStringAsFixed(0)}" : ""}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  // ─── TAB 2: Merchant Overrides ────────────────────────────────────────────

  Widget _buildOverridesTab() {
    final overridesAsync = ref.watch(merchantOverridesProvider);
    return overridesAsync.when(
      data: (overrides) {
        final filtered = _overrideSearch.isEmpty
            ? overrides
            : overrides.where((o) =>
                o.merchantName.toLowerCase().contains(_overrideSearch.toLowerCase()) ||
                _metaOf(o.sector).label.toLowerCase().contains(_overrideSearch.toLowerCase())).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats + Actions row
              Row(
                children: [
                  _buildOverrideStat(
                    icon: Icons.business_rounded,
                    label: 'Özel Oran Tanımlı',
                    value: '${overrides.length} işletme',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  _buildOverrideStat(
                    icon: Icons.category_rounded,
                    label: 'Sektör Sayısı',
                    value: '${overrides.map((o) => o.sector).toSet().length} sektör',
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 12),
                  _buildOverrideStat(
                    icon: Icons.trending_down_rounded,
                    label: 'En Düşük Özel Oran',
                    value: overrides.isEmpty ? '-' : '%${(overrides.map((o) => o.rate * 100).reduce((a, b) => a < b ? a : b)).toStringAsFixed(1)}',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddOverrideDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Yeni Özel Oran'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Search bar
              TextField(
                onChanged: (v) => setState(() => _overrideSearch = v),
                decoration: InputDecoration(
                  hintText: 'İşletme adı veya sektör ile ara...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                  suffixIcon: _overrideSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () => setState(() => _overrideSearch = ''),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Table
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                overrides.isEmpty ? 'Henüz özel oran tanımlı değil' : 'Sonuç bulunamadı',
                                style: const TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Table header
                          _overrideTableHeader(),
                          const Divider(color: AppColors.surfaceLight, height: 1),
                          // Rows
                          ...filtered.map((o) => _overrideTableRow(o)),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
    );
  }

  Widget _buildOverrideStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overrideTableHeader() {
    const style = TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('İŞLETME', style: style)),
          Expanded(flex: 2, child: Text('SEKTÖR', style: style)),
          Expanded(flex: 1, child: Text('ORAN', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('NEDEN', style: style)),
          Expanded(flex: 2, child: Text('TARİH', style: style)),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _overrideTableRow(MerchantCommissionOverride o) {
    final meta = _metaOf(o.sector);
    final pct = o.rate * 100;
    final rateColor = pct <= 10 ? AppColors.success : pct <= 15 ? AppColors.warning : AppColors.error;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(meta.icon, color: meta.color, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        o.merchantName.isNotEmpty ? o.merchantName : o.merchantId,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    meta.label,
                    style: TextStyle(color: meta.color, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: rateColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '%${pct.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: rateColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  o.reason ?? '-',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _dateFormat.format(o.createdAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                  onPressed: () async {
                    final confirm = await _confirmDelete(o.merchantName.isNotEmpty ? o.merchantName : o.merchantId);
                    if (confirm && mounted) {
                      await CommissionService.deleteMerchantOverride(o.id);
                      ref.invalidate(merchantOverridesProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Özel oran silindi'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.surfaceLight, height: 1),
      ],
    );
  }

  Future<bool> _confirmDelete(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Özel Oranı Sil', style: TextStyle(color: AppColors.textPrimary)),
            content: Text(
              '"$name" için tanımlı özel oran silinecek. Devam edilsin mi?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─── DIALOGS ─────────────────────────────────────────────────────────────

  Future<void> _showEditRateDialog(CommissionRate rate) async {
    final rateCtrl = TextEditingController(text: (rate.rate * 100).toStringAsFixed(1));
    final minCtrl = TextEditingController(text: rate.minAmount?.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(text: rate.maxAmount?.toStringAsFixed(0) ?? '');
    final meta = _metaOf(rate.sector);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(meta.icon, color: meta.color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              '${meta.label} Komisyon Oranı',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Komisyon Oranı (%)',
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Tutar ₺',
                        prefixIcon: Icon(Icons.arrow_downward_rounded, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Tutar ₺',
                        prefixIcon: Icon(Icons.arrow_upward_rounded, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
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
                  rate: newRate,
                  minAmount: double.tryParse(minCtrl.text),
                  maxAmount: double.tryParse(maxCtrl.text),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(commissionRatesProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Oran güncellendi'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                  );
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
    await showDialog(
      context: context,
      builder: (ctx) => _AddOverrideDialog(
        onSaved: () {
          ref.invalidate(merchantOverridesProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Özel oran eklendi'), backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }
}

// ─── Add Override Dialog (separate StatefulWidget for clean autocomplete) ────

class _AddOverrideDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddOverrideDialog({required this.onSaved});

  @override
  State<_AddOverrideDialog> createState() => _AddOverrideDialogState();
}

class _AddOverrideDialogState extends State<_AddOverrideDialog> {
  final _rateCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _selectedSector = 'food';
  MerchantSearchResult? _selectedMerchant;
  List<MerchantSearchResult> _searchResults = [];
  bool _searching = false;
  bool _showResults = false;
  bool _saving = false;

  @override
  void dispose() {
    _rateCtrl.dispose();
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() { _searchResults = []; _showResults = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await CommissionService.searchMerchants(query);
      if (mounted) setState(() { _searchResults = results; _showResults = true; _searching = false; });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectMerchant(MerchantSearchResult m) {
    setState(() {
      _selectedMerchant = m;
      _searchCtrl.text = m.name;
      _showResults = false;
      // Auto-set sector if merchant has a type
      final mapped = _merchantTypeToSector(m.type);
      if (m.type.isNotEmpty && _sectors.any((s) => s.key == mapped)) {
        _selectedSector = mapped;
      }
    });
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rateCtrl.text);
    if (_selectedMerchant == null || rate == null) return;
    setState(() => _saving = true);
    try {
      await CommissionService.createMerchantOverride(
        merchantId: _selectedMerchant!.id,
        sector: _selectedSector,
        rate: rate,
        reason: _reasonCtrl.text.isNotEmpty ? _reasonCtrl.text : null,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedMerchant != null && _rateCtrl.text.isNotEmpty && !_saving;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_business_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Yeni Özel Oran', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Merchant search ──
            const Text(
              'İşletme',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _searchCtrl,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'İşletme adı yazın...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searching
                    ? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                    : _selectedMerchant != null
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () => setState(() { _selectedMerchant = null; _searchCtrl.clear(); _showResults = false; }),
                          )
                        : null,
              ),
            ),
            if (_showResults && _searchResults.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, _) => const Divider(color: AppColors.surfaceLight, height: 1),
                  itemBuilder: (_, i) {
                    final m = _searchResults[i];
                    final meta = _metaOf(m.type);
                    return ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(meta.icon, color: meta.color, size: 14),
                      ),
                      title: Text(m.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      subtitle: Text(meta.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      onTap: () => _selectMerchant(m),
                    );
                  },
                ),
              ),
            ] else if (_showResults && _searchResults.isEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 16),
                    SizedBox(width: 8),
                    Text('Eşleşen işletme bulunamadı', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],

            // Selected merchant chip
            if (_selectedMerchant != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMerchant!.name,
                        style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Sector ──
            const Text(
              'Sektör',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedSector,
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.category_rounded, size: 18)),
              items: _sectors.map((s) => DropdownMenuItem(
                value: s.key,
                child: Row(
                  children: [
                    Icon(s.icon, color: s.color, size: 16),
                    const SizedBox(width: 8),
                    Text(s.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  ],
                ),
              )).toList(),
              onChanged: (v) => setState(() => _selectedSector = v ?? 'food'),
            ),
            const SizedBox(height: 12),

            // ── Rate ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Komisyon Oranı (%)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _rateCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Örn: 12.5',
                          prefixIcon: Icon(Icons.percent_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Neden (opsiyonel)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _reasonCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Örn: VIP anlaşma',
                          prefixIcon: Icon(Icons.note_alt_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: canSave ? _save : null,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
