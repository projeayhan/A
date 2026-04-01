import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

// Vehicle Types Provider - taxi_pricing ile birlikte getir
final vehicleTypesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('vehicle_types')
      .select('*, taxi_pricing(*)')
      .order('sort_order');
  return List<Map<String, dynamic>>.from(response);
});

// Taxi Pricing Provider
final taxiPricingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('taxi_pricing')
      .select('*, vehicle_types(*)')
      .order('created_at');
  return List<Map<String, dynamic>>.from(response);
});

// Delivery Pricing Provider
final deliveryPricingProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('delivery_pricing')
      .select()
      .eq('is_active', true)
      .limit(1)
      .maybeSingle();
  return response;
});

// Platform Commissions Provider
final platformCommissionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('platform_commissions').select().order('service_type');
  return List<Map<String, dynamic>>.from(response);
});

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Taksi fiyatlandırma değişiklikleri için state
  final Map<String, Map<String, dynamic>> _taxiPricingChanges = {};
  bool _hasTaxiPricingChanges = false;
  bool _isSavingTaxiPricing = false;

  // Kurye fiyatlandırma değişiklikleri için state
  final Map<String, dynamic> _deliveryPricingChanges = {};
  bool _hasDeliveryPricingChanges = false;
  bool _isSavingDeliveryPricing = false;
  String? _currentDeliveryPricingId;

  // Komisyon değişiklikleri için state
  final Map<String, Map<String, dynamic>> _commissionChanges = {};
  bool _hasCommissionChanges = false;
  bool _isSavingCommissions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
                      'Fiyatlandırma Yönetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Taksi, kurye fiyatlarını ve platform komisyonlarını yönetin',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.invalidate(vehicleTypesProvider);
                    ref.invalidate(taxiPricingProvider);
                    ref.invalidate(deliveryPricingProvider);
                    ref.invalidate(platformCommissionsProvider);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yenile'),
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
                Tab(text: 'Araç Tipleri'),
                Tab(text: 'Taksi Ücretleri'),
                Tab(text: 'Kurye Ücretleri'),
                Tab(text: 'Komisyonlar'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVehicleTypesTab(),
                _buildTaxiPricingTab(),
                _buildCourierPricingTab(),
                _buildCommissionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ARAÇ TİPLERİ TAB ====================
  Widget _buildVehicleTypesTab() {
    final vehicleTypesAsync = ref.watch(vehicleTypesProvider);

    return vehicleTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (vehicleTypes) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showVehicleTypeDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Araç Tipi'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DataTable2(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    columns: const [
                      DataColumn2(label: Text('Tip'), size: ColumnSize.S),
                      DataColumn2(label: Text('Görünen Ad'), size: ColumnSize.M),
                      DataColumn2(label: Text('Açılış'), size: ColumnSize.S),
                      DataColumn2(label: Text('KM'), size: ColumnSize.S),
                      DataColumn2(label: Text('Dakika'), size: ColumnSize.S),
                      DataColumn2(label: Text('Min.'), size: ColumnSize.S),
                      DataColumn2(label: Text('Kapasite'), size: ColumnSize.S),
                      DataColumn2(label: Text('Durum'), size: ColumnSize.S),
                      DataColumn2(label: Text('İşlem'), size: ColumnSize.M),
                    ],
                    rows: vehicleTypes.map((vt) {
                      // taxi_pricing tablosundan fiyatları al
                      final pricing = vt['taxi_pricing'];
                      final pricingData = pricing is List && pricing.isNotEmpty
                          ? pricing.first
                          : (pricing is Map ? pricing : null);

                      final baseFare = pricingData?['base_fare'] ?? vt['default_base_fare'] ?? 0;
                      final perKm = pricingData?['per_km_fare'] ?? vt['default_per_km'] ?? 0;
                      final perMinute = pricingData?['per_minute_fare'] ?? vt['default_per_minute'] ?? 0;
                      final minFare = pricingData?['minimum_fare'] ?? vt['default_minimum_fare'] ?? 0;

                      return DataRow2(
                        cells: [
                          DataCell(Text(vt['name'] ?? '')),
                          DataCell(Text(vt['display_name'] ?? '')),
                          DataCell(Text('$baseFare TL')),
                          DataCell(Text('$perKm TL')),
                          DataCell(Text('$perMinute TL')),
                          DataCell(Text('$minFare TL')),
                          DataCell(Text('${vt['capacity']} kişi')),
                          DataCell(_buildStatusBadge(vt['is_active'] == true)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showVehicleTypeDialog(vehicleType: vt),
                                  color: AppColors.info,
                                  tooltip: 'Düzenle',
                                ),
                                IconButton(
                                  icon: Icon(
                                    vt['is_active'] == true ? Icons.pause : Icons.play_arrow,
                                    size: 18,
                                  ),
                                  onPressed: () => _toggleVehicleTypeStatus(vt),
                                  tooltip: vt['is_active'] == true ? 'Devre Dışı Bırak' : 'Etkinleştir',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => _confirmDeleteVehicleType(vt),
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
          ],
        ),
      ),
    );
  }

  // ==================== TAKSİ ÜCRETLERİ TAB ====================
  Widget _buildTaxiPricingTab() {
    final taxiPricingAsync = ref.watch(taxiPricingProvider);

    return taxiPricingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (pricingList) => Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Taksi ücretleri araç tipine göre belirlenir. Her araç tipi için farklı fiyatlandırma ayarlayabilirsiniz.\n'
                          'Hesaplama: Açılış Ücreti + (Mesafe x KM Ücreti) + (Süre x Dakika Ücreti)',
                          style: TextStyle(color: AppColors.info, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Pricing cards for each vehicle type
                ...pricingList.map((pricing) => _buildTaxiPricingCard(pricing)),

                if (pricingList.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.local_taxi, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'Taksi fiyatlandırması bulunamadı.\nÖnce araç tipleri ekleyin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Kaydet butonu için boşluk
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Sabit Kaydet Butonu
          if (pricingList.isNotEmpty && _hasTaxiPricingChanges)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_taxiPricingChanges.length} araç tipinde değişiklik var',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _discardTaxiPricingChanges,
                      child: const Text('Vazgeç'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSavingTaxiPricing ? null : _saveAllTaxiPricingChanges,
                      icon: _isSavingTaxiPricing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSavingTaxiPricing ? 'Kaydediliyor...' : 'Tüm Değişiklikleri Kaydet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaxiPricingCard(Map<String, dynamic> pricing) {
    final vt = pricing['vehicle_types'];
    final vehicleName = vt?['display_name'] ?? 'Bilinmeyen';
    final pricingId = pricing['id']?.toString() ?? '';

    // Değişiklik varsa onu kullan, yoksa orijinal değeri kullan
    Map<String, dynamic> getCurrentValue(String field) {
      if (_taxiPricingChanges.containsKey(pricingId) &&
          _taxiPricingChanges[pricingId]!.containsKey(field)) {
        return {'value': _taxiPricingChanges[pricingId]![field], 'changed': true};
      }
      return {'value': pricing[field], 'changed': false};
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_taxi, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicleName, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Kapasite: ${vt?['capacity'] ?? 4} kişi',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                if (_taxiPricingChanges.containsKey(pricingId))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Değiştirildi',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                _buildStatusBadge(pricing['is_active'] == true),
                const SizedBox(width: 8),
                // Delete button for taxi pricing record
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _confirmDeleteTaxiPricing(pricing),
                  color: AppColors.error,
                  tooltip: 'Bu Fiyat Kaydını Sil',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pricing fields
            Row(
              children: [
                Expanded(
                  child: _buildTaxiPriceFieldNew(
                    'Açılış Ücreti',
                    getCurrentValue('base_fare'),
                    'TL',
                    'base_fare',
                    pricingId,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTaxiPriceFieldNew(
                    'KM Başına',
                    getCurrentValue('per_km_fare'),
                    'TL',
                    'per_km_fare',
                    pricingId,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTaxiPriceFieldNew(
                    'Dakika Başına',
                    getCurrentValue('per_minute_fare'),
                    'TL',
                    'per_minute_fare',
                    pricingId,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTaxiPriceFieldNew(
                    'Minimum Ücret',
                    getCurrentValue('minimum_fare'),
                    'TL',
                    'minimum_fare',
                    pricingId,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Surge & Gece Tarifeleri
            Row(
              children: [
                // Surge (Yoğun Saat) Tarifesi
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.trending_up, color: AppColors.warning, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Yoğun Saat Tarifesi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTaxiPriceFieldNew(
                          'Surge Çarpanı',
                          getCurrentValue('surge_multiplier'),
                          'x',
                          'surge_multiplier',
                          pricingId,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTaxiTimeFieldNew(
                                'Sabah',
                                getCurrentValue('surge_start_hour_1'),
                                getCurrentValue('surge_end_hour_1'),
                                pricingId,
                                'surge_start_hour_1',
                                'surge_end_hour_1',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTaxiTimeFieldNew(
                                'Akşam',
                                getCurrentValue('surge_start_hour_2'),
                                getCurrentValue('surge_end_hour_2'),
                                pricingId,
                                'surge_start_hour_2',
                                'surge_end_hour_2',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yoğun saatlerde fiyatlar otomatik '
                          '${((getCurrentValue('surge_multiplier')['value'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(1)}x ile çarpılır',
                          style: TextStyle(color: AppColors.warning, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Gece Tarifesi
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.nightlight_round, color: AppColors.info, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Gece Tarifesi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTaxiPriceFieldNew(
                          'Gece Çarpanı',
                          getCurrentValue('night_multiplier'),
                          'x',
                          'night_multiplier',
                          pricingId,
                        ),
                        const SizedBox(height: 12),
                        _buildTaxiTimeFieldNew(
                          'Gece Saatleri',
                          getCurrentValue('night_start_hour'),
                          getCurrentValue('night_end_hour'),
                          pricingId,
                          'night_start_hour',
                          'night_end_hour',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gece ${getCurrentValue('night_start_hour')['value'] ?? 0}:00 - '
                          '${getCurrentValue('night_end_hour')['value'] ?? 6}:00 arası '
                          '${((getCurrentValue('night_multiplier')['value'] as num?)?.toDouble() ?? 1.5).toStringAsFixed(1)}x tarife uygulanır',
                          style: TextStyle(color: AppColors.info, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Example calculation - güncel değerleri kullan
            _buildTaxiCalculationExampleNew(pricingId, pricing),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxiPriceFieldNew(
    String label,
    Map<String, dynamic> valueData,
    String unit,
    String field,
    String pricingId,
  ) {
    final value = valueData['value'];
    final isChanged = valueData['changed'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value?.toString() ?? '0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: isChanged,
            fillColor: isChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isChanged ? AppColors.warning : AppColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isChanged ? AppColors.warning : AppColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
          ),
          onChanged: (newValue) => _onTaxiPricingFieldChanged(pricingId, field, newValue),
        ),
      ],
    );
  }

  Widget _buildTaxiTimeFieldNew(
    String label,
    Map<String, dynamic> startData,
    Map<String, dynamic> endData,
    String pricingId,
    String startField,
    String endField,
  ) {
    final startValue = startData['value'];
    final endValue = endData['value'];
    final isStartChanged = startData['changed'] == true;
    final isEndChanged = endData['changed'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: startValue?.toString() ?? '0',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Başlangıç',
                  suffixText: ':00',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  filled: isStartChanged,
                  fillColor: isStartChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
                ),
                onChanged: (val) => _onTaxiPricingFieldChanged(pricingId, startField, val),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-'),
            ),
            Expanded(
              child: TextFormField(
                initialValue: endValue?.toString() ?? '0',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Bitiş',
                  suffixText: ':00',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  filled: isEndChanged,
                  fillColor: isEndChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
                ),
                onChanged: (val) => _onTaxiPricingFieldChanged(pricingId, endField, val),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onTaxiPricingFieldChanged(String pricingId, String field, String value) {
    setState(() {
      if (!_taxiPricingChanges.containsKey(pricingId)) {
        _taxiPricingChanges[pricingId] = {};
      }
      _taxiPricingChanges[pricingId]![field] = num.tryParse(value) ?? 0;
      _hasTaxiPricingChanges = _taxiPricingChanges.isNotEmpty;
    });
  }

  void _discardTaxiPricingChanges() {
    setState(() {
      _taxiPricingChanges.clear();
      _hasTaxiPricingChanges = false;
    });
    ref.invalidate(taxiPricingProvider);
    ref.invalidate(vehicleTypesProvider);
  }

  Future<void> _saveAllTaxiPricingChanges() async {
    if (_taxiPricingChanges.isEmpty) return;

    setState(() => _isSavingTaxiPricing = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final taxiPricingData = ref.read(taxiPricingProvider).valueOrNull ?? [];

      for (final entry in _taxiPricingChanges.entries) {
        final pricingId = entry.key;
        final changes = Map<String, dynamic>.from(entry.value);

        if (changes.isNotEmpty) {
          changes['updated_at'] = DateTime.now().toIso8601String();
          await supabase.from('taxi_pricing').update(changes).eq('id', pricingId);

          final pricingRecord = taxiPricingData.firstWhere(
            (p) => p['id']?.toString() == pricingId,
            orElse: () => {},
          );
          final vehicleTypeId = pricingRecord['vehicle_type_id'];

          if (vehicleTypeId != null) {
            final vehicleTypeChanges = <String, dynamic>{};
            if (changes.containsKey('base_fare')) {
              vehicleTypeChanges['default_base_fare'] = changes['base_fare'];
            }
            if (changes.containsKey('per_km_fare')) {
              vehicleTypeChanges['default_per_km'] = changes['per_km_fare'];
            }
            if (changes.containsKey('per_minute_fare')) {
              vehicleTypeChanges['default_per_minute'] = changes['per_minute_fare'];
            }
            if (changes.containsKey('minimum_fare')) {
              vehicleTypeChanges['default_minimum_fare'] = changes['minimum_fare'];
            }

            if (vehicleTypeChanges.isNotEmpty) {
              await supabase
                  .from('vehicle_types')
                  .update(vehicleTypeChanges)
                  .eq('id', vehicleTypeId);
            }
          }
        }
      }

      setState(() {
        _taxiPricingChanges.clear();
        _hasTaxiPricingChanges = false;
        _isSavingTaxiPricing = false;
      });

      ref.invalidate(taxiPricingProvider);
      ref.invalidate(vehicleTypesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm taksi fiyatlandırmaları başarıyla kaydedildi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _isSavingTaxiPricing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildTaxiCalculationExampleNew(
    String pricingId,
    Map<String, dynamic> originalPricing,
  ) {
    dynamic getValue(String field) {
      if (_taxiPricingChanges.containsKey(pricingId) &&
          _taxiPricingChanges[pricingId]!.containsKey(field)) {
        return _taxiPricingChanges[pricingId]![field];
      }
      return originalPricing[field];
    }

    final baseFare = (getValue('base_fare') as num?)?.toDouble() ?? 35.0;
    final perKm = (getValue('per_km_fare') as num?)?.toDouble() ?? 7.5;
    final perMin = (getValue('per_minute_fare') as num?)?.toDouble() ?? 1.2;
    final minFare = (getValue('minimum_fare') as num?)?.toDouble() ?? 50.0;
    final nightMultiplier = (getValue('night_multiplier') as num?)?.toDouble() ?? 1.5;
    final surgeMultiplier = (getValue('surge_multiplier') as num?)?.toDouble() ?? 1.0;

    double normalTotal = baseFare + (5 * perKm) + (15 * perMin);
    normalTotal = normalTotal < minFare ? minFare : normalTotal;
    double nightTotal = normalTotal * nightMultiplier;
    double surgeTotal = normalTotal * surgeMultiplier;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                'Hesaplama Örnekleri (5 km, 15 dk)',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          const Text(
                            'Normal',
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${normalTotal.toStringAsFixed(2)} TL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, size: 16, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Text(
                            'Yoğun Saat (x$surgeMultiplier)',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${surgeTotal.toStringAsFixed(2)} TL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.nightlight_round, size: 16, color: AppColors.info),
                          const SizedBox(width: 6),
                          Text(
                            'Gece (x$nightMultiplier)',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${nightTotal.toStringAsFixed(2)} TL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Formül: $baseFare TL (açılış) + (5 km x $perKm TL) + (15 dk x $perMin TL) = ${normalTotal.toStringAsFixed(2)} TL',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==================== KURYE ÜCRETLERİ TAB ====================
  Widget _buildCourierPricingTab() {
    final pricingAsync = ref.watch(deliveryPricingProvider);

    return pricingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (pricing) {
        if (pricing != null && _currentDeliveryPricingId == null) {
          _currentDeliveryPricingId = pricing['id']?.toString();
        }

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Platform kuryelerinin teslimat ücretleri mesafeye göre hesaplanır.\n'
                            'Müşteriye yansıyacak ücret = Baz Ücret + (Mesafe x KM Ücreti) x Çarpanlar',
                            style: TextStyle(color: AppColors.info, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Basic pricing
                  Text('Temel Ücretler', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDeliveryPricingCardNew(
                          'Baz Ücret',
                          pricing,
                          'base_fee',
                          'TL',
                          Icons.delivery_dining,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDeliveryPricingCardNew(
                          'KM Başına',
                          pricing,
                          'per_km_fee',
                          'TL',
                          Icons.straighten,
                          AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDeliveryPricingCardNew(
                          'Min. Ücret',
                          pricing,
                          'min_fee',
                          'TL',
                          Icons.arrow_downward,
                          AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDeliveryPricingCardNew(
                          'Maks. Ücret',
                          pricing,
                          'max_fee',
                          'TL',
                          Icons.arrow_upward,
                          AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Distance tiers
                  Text('Mesafe Kademeleri', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Farklı mesafe aralıkları için sabit ücretler belirleyebilirsiniz',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTierCardNew(
                          'Kademe 1',
                          '0 - ${_getDeliveryValue(pricing, 'tier_1_km') ?? 3} km',
                          pricing,
                          'tier_1_fee',
                          AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTierCardNew(
                          'Kademe 2',
                          '${_getDeliveryValue(pricing, 'tier_1_km') ?? 3} - ${_getDeliveryValue(pricing, 'tier_2_km') ?? 7} km',
                          pricing,
                          'tier_2_fee',
                          AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTierCardNew(
                          'Kademe 3',
                          '${_getDeliveryValue(pricing, 'tier_2_km') ?? 7} - ${_getDeliveryValue(pricing, 'tier_3_km') ?? 15} km',
                          pricing,
                          'tier_3_fee',
                          AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTierCardNew(
                          '15+ km',
                          'Her ek km için',
                          pricing,
                          'extra_km_fee',
                          AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Multipliers
                  Text('Çarpanlar', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.trending_up, color: AppColors.warning),
                                    const SizedBox(width: 8),
                                    const Text('Surge (Yoğun Saat)'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDeliveryMultiplierFieldNew(
                                  'Surge Çarpanı',
                                  pricing,
                                  'surge_multiplier',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDeliveryTimeFieldNew(
                                        'Öğle',
                                        pricing,
                                        'surge_start_hour',
                                        'surge_end_hour',
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildDeliveryTimeFieldNew(
                                        'Akşam',
                                        pricing,
                                        'evening_surge_start',
                                        'evening_surge_end',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.nightlight, color: AppColors.info),
                                    const SizedBox(width: 8),
                                    const Text('Gece Tarifesi'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDeliveryMultiplierFieldNew(
                                  'Gece Çarpanı',
                                  pricing,
                                  'night_multiplier',
                                ),
                                const SizedBox(height: 12),
                                _buildDeliveryTimeFieldNew(
                                  'Gece Saatleri',
                                  pricing,
                                  'night_start_hour',
                                  'night_end_hour',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.cloud, color: AppColors.textMuted),
                                    const SizedBox(width: 8),
                                    const Text('Kötü Hava'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDeliveryMultiplierFieldNew(
                                  'Hava Çarpanı',
                                  pricing,
                                  'bad_weather_multiplier',
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Yağmur, kar gibi kötü hava koşullarında otomatik uygulanır',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _buildCourierCalculationExampleNew(pricing),
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // Sabit Kaydet Butonu
            if (_hasDeliveryPricingChanges)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_deliveryPricingChanges.length} alanda değişiklik var',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: _discardDeliveryPricingChanges,
                        child: const Text('Vazgeç'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed:
                            _isSavingDeliveryPricing ? null : _saveAllDeliveryPricingChanges,
                        icon: _isSavingDeliveryPricing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSavingDeliveryPricing
                              ? 'Kaydediliyor...'
                              : 'Tüm Değişiklikleri Kaydet',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  dynamic _getDeliveryValue(Map<String, dynamic>? pricing, String field) {
    if (_deliveryPricingChanges.containsKey(field)) {
      return _deliveryPricingChanges[field];
    }
    return pricing?[field];
  }

  Widget _buildDeliveryPricingCardNew(
    String title,
    Map<String, dynamic>? pricing,
    String field,
    String unit,
    IconData icon,
    Color color,
  ) {
    final value = _getDeliveryValue(pricing, field);
    final isChanged = _deliveryPricingChanges.containsKey(field);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleSmall),
                ),
                if (isChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '*',
                      style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: value?.toString() ?? '0',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: unit,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: isChanged,
                fillColor: isChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
              ),
              onChanged: (val) => _onDeliveryPricingFieldChanged(field, val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCardNew(
    String title,
    String range,
    Map<String, dynamic>? pricing,
    String field,
    Color color,
  ) {
    final value = _getDeliveryValue(pricing, field);
    final isChanged = _deliveryPricingChanges.containsKey(field);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (isChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '*',
                      style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(range, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: value?.toString() ?? '0',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: 'TL',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: isChanged,
                fillColor: isChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
              ),
              onChanged: (val) => _onDeliveryPricingFieldChanged(field, val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryMultiplierFieldNew(
    String label,
    Map<String, dynamic>? pricing,
    String field,
  ) {
    final value = _getDeliveryValue(pricing, field);
    final isChanged = _deliveryPricingChanges.containsKey(field);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        Expanded(
          child: TextFormField(
            initialValue: value?.toString() ?? '1.0',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: 'x',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              filled: isChanged,
              fillColor: isChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
            ),
            onChanged: (val) => _onDeliveryPricingFieldChanged(field, val),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryTimeFieldNew(
    String label,
    Map<String, dynamic>? pricing,
    String startField,
    String endField,
  ) {
    final startValue = _getDeliveryValue(pricing, startField);
    final endValue = _getDeliveryValue(pricing, endField);
    final isStartChanged = _deliveryPricingChanges.containsKey(startField);
    final isEndChanged = _deliveryPricingChanges.containsKey(endField);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: startValue?.toString() ?? '0',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: ':00',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  filled: isStartChanged,
                  fillColor: isStartChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
                ),
                onChanged: (val) => _onDeliveryPricingFieldChanged(startField, val),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-'),
            ),
            Expanded(
              child: TextFormField(
                initialValue: endValue?.toString() ?? '0',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: ':00',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  filled: isEndChanged,
                  fillColor: isEndChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
                ),
                onChanged: (val) => _onDeliveryPricingFieldChanged(endField, val),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onDeliveryPricingFieldChanged(String field, String value) {
    setState(() {
      _deliveryPricingChanges[field] = num.tryParse(value) ?? 0;
      _hasDeliveryPricingChanges = _deliveryPricingChanges.isNotEmpty;
    });
  }

  void _discardDeliveryPricingChanges() {
    setState(() {
      _deliveryPricingChanges.clear();
      _hasDeliveryPricingChanges = false;
    });
    ref.invalidate(deliveryPricingProvider);
  }

  Future<void> _saveAllDeliveryPricingChanges() async {
    if (_deliveryPricingChanges.isEmpty || _currentDeliveryPricingId == null) return;

    setState(() => _isSavingDeliveryPricing = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final changes = Map<String, dynamic>.from(_deliveryPricingChanges);
      changes['updated_at'] = DateTime.now().toIso8601String();

      await supabase
          .from('delivery_pricing')
          .update(changes)
          .eq('id', _currentDeliveryPricingId!);

      setState(() {
        _deliveryPricingChanges.clear();
        _hasDeliveryPricingChanges = false;
        _isSavingDeliveryPricing = false;
      });

      ref.invalidate(deliveryPricingProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kurye fiyatlandırmaları başarıyla kaydedildi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _isSavingDeliveryPricing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildCourierCalculationExampleNew(Map<String, dynamic>? pricing) {
    final baseFee =
        (_getDeliveryValue(pricing, 'base_fee') as num?)?.toDouble() ?? 15.0;
    final perKm =
        (_getDeliveryValue(pricing, 'per_km_fee') as num?)?.toDouble() ?? 2.0;
    final surgeMultiplier =
        (_getDeliveryValue(pricing, 'surge_multiplier') as num?)?.toDouble() ?? 1.5;
    final minFee =
        (_getDeliveryValue(pricing, 'min_fee') as num?)?.toDouble() ?? 10.0;
    final maxFee =
        (_getDeliveryValue(pricing, 'max_fee') as num?)?.toDouble() ?? 100.0;

    double normalFee = baseFee + (5 * perKm);
    double surgeFee = normalFee * surgeMultiplier;
    normalFee = normalFee.clamp(minFee, maxFee);
    surgeFee = surgeFee.clamp(minFee, maxFee);

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Hesaplama Örnekleri', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '5 km Normal',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('$baseFee + (5 x $perKm) = ${normalFee.toStringAsFixed(2)} TL'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '5 km Surge',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'x$surgeMultiplier',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${normalFee.toStringAsFixed(2)} x $surgeMultiplier = ${surgeFee.toStringAsFixed(2)} TL',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== KOMİSYONLAR TAB ====================
  Widget _buildCommissionsTab() {
    final commissionsAsync = ref.watch(platformCommissionsProvider);

    return commissionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (commissions) => Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with Add button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    ElevatedButton.icon(
                      onPressed: () => _showCommissionDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Komisyon Kuralı'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Platform komisyonları, her işlemden platformun alacağı payı belirler.\n'
                          'Örnek: %20 komisyon = 100 TL işlemden platform 20 TL, sürücü/kurye 80 TL alır.',
                          style: TextStyle(color: AppColors.warning, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Commission cards
                ...commissions.map(
                  (commission) => _buildCommissionCardNew(commission),
                ),

                if (commissions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.percent, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'Komisyon ayarı bulunamadı',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showCommissionDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('İlk Komisyon Kuralını Ekle'),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),

          // Sabit Kaydet Butonu
          if (_hasCommissionChanges)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_commissionChanges.length} serviste değişiklik var',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _discardCommissionChanges,
                      child: const Text('Vazgeç'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSavingCommissions ? null : _saveAllCommissionChanges,
                      icon: _isSavingCommissions
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSavingCommissions
                            ? 'Kaydediliyor...'
                            : 'Tüm Değişiklikleri Kaydet',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommissionCardNew(Map<String, dynamic> commission) {
    final serviceType = commission['service_type'] ?? '';
    final displayName = commission['display_name'] ?? serviceType;
    final commissionId = commission['id']?.toString() ?? '';

    IconData icon;
    Color color;
    switch (serviceType) {
      case 'taxi':
        icon = Icons.local_taxi;
        color = AppColors.warning;
        break;
      case 'courier':
        icon = Icons.delivery_dining;
        color = AppColors.primary;
        break;
      case 'restaurant':
        icon = Icons.restaurant;
        color = AppColors.success;
        break;
      case 'store':
        icon = Icons.store;
        color = AppColors.info;
        break;
      case 'rent_a_car':
        icon = Icons.directions_car;
        color = const Color(0xFF9C27B0);
        break;
      default:
        icon = Icons.business;
        color = AppColors.textMuted;
    }

    final hasChanges = _commissionChanges.containsKey(commissionId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Servis Tipi: $serviceType',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                if (hasChanges)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Değiştirildi',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                _buildStatusBadge(commission['is_active'] == true),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showCommissionDialog(commission: commission),
                  color: AppColors.info,
                  tooltip: 'Düzenle',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _confirmDeleteCommission(commission),
                  color: AppColors.error,
                  tooltip: 'Sil',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Commission fields (inline editing)
            Row(
              children: [
                Expanded(
                  child: _buildCommissionFieldNew(
                    'Platform Komisyonu',
                    commission,
                    'platform_commission_rate',
                    '%',
                    commissionId,
                    AppColors.error,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCommissionFieldNew(
                    'Sürücü/Kurye Payı',
                    commission,
                    'driver_earning_rate',
                    '%',
                    commissionId,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCommissionFieldNew(
                    'Hizmet Bedeli',
                    commission,
                    'service_fee',
                    'TL',
                    commissionId,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCommissionFieldNew(
                    'Sigorta Ücreti',
                    commission,
                    'insurance_fee',
                    'TL',
                    commissionId,
                    AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildCommissionExampleNew(commission, commissionId),
          ],
        ),
      ),
    );
  }

  dynamic _getCommissionValue(
    Map<String, dynamic> commission,
    String commissionId,
    String field,
  ) {
    if (_commissionChanges.containsKey(commissionId) &&
        _commissionChanges[commissionId]!.containsKey(field)) {
      return _commissionChanges[commissionId]![field];
    }
    return commission[field];
  }

  Widget _buildCommissionFieldNew(
    String label,
    Map<String, dynamic> commission,
    String field,
    String unit,
    String commissionId,
    Color color,
  ) {
    final value = _getCommissionValue(commission, commissionId, field);
    final isChanged = _commissionChanges.containsKey(commissionId) &&
        _commissionChanges[commissionId]!.containsKey(field);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value?.toString() ?? '0',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: unit,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: isChanged,
            fillColor: isChanged ? AppColors.warning.withValues(alpha: 0.1) : null,
          ),
          onChanged: (val) => _onCommissionFieldChanged(commissionId, field, val),
        ),
      ],
    );
  }

  Widget _buildCommissionExampleNew(
    Map<String, dynamic> commission,
    String commissionId,
  ) {
    final platformRate =
        (_getCommissionValue(commission, commissionId, 'platform_commission_rate')
                    as num?)
                ?.toDouble() ??
            20.0;
    final driverRate =
        (_getCommissionValue(commission, commissionId, 'driver_earning_rate') as num?)
                ?.toDouble() ??
            80.0;
    final serviceFee =
        (_getCommissionValue(commission, commissionId, 'service_fee') as num?)
                ?.toDouble() ??
            0;

    const exampleAmount = 100.0;
    final platformEarning = exampleAmount * platformRate / 100;
    final driverEarning = exampleAmount * driverRate / 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Örnek: ${exampleAmount.toStringAsFixed(0)} TL işlem = '
              'Platform ${platformEarning.toStringAsFixed(2)} TL, '
              'Sürücü/Kurye ${driverEarning.toStringAsFixed(2)} TL'
              '${serviceFee > 0 ? ' + $serviceFee TL hizmet bedeli' : ''}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _onCommissionFieldChanged(String commissionId, String field, String value) {
    setState(() {
      if (!_commissionChanges.containsKey(commissionId)) {
        _commissionChanges[commissionId] = {};
      }
      _commissionChanges[commissionId]![field] = num.tryParse(value) ?? 0;
      _hasCommissionChanges = _commissionChanges.isNotEmpty;
    });
  }

  void _discardCommissionChanges() {
    setState(() {
      _commissionChanges.clear();
      _hasCommissionChanges = false;
    });
    ref.invalidate(platformCommissionsProvider);
  }

  Future<void> _saveAllCommissionChanges() async {
    if (_commissionChanges.isEmpty) return;

    setState(() => _isSavingCommissions = true);

    try {
      final supabase = ref.read(supabaseProvider);

      for (final entry in _commissionChanges.entries) {
        final commissionId = entry.key;
        final changes = Map<String, dynamic>.from(entry.value);

        if (changes.isNotEmpty) {
          changes['updated_at'] = DateTime.now().toIso8601String();
          await supabase
              .from('platform_commissions')
              .update(changes)
              .eq('id', commissionId);
        }
      }

      setState(() {
        _commissionChanges.clear();
        _hasCommissionChanges = false;
        _isSavingCommissions = false;
      });

      ref.invalidate(platformCommissionsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komisyon ayarları başarıyla kaydedildi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _isSavingCommissions = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ==================== YARDIMCI METODLAR ====================
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

  // ==================== ARAÇ TİPİ DİYALOG ====================
  void _showVehicleTypeDialog({Map<String, dynamic>? vehicleType}) {
    final isEditing = vehicleType != null;

    final pricing = vehicleType?['taxi_pricing'];
    final pricingData = pricing is List && pricing.isNotEmpty
        ? pricing.first
        : (pricing is Map ? pricing : null);

    final nameController = TextEditingController(text: vehicleType?['name'] ?? '');
    final displayNameController =
        TextEditingController(text: vehicleType?['display_name'] ?? '');
    final baseFareController = TextEditingController(
      text: (pricingData?['base_fare'] ?? vehicleType?['default_base_fare'] ?? '').toString(),
    );
    final perKmController = TextEditingController(
      text: (pricingData?['per_km_fare'] ?? vehicleType?['default_per_km'] ?? '').toString(),
    );
    final perMinuteController = TextEditingController(
      text: (pricingData?['per_minute_fare'] ?? vehicleType?['default_per_minute'] ?? '')
          .toString(),
    );
    final minFareController = TextEditingController(
      text:
          (pricingData?['minimum_fare'] ?? vehicleType?['default_minimum_fare'] ?? '').toString(),
    );
    final capacityController =
        TextEditingController(text: vehicleType?['capacity']?.toString() ?? '4');

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Araç Tipini Düzenle' : 'Yeni Araç Tipi'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tip Adı (örn: standard)',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Görünen Ad (örn: Standart)',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: baseFareController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Açılış Ücreti (TL)',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !isLoading,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: perKmController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'KM Başına (TL)',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !isLoading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: perMinuteController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Dakika Başına (TL)',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !isLoading,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: minFareController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Ücret (TL)',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !isLoading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kapasite (Kişi)',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !isLoading,
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
                              content: Text('Tip adı boş olamaz'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        if (displayNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Görünen ad boş olamaz'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        final baseFare =
                            double.tryParse(baseFareController.text) ?? 0;
                        final perKm = double.tryParse(perKmController.text) ?? 0;
                        final perMinute =
                            double.tryParse(perMinuteController.text) ?? 0;
                        final minFare =
                            double.tryParse(minFareController.text) ?? 0;

                        final vehicleData = {
                          'name': nameController.text.trim(),
                          'display_name': displayNameController.text.trim(),
                          'default_base_fare': baseFare,
                          'default_per_km': perKm,
                          'default_per_minute': perMinute,
                          'default_minimum_fare': minFare,
                          'capacity': int.tryParse(capacityController.text) ?? 4,
                          'is_active': true,
                        };

                        final pricingUpdateData = {
                          'base_fare': baseFare,
                          'per_km_fare': perKm,
                          'per_minute_fare': perMinute,
                          'minimum_fare': minFare,
                          'updated_at': DateTime.now().toIso8601String(),
                        };

                        try {
                          final supabase = ref.read(supabaseProvider);
                          if (isEditing) {
                            await supabase
                                .from('vehicle_types')
                                .update(vehicleData)
                                .eq('id', vehicleType['id']);
                            if (pricingData != null && pricingData['id'] != null) {
                              await supabase
                                  .from('taxi_pricing')
                                  .update(pricingUpdateData)
                                  .eq('id', pricingData['id']);
                            } else {
                              await supabase.from('taxi_pricing').insert({
                                ...pricingUpdateData,
                                'vehicle_type_id': vehicleType['id'],
                                'is_active': true,
                              });
                            }
                          } else {
                            final result = await supabase
                                .from('vehicle_types')
                                .insert(vehicleData)
                                .select()
                                .single();
                            await supabase.from('taxi_pricing').insert({
                              'vehicle_type_id': result['id'],
                              'base_fare': baseFare,
                              'per_km_fare': perKm,
                              'per_minute_fare': perMinute,
                              'minimum_fare': minFare,
                              'is_active': true,
                            });
                          }

                          ref.invalidate(vehicleTypesProvider);
                          ref.invalidate(taxiPricingProvider);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? 'Araç tipi güncellendi'
                                      : 'Yeni araç tipi eklendi',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (dialogContext.mounted) {
                            String errorMessage = 'Hata: $e';
                            if (e.toString().contains('duplicate key') ||
                                e.toString().contains('unique constraint')) {
                              errorMessage =
                                  'Bu tip adı zaten mevcut! Lütfen farklı bir tip adı girin.';
                            }
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(errorMessage),
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
                    : Text(isEditing ? 'Güncelle' : 'Ekle'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleVehicleTypeStatus(Map<String, dynamic> vt) async {
    final supabase = ref.read(supabaseProvider);
    try {
      await supabase
          .from('vehicle_types')
          .update({'is_active': !(vt['is_active'] == true)})
          .eq('id', vt['id']);
      ref.invalidate(vehicleTypesProvider);
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

  // ==================== SİLME ONAYLAMA DİYALOGLARI ====================
  void _confirmDeleteVehicleType(Map<String, dynamic> vt) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Araç Tipini Sil'),
        content: Text(
          '"${vt['display_name'] ?? vt['name']}" araç tipini silmek istediğinize emin misiniz?\n\n'
          'Bu işlem ilgili taksi fiyatlandırma kayıtlarını da etkileyebilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteVehicleType(vt);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVehicleType(Map<String, dynamic> vt) async {
    try {
      final supabase = ref.read(supabaseProvider);
      // taxi_pricing kaydını da sil
      await supabase.from('taxi_pricing').delete().eq('vehicle_type_id', vt['id']);
      await supabase.from('vehicle_types').delete().eq('id', vt['id']);
      ref.invalidate(vehicleTypesProvider);
      ref.invalidate(taxiPricingProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Araç tipi silindi'),
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

  void _confirmDeleteTaxiPricing(Map<String, dynamic> pricing) {
    final vt = pricing['vehicle_types'];
    final name = vt?['display_name'] ?? 'Bu kayıt';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fiyat Kaydını Sil'),
        content: Text(
          '"$name" için taksi fiyat kaydını silmek istediğinize emin misiniz?',
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
                await supabase
                    .from('taxi_pricing')
                    .delete()
                    .eq('id', pricing['id']);
                ref.invalidate(taxiPricingProvider);
                ref.invalidate(vehicleTypesProvider);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fiyat kaydı silindi'),
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

  // ==================== KOMİSYON DİYALOG ====================
  void _showCommissionDialog({Map<String, dynamic>? commission}) {
    final isEditing = commission != null;
    final displayNameController =
        TextEditingController(text: commission?['display_name'] ?? '');
    final serviceTypeController =
        TextEditingController(text: commission?['service_type'] ?? '');
    final platformRateController = TextEditingController(
      text: commission?['platform_commission_rate']?.toString() ?? '20',
    );
    final driverRateController = TextEditingController(
      text: commission?['driver_earning_rate']?.toString() ?? '80',
    );
    final serviceFeeController =
        TextEditingController(text: commission?['service_fee']?.toString() ?? '0');
    final insuranceFeeController =
        TextEditingController(text: commission?['insurance_fee']?.toString() ?? '0');
    bool isActive = commission?['is_active'] ?? true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Komisyon Kuralını Düzenle' : 'Yeni Komisyon Kuralı'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Görünen Ad (örn: Taksi Servisi)',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: serviceTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Servis Tipi (taxi / courier / restaurant / store)',
                      border: OutlineInputBorder(),
                      helperText: 'Küçük harf, özel karakter kullanmayın',
                    ),
                    enabled: !isLoading && !isEditing,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: platformRateController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Platform Komisyonu (%)',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                          ),
                          enabled: !isLoading,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: driverRateController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sürücü/Kurye Payı (%)',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                          ),
                          enabled: !isLoading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: serviceFeeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Hizmet Bedeli (TL)',
                            border: OutlineInputBorder(),
                            suffixText: 'TL',
                          ),
                          enabled: !isLoading,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: insuranceFeeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sigorta Ücreti (TL)',
                            border: OutlineInputBorder(),
                            suffixText: 'TL',
                          ),
                          enabled: !isLoading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    subtitle: const Text('Bu komisyon kuralı uygulanıyor'),
                    value: isActive,
                    onChanged: isLoading
                        ? null
                        : (val) => setDialogState(() => isActive = val),
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
                      if (displayNameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Görünen ad boş olamaz'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      if (!isEditing && serviceTypeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Servis tipi boş olamaz'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final data = {
                        'display_name': displayNameController.text.trim(),
                        'platform_commission_rate':
                            double.tryParse(platformRateController.text) ?? 20,
                        'driver_earning_rate':
                            double.tryParse(driverRateController.text) ?? 80,
                        'service_fee':
                            double.tryParse(serviceFeeController.text) ?? 0,
                        'insurance_fee':
                            double.tryParse(insuranceFeeController.text) ?? 0,
                        'is_active': isActive,
                        'updated_at': DateTime.now().toIso8601String(),
                      };

                      if (!isEditing) {
                        data['service_type'] = serviceTypeController.text.trim();
                        data['created_at'] = DateTime.now().toIso8601String();
                      }

                      try {
                        final supabase = ref.read(supabaseProvider);
                        if (isEditing) {
                          await supabase
                              .from('platform_commissions')
                              .update(data)
                              .eq('id', commission['id']);
                        } else {
                          await supabase.from('platform_commissions').insert(data);
                        }
                        ref.invalidate(platformCommissionsProvider);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? 'Komisyon kuralı güncellendi'
                                    : 'Yeni komisyon kuralı eklendi',
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
                  : Text(isEditing ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCommission(Map<String, dynamic> commission) {
    final name = commission['display_name'] ?? commission['service_type'] ?? 'Bu kayıt';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Komisyon Kuralını Sil'),
        content: Text('"$name" komisyon kuralını silmek istediğinize emin misiniz?'),
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
                await supabase
                    .from('platform_commissions')
                    .delete()
                    .eq('id', commission['id']);
                // Temizle değişiklik state'ini de
                final id = commission['id']?.toString();
                if (id != null) _commissionChanges.remove(id);
                _hasCommissionChanges = _commissionChanges.isNotEmpty;
                ref.invalidate(platformCommissionsProvider);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Komisyon kuralı silindi'),
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
}
