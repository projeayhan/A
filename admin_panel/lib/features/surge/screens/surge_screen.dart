import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

// Surge Zones Provider
final surgeZonesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('surge_zones').select().order('name');
  return List<Map<String, dynamic>>.from(response);
});

// Surge Rules Provider - uses surge_zones table (no separate surge_rules table exists)
// Rules are derived from surge_zones with auto_surge_enabled configuration
final surgeRulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('surge_zones')
      .select()
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class SurgeScreen extends ConsumerStatefulWidget {
  const SurgeScreen({super.key});

  @override
  ConsumerState<SurgeScreen> createState() => _SurgeScreenState();
}

class _SurgeScreenState extends ConsumerState<SurgeScreen>
    with SingleTickerProviderStateMixin {
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
    final surgeZonesAsync = ref.watch(surgeZonesProvider);
    final surgeRulesAsync = ref.watch(surgeRulesProvider);

    // Compute the highest active multiplier across all zones for the banner
    final zones = surgeZonesAsync.valueOrNull ?? [];
    final activeSurgeMultiplier = zones.isEmpty
        ? 1.0
        : zones.fold<double>(
            1.0,
            (max, z) {
              final m =
                  double.tryParse(z['current_multiplier']?.toString() ?? '1') ??
                      1.0;
              return m > max ? m : max;
            },
          );
    final activeSurgeZoneCount =
        zones.where((z) => (double.tryParse(z['current_multiplier']?.toString() ?? '1') ?? 1) > 1).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Surge Pricing Yönetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dinamik fiyatlandırma bölgelerini ve kurallarını yönetin',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(surgeZonesProvider);
                        ref.invalidate(surgeRulesProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _tabController.index == 0
                          ? () => _showSurgeZoneDialog()
                          : () => _showSurgeRuleDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: ListenableBuilder(
                        listenable: _tabController,
                        builder: (ctx, child) => Text(
                          _tabController.index == 0
                              ? 'Yeni Bölge Ekle'
                              : 'Yeni Surge Kuralı',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Active Surge Banner ───────────────────────────────────
          if (activeSurgeMultiplier > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.warning.withValues(alpha: 0.15),
                      AppColors.error.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.bolt, color: AppColors.warning, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aktif Surge: x${activeSurgeMultiplier.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$activeSurgeZoneCount bölgede yüksek fiyat uygulanıyor',
                            style: TextStyle(
                              color: AppColors.warning.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick reset button
                    OutlinedButton.icon(
                      onPressed: () => _resetAllSurge(zones),
                      icon: const Icon(Icons.stop_circle_outlined, size: 16),
                      label: const Text('Tümünü Sıfırla'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (activeSurgeMultiplier > 1) const SizedBox(height: 16),

          // ── Stats Row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: surgeZonesAsync.when(
              loading: () => const SizedBox(height: 72),
              error: (err, stack) => const SizedBox(),
              data: (zones) => Row(
                children: [
                  _buildStatCard(
                    'Toplam Bölge',
                    zones.length.toString(),
                    Icons.map,
                    AppColors.primary,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Aktif Surge',
                    zones
                        .where((z) =>
                            (double.tryParse(
                                    z['current_multiplier']?.toString() ?? '1') ??
                                1) >
                            1)
                        .length
                        .toString(),
                    Icons.trending_up,
                    AppColors.warning,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Ort. Çarpan',
                    'x${_calculateAvgMultiplier(zones).toStringAsFixed(2)}',
                    Icons.speed,
                    AppColors.info,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Toplam Talep',
                    zones
                        .fold<int>(
                          0,
                          (sum, z) => sum + ((z['current_demand'] as int?) ?? 0),
                        )
                        .toString(),
                    Icons.people,
                    AppColors.success,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Tabs ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {}),
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'Surge Bölgeleri'),
                Tab(text: 'Surge Kuralları'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Tab Content ──────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildZonesTab(surgeZonesAsync),
                _buildRulesTab(surgeRulesAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SURGE BÖLGELERİ TAB ====================
  Widget _buildZonesTab(AsyncValue<List<Map<String, dynamic>>> surgeZonesAsync) {
    return surgeZonesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (zones) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: zones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz surge bölgesi yok',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showSurgeZoneDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('İlk Bölgeyi Ekle'),
                        ),
                      ],
                    ),
                  )
                : DataTable2(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    columns: const [
                      DataColumn2(label: Text('Bölge Adı'), size: ColumnSize.M),
                      DataColumn2(label: Text('Konum'), size: ColumnSize.M),
                      DataColumn2(label: Text('Yarıçap'), size: ColumnSize.S),
                      DataColumn2(label: Text('Mevcut Çarpan'), size: ColumnSize.S),
                      DataColumn2(label: Text('Min/Maks'), size: ColumnSize.S),
                      DataColumn2(label: Text('Talep'), size: ColumnSize.S),
                      DataColumn2(label: Text('Sürücüler'), size: ColumnSize.S),
                      DataColumn2(label: Text('Oto Surge'), size: ColumnSize.S),
                      DataColumn2(label: Text('Durum'), size: ColumnSize.S),
                      DataColumn2(label: Text('İşlemler'), size: ColumnSize.M),
                    ],
                    rows: zones.map((zone) {
                      final multiplier =
                          double.tryParse(
                            zone['current_multiplier']?.toString() ?? '1',
                          ) ??
                          1;
                      return DataRow2(
                        cells: [
                          DataCell(Text(zone['name'] ?? '')),
                          DataCell(
                            Text(
                              '${zone['center_latitude']?.toStringAsFixed(4)}, '
                              '${zone['center_longitude']?.toStringAsFixed(4)}',
                            ),
                          ),
                          DataCell(Text('${zone['radius_km']} km')),
                          DataCell(_buildMultiplierBadge(multiplier)),
                          DataCell(
                            Text(
                              'x${zone['min_multiplier']} - x${zone['max_multiplier']}',
                            ),
                          ),
                          DataCell(Text('${zone['current_demand'] ?? 0}')),
                          DataCell(Text('${zone['available_drivers'] ?? 0}')),
                          DataCell(
                            Switch(
                              value: zone['auto_surge_enabled'] == true,
                              onChanged: (value) => _toggleAutoSurge(zone, value),
                              activeThumbColor: AppColors.primary,
                            ),
                          ),
                          DataCell(
                            _buildStatusBadge(zone['is_active'] == true),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showSurgeZoneDialog(zone: zone),
                                  color: AppColors.info,
                                  tooltip: 'Düzenle',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.speed, size: 18),
                                  color: AppColors.warning,
                                  onPressed: () => _showManualSurgeDialog(zone),
                                  tooltip: 'Manuel Surge',
                                ),
                                IconButton(
                                  icon: Icon(
                                    zone['is_active'] == true
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 18,
                                  ),
                                  onPressed: () => _toggleZoneStatus(zone),
                                  tooltip: zone['is_active'] == true
                                      ? 'Devre Dışı Bırak'
                                      : 'Etkinleştir',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => _confirmDeleteZone(zone),
                                  color: AppColors.error,
                                  tooltip: 'Sil',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ),
      ),
    );
  }

  // ==================== SURGE KURALLARI TAB ====================
  Widget _buildRulesTab(AsyncValue<List<Map<String, dynamic>>> surgeRulesAsync) {
    return surgeRulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_chart, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Surge kuralları yüklenemedi.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen Supabase\'de migration çalıştırın.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      data: (rules) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: rules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rule, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz surge kuralı yok',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Zaman bazlı otomatik surge için kural ekleyin',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showSurgeRuleDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('İlk Kuralı Ekle'),
                        ),
                      ],
                    ),
                  )
                : DataTable2(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    columns: const [
                      DataColumn2(label: Text('Kural Adı'), size: ColumnSize.M),
                      DataColumn2(label: Text('Servis'), size: ColumnSize.S),
                      DataColumn2(label: Text('Çarpan'), size: ColumnSize.S),
                      DataColumn2(label: Text('Tetikleyici'), size: ColumnSize.S),
                      DataColumn2(label: Text('Saat Aralığı'), size: ColumnSize.S),
                      DataColumn2(label: Text('Günler'), size: ColumnSize.M),
                      DataColumn2(label: Text('Aktif'), size: ColumnSize.S),
                      DataColumn2(label: Text('İşlemler'), size: ColumnSize.M),
                    ],
                    rows: rules.map((rule) {
                      final multiplier =
                          double.tryParse(rule['multiplier']?.toString() ?? '1') ?? 1;
                      final isActive = rule['is_active'] == true;
                      final triggerType = rule['trigger_type'] ?? 'time';
                      final days = _parseDays(rule['days_of_week']);

                      return DataRow2(
                        cells: [
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  rule['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                if ((rule['description'] ?? '').toString().isNotEmpty)
                                  Text(
                                    rule['description'],
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          DataCell(_buildServiceTypeBadge(rule['service_type'] ?? 'all')),
                          DataCell(_buildMultiplierBadge(multiplier)),
                          DataCell(_buildTriggerBadge(triggerType)),
                          DataCell(
                            triggerType == 'time'
                                ? Text(
                                    '${rule['start_time'] ?? '--'}  –  ${rule['end_time'] ?? '--'}',
                                  )
                                : Text(
                                    'Talep ≥ ${rule['demand_threshold'] ?? 0}',
                                    style: TextStyle(color: AppColors.warning),
                                  ),
                          ),
                          DataCell(
                            triggerType == 'time'
                                ? Wrap(
                                    spacing: 4,
                                    children: days
                                        .map(
                                          (d) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              d,
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  )
                                : Text(
                                    'Tüm günler',
                                    style: TextStyle(color: AppColors.textMuted),
                                  ),
                          ),
                          DataCell(
                            Switch(
                              value: isActive,
                              onChanged: (val) => _toggleRuleActive(rule, val),
                              activeThumbColor: AppColors.success,
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showSurgeRuleDialog(rule: rule),
                                  color: AppColors.info,
                                  tooltip: 'Düzenle',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => _confirmDeleteRule(rule),
                                  color: AppColors.error,
                                  tooltip: 'Sil',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ),
      ),
    );
  }

  // ==================== YARDIMCI WIDGET'LAR ====================
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplierBadge(double multiplier) {
    Color color;
    if (multiplier >= 2) {
      color = AppColors.error;
    } else if (multiplier >= 1.5) {
      color = AppColors.warning;
    } else if (multiplier > 1) {
      color = AppColors.info;
    } else {
      color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (multiplier > 1) Icon(Icons.trending_up, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'x${multiplier.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildServiceTypeBadge(String serviceType) {
    Color color;
    String label;
    switch (serviceType) {
      case 'taxi':
        color = AppColors.warning;
        label = 'Taksi';
        break;
      case 'food':
        color = AppColors.success;
        label = 'Yemek';
        break;
      case 'rental':
        color = const Color(0xFF9C27B0);
        label = 'Kiralık';
        break;
      case 'all':
      default:
        color = AppColors.primary;
        label = 'Tümü';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTriggerBadge(String triggerType) {
    final isTime = triggerType == 'time';
    final color = isTime ? AppColors.info : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTime ? Icons.access_time : Icons.people,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isTime ? 'Zaman' : 'Talep',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  List<String> _parseDays(dynamic daysOfWeek) {
    const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    if (daysOfWeek == null) return [];
    if (daysOfWeek is List) {
      return daysOfWeek.map((d) {
        final idx = (d as int?) ?? 0;
        return idx >= 0 && idx < dayNames.length ? dayNames[idx] : '';
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  double _calculateAvgMultiplier(List<Map<String, dynamic>> zones) {
    if (zones.isEmpty) return 1;
    final total = zones.fold<double>(
      0,
      (sum, z) =>
          sum + (double.tryParse(z['current_multiplier']?.toString() ?? '1') ?? 1),
    );
    return total / zones.length;
  }

  // ==================== BÖLGE DIALOG ====================
  void _showSurgeZoneDialog({Map<String, dynamic>? zone}) {
    final isEditing = zone != null;
    final nameController = TextEditingController(text: zone?['name'] ?? '');
    final latController = TextEditingController(
      text: zone?['center_latitude']?.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: zone?['center_longitude']?.toString() ?? '',
    );
    final radiusController = TextEditingController(
      text: zone?['radius_km']?.toString() ?? '5',
    );
    final minMultiplierController = TextEditingController(
      text: zone?['min_multiplier']?.toString() ?? '1',
    );
    final maxMultiplierController = TextEditingController(
      text: zone?['max_multiplier']?.toString() ?? '3',
    );
    final demandThresholdController = TextEditingController(
      text: zone?['demand_threshold']?.toString() ?? '10',
    );
    bool autoSurge = zone?['auto_surge_enabled'] ?? true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Bölgeyi Düzenle' : 'Yeni Surge Bölgesi'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Bölge Adı',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Enlem (Latitude)',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isLoading,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: lngController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Boylam (Longitude)',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isLoading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Yarıçap (km)',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minMultiplierController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min. Çarpan',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isLoading,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: maxMultiplierController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maks. Çarpan',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isLoading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: demandThresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Talep Eşiği',
                      helperText: 'Bu sayıda talebi geçince otomatik surge başlar',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Otomatik Surge'),
                    subtitle: const Text('Talebe göre otomatik fiyat ayarla'),
                    value: autoSurge,
                    onChanged: isLoading
                        ? null
                        : (value) => setDialogState(() => autoSurge = value),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Bölge adı zorunludur'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      final minMult =
                          double.tryParse(minMultiplierController.text);
                      final maxMult =
                          double.tryParse(maxMultiplierController.text);
                      if (minMult != null &&
                          maxMult != null &&
                          minMult > maxMult) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Min çarpan, maks çarpandan büyük olamaz'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final data = {
                        'name': nameController.text.trim(),
                        'center_latitude':
                            double.tryParse(latController.text),
                        'center_longitude':
                            double.tryParse(lngController.text),
                        'radius_km': double.tryParse(radiusController.text),
                        'min_multiplier': minMult,
                        'max_multiplier': maxMult,
                        'demand_threshold': int.tryParse(
                          demandThresholdController.text,
                        ),
                        'auto_surge_enabled': autoSurge,
                        'current_multiplier':
                            isEditing ? zone['current_multiplier'] : 1,
                        'is_active': true,
                      };

                      final supabase = ref.read(supabaseProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        if (isEditing) {
                          await supabase
                              .from('surge_zones')
                              .update(data)
                              .eq('id', zone['id']);
                        } else {
                          await supabase.from('surge_zones').insert(data);
                        }
                        ref.invalidate(surgeZonesProvider);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? 'Bölge güncellendi'
                                    : 'Yeni bölge oluşturuldu',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEditing ? 'Güncelle' : 'Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SURGE KURALI DİYALOG ====================
  void _showSurgeRuleDialog({Map<String, dynamic>? rule}) {
    final isEditing = rule != null;

    // Parse days_of_week from the existing rule (stored as List<int> 0=Mon..6=Sun)
    final List<bool> selectedDays = List.filled(7, false);
    if (rule?['days_of_week'] is List) {
      for (final d in (rule!['days_of_week'] as List)) {
        final idx = d as int?;
        if (idx != null && idx >= 0 && idx < 7) selectedDays[idx] = true;
      }
    }

    final nameController = TextEditingController(text: rule?['name'] ?? '');
    final descController = TextEditingController(text: rule?['description'] ?? '');
    final multiplierController = TextEditingController(
      text: rule?['multiplier']?.toString() ?? '1.5',
    );
    final demandController = TextEditingController(
      text: rule?['demand_threshold']?.toString() ?? '20',
    );
    final startTimeController =
        TextEditingController(text: rule?['start_time'] ?? '07:00');
    final endTimeController =
        TextEditingController(text: rule?['end_time'] ?? '09:00');

    String triggerType = rule?['trigger_type'] ?? 'time';
    String serviceType = rule?['service_type'] ?? 'all';
    bool isActive = rule?['is_active'] ?? true;
    bool isLoading = false;

    const dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Surge Kuralını Düzenle' : 'Yeni Surge Kuralı'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Kural Adı',
                      hintText: 'örn: Sabah Yoğun Saati',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama (opsiyonel)',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 20),

                  // Multiplier + Service Type row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Çarpan (1.0 – 5.0)',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: multiplierController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                prefixText: 'x',
                                border: OutlineInputBorder(),
                              ),
                              enabled: !isLoading,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Servis Tipi',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.surfaceLight),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: serviceType,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surface,
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('Tümü')),
                                    DropdownMenuItem(
                                        value: 'taxi', child: Text('Taksi')),
                                    DropdownMenuItem(
                                        value: 'food', child: Text('Yemek')),
                                    DropdownMenuItem(
                                        value: 'rental', child: Text('Kiralık Araç')),
                                  ],
                                  onChanged: isLoading
                                      ? null
                                      : (val) =>
                                          setDialogState(() => serviceType = val!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Trigger type toggle
                  Text(
                    'Tetikleyici Koşul',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => setDialogState(() => triggerType = 'time'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: triggerType == 'time'
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: triggerType == 'time'
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Zaman Bazlı',
                                    style: TextStyle(
                                      color: triggerType == 'time'
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => setDialogState(() => triggerType = 'demand'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: triggerType == 'demand'
                                    ? AppColors.warning
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 16,
                                    color: triggerType == 'demand'
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Talep Bazlı',
                                    style: TextStyle(
                                      color: triggerType == 'demand'
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Conditional fields based on trigger type
                  if (triggerType == 'time') ...[
                    // Time range
                    Text(
                      'Saat Aralığı',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Başlangıç',
                              hintText: '07:00',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !isLoading,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward,
                              color: AppColors.textMuted, size: 20),
                        ),
                        Expanded(
                          child: TextField(
                            controller: endTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Bitiş',
                              hintText: '09:00',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !isLoading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Day of week selection
                    Text(
                      'Haftanın Günleri',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(7, (i) {
                        return Expanded(
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => setDialogState(
                                      () => selectedDays[i] = !selectedDays[i],
                                    ),
                            child: Container(
                              margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedDays[i]
                                    ? AppColors.primary
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedDays[i]
                                      ? AppColors.primary
                                      : AppColors.surfaceLight,
                                ),
                              ),
                              child: Text(
                                dayLabels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selectedDays[i]
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],

                  if (triggerType == 'demand') ...[
                    Text(
                      'Talep Eşiği',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: demandController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Aktif Talep Sayısı',
                        helperText: 'Bu sayıyı aştığında surge otomatik devreye girer',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !isLoading,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Active toggle
                  SwitchListTile(
                    title: const Text('Kuralı Aktif Et'),
                    subtitle: const Text('Kural şu anda uygulanıyor'),
                    value: isActive,
                    onChanged: isLoading
                        ? null
                        : (val) => setDialogState(() => isActive = val),
                    activeThumbColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Validation
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Kural adı boş olamaz'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      final mult =
                          double.tryParse(multiplierController.text) ?? 1.5;
                      if (mult < 1.0 || mult > 5.0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Çarpan 1.0 ile 5.0 arasında olmalıdır'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      if (triggerType == 'time') {
                        final hasDay = selectedDays.any((d) => d);
                        if (!hasDay) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('En az bir gün seçmelisiniz'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                      }

                      setDialogState(() => isLoading = true);

                      // Map rule dialog fields to surge_zones columns
                      final data = <String, dynamic>{
                        'name': nameController.text.trim(),
                        'current_multiplier': mult,
                        'min_multiplier': 1.0,
                        'max_multiplier': mult > 3.0 ? mult : 3.0,
                        'demand_threshold':
                            int.tryParse(demandController.text) ?? 20,
                        'auto_surge_enabled': triggerType == 'demand',
                        'is_active': isActive,
                        'updated_at': DateTime.now().toIso8601String(),
                      };

                      if (!isEditing) {
                        data['created_at'] = DateTime.now().toIso8601String();
                        data['center_latitude'] = 0.0;
                        data['center_longitude'] = 0.0;
                        data['radius_km'] = 5.0;
                        data['current_demand'] = 0;
                        data['available_drivers'] = 0;
                      }

                      try {
                        final supabase = ref.read(supabaseProvider);
                        if (isEditing) {
                          await supabase
                              .from('surge_zones')
                              .update(data)
                              .eq('id', rule['id']);
                        } else {
                          await supabase.from('surge_zones').insert(data);
                        }
                        ref.invalidate(surgeRulesProvider);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? 'Surge kuralı güncellendi'
                                    : 'Yeni surge kuralı oluşturuldu',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEditing ? 'Güncelle' : 'Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MANUEL SURGE DİYALOG ====================
  void _showManualSurgeDialog(Map<String, dynamic> zone) {
    double multiplier =
        double.tryParse(zone['current_multiplier']?.toString() ?? '1') ?? 1;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manuel Surge: ${zone['name']}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Surge çarpanını ayarlayın'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (multiplier > 1) {
                          setDialogState(() => multiplier -= 0.1);
                        }
                      },
                      icon: const Icon(Icons.remove_circle, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'x${multiplier.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {
                        final max =
                            double.tryParse(
                              zone['max_multiplier']?.toString() ?? '3',
                            ) ??
                            3;
                        if (multiplier < max) {
                          setDialogState(() => multiplier += 0.1);
                        }
                      },
                      icon: const Icon(Icons.add_circle, size: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Slider(
                  value: multiplier,
                  min: 1,
                  max:
                      double.tryParse(
                        zone['max_multiplier']?.toString() ?? '3',
                      ) ??
                      3,
                  divisions: 20,
                  label: 'x${multiplier.toStringAsFixed(2)}',
                  onChanged: (value) => setDialogState(() => multiplier = value),
                  activeColor: AppColors.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  _getSurgePriceExample(multiplier),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            OutlinedButton(
              onPressed: () async {
                final supabase = ref.read(supabaseProvider);
                await supabase
                    .from('surge_zones')
                    .update({'current_multiplier': 1})
                    .eq('id', zone['id']);
                ref.invalidate(surgeZonesProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Surge Kapat'),
            ),
            ElevatedButton(
              onPressed: () async {
                final supabase = ref.read(supabaseProvider);
                await supabase
                    .from('surge_zones')
                    .update({'current_multiplier': multiplier})
                    .eq('id', zone['id']);
                ref.invalidate(surgeZonesProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SİLME ONAYLAMA ====================
  void _confirmDeleteZone(Map<String, dynamic> zone) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bölgeyi Sil'),
        content: Text(
          '"${zone['name']}" surge bölgesini silmek istediğinize emin misiniz?\n\n'
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final supabase = ref.read(supabaseProvider);
                await supabase.from('surge_zones').delete().eq('id', zone['id']);
                ref.invalidate(surgeZonesProvider);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bölge silindi'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRule(Map<String, dynamic> rule) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Surge Kuralını Sil'),
        content: Text(
          '"${rule['name']}" surge kuralını silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final supabase = ref.read(supabaseProvider);
                await supabase.from('surge_zones').delete().eq('id', rule['id']);
                ref.invalidate(surgeRulesProvider);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Surge kuralı silindi'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ==================== DURUM DEĞİŞTİRME ====================
  Future<void> _toggleAutoSurge(Map<String, dynamic> zone, bool value) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('surge_zones')
          .update({'auto_surge_enabled': value})
          .eq('id', zone['id']);
      ref.invalidate(surgeZonesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _toggleZoneStatus(Map<String, dynamic> zone) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('surge_zones')
          .update({'is_active': !(zone['is_active'] == true)})
          .eq('id', zone['id']);
      ref.invalidate(surgeZonesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _toggleRuleActive(Map<String, dynamic> rule, bool value) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('surge_zones')
          .update({'is_active': value})
          .eq('id', rule['id']);
      ref.invalidate(surgeRulesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _resetAllSurge(List<Map<String, dynamic>> zones) async {
    final activeSurgeZones =
        zones.where((z) =>
            (double.tryParse(z['current_multiplier']?.toString() ?? '1') ?? 1) > 1).toList();

    if (activeSurgeZones.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tüm Surge\'leri Sıfırla'),
        content: Text(
          '${activeSurgeZones.length} aktif bölgedeki surge çarpanları 1.0\'a sıfırlanacak. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      for (final zone in activeSurgeZones) {
        await supabase
            .from('surge_zones')
            .update({'current_multiplier': 1.0})
            .eq('id', zone['id']);
      }
      ref.invalidate(surgeZonesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${activeSurgeZones.length} bölgedeki surge sıfırlandı',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _getSurgePriceExample(double multiplier) {
    const basePrice = 50.0;
    final surgedPrice = basePrice * multiplier;
    return 'Örnek: 50 TL yolculuk → ${surgedPrice.toStringAsFixed(2)} TL olur';
  }
}
