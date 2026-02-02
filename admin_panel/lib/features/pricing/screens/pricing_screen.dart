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
                      'Fiyatlandirma Yonetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Taksi, kurye fiyatlarini ve platform komisyonlarini yonetin',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
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
                Tab(text: 'Arac Tipleri'),
                Tab(text: 'Taksi Ucretleri'),
                Tab(text: 'Kurye Ucretleri'),
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

  // ==================== ARAC TIPLERI TAB ====================
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
                  label: const Text('Yeni Arac Tipi'),
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
                      DataColumn2(label: Text('Gorunen Ad'), size: ColumnSize.M),
                      DataColumn2(label: Text('Acilis'), size: ColumnSize.S),
                      DataColumn2(label: Text('KM'), size: ColumnSize.S),
                      DataColumn2(label: Text('Dakika'), size: ColumnSize.S),
                      DataColumn2(label: Text('Min.'), size: ColumnSize.S),
                      DataColumn2(label: Text('Kapasite'), size: ColumnSize.S),
                      DataColumn2(label: Text('Durum'), size: ColumnSize.S),
                      DataColumn2(label: Text('Islem'), size: ColumnSize.S),
                    ],
                    rows: vehicleTypes.map((vt) {
                      // taxi_pricing tablosundan fiyatları al
                      final pricing = vt['taxi_pricing'];
                      final pricingData = pricing is List && pricing.isNotEmpty ? pricing.first : (pricing is Map ? pricing : null);

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
                          DataCell(Text('${vt['capacity']} kisi')),
                          DataCell(_buildStatusBadge(vt['is_active'] == true)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showVehicleTypeDialog(vehicleType: vt),
                                  tooltip: 'Duzenle',
                                ),
                                IconButton(
                                  icon: Icon(
                                    vt['is_active'] == true ? Icons.pause : Icons.play_arrow,
                                    size: 18,
                                  ),
                                  onPressed: () => _toggleVehicleTypeStatus(vt),
                                  tooltip: vt['is_active'] == true ? 'Devre Disi Birak' : 'Etkinlestir',
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

  // ==================== TAKSI UCRETLERI TAB ====================
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
                          'Taksi ucretleri arac tipine gore belirlenir. Her arac tipi icin farkli fiyatlandirma ayarlayabilirsiniz.\n'
                          'Hesaplama: Acilis Ucreti + (Mesafe x KM Ucreti) + (Sure x Dakika Ucreti)',
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
                            'Taksi fiyatlandirmasi bulunamadi.\nOnce arac tipleri ekleyin.',
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
                        '${_taxiPricingChanges.length} arac tipinde degisiklik var',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _discardTaxiPricingChanges,
                      child: const Text('Vazgec'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSavingTaxiPricing ? null : _saveAllTaxiPricingChanges,
                      icon: _isSavingTaxiPricing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isSavingTaxiPricing ? 'Kaydediliyor...' : 'Tum Degisiklikleri Kaydet'),
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
      if (_taxiPricingChanges.containsKey(pricingId) && _taxiPricingChanges[pricingId]!.containsKey(field)) {
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
                    Text('Kapasite: ${vt?['capacity'] ?? 4} kisi', style: TextStyle(color: AppColors.textMuted)),
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
                    child: Text('Degistirildi', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                _buildStatusBadge(pricing['is_active'] == true),
              ],
            ),
            const SizedBox(height: 24),

            // Pricing fields
            Row(
              children: [
                Expanded(child: _buildTaxiPriceFieldNew('Acilis Ucreti', getCurrentValue('base_fare'), 'TL', 'base_fare', pricingId)),
                const SizedBox(width: 16),
                Expanded(child: _buildTaxiPriceFieldNew('KM Basina', getCurrentValue('per_km_fare'), 'TL', 'per_km_fare', pricingId)),
                const SizedBox(width: 16),
                Expanded(child: _buildTaxiPriceFieldNew('Dakika Basina', getCurrentValue('per_minute_fare'), 'TL', 'per_minute_fare', pricingId)),
                const SizedBox(width: 16),
                Expanded(child: _buildTaxiPriceFieldNew('Minimum Ucret', getCurrentValue('minimum_fare'), 'TL', 'minimum_fare', pricingId)),
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
                            const Text('Yogun Saat Tarifesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTaxiPriceFieldNew('Surge Carpani', getCurrentValue('surge_multiplier'), 'x', 'surge_multiplier', pricingId),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTaxiTimeFieldNew('Sabah', getCurrentValue('surge_start_hour_1'), getCurrentValue('surge_end_hour_1'), pricingId, 'surge_start_hour_1', 'surge_end_hour_1')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTaxiTimeFieldNew('Aksam', getCurrentValue('surge_start_hour_2'), getCurrentValue('surge_end_hour_2'), pricingId, 'surge_start_hour_2', 'surge_end_hour_2')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yogun saatlerde fiyatlar otomatik ${((getCurrentValue('surge_multiplier')['value'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(1)}x ile carpilir',
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
                            const Text('Gece Tarifesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTaxiPriceFieldNew('Gece Carpani', getCurrentValue('night_multiplier'), 'x', 'night_multiplier', pricingId),
                        const SizedBox(height: 12),
                        _buildTaxiTimeFieldNew('Gece Saatleri', getCurrentValue('night_start_hour'), getCurrentValue('night_end_hour'), pricingId, 'night_start_hour', 'night_end_hour'),
                        const SizedBox(height: 8),
                        Text(
                          'Gece ${getCurrentValue('night_start_hour')['value'] ?? 0}:00 - ${getCurrentValue('night_end_hour')['value'] ?? 6}:00 arasi ${((getCurrentValue('night_multiplier')['value'] as num?)?.toDouble() ?? 1.5).toStringAsFixed(1)}x tarife uygulanir',
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

  Widget _buildTaxiPriceFieldNew(String label, Map<String, dynamic> valueData, String unit, String field, String pricingId) {
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
              borderSide: BorderSide(color: isChanged ? AppColors.warning : AppColors.textMuted.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isChanged ? AppColors.warning : AppColors.textMuted.withValues(alpha: 0.3)),
            ),
          ),
          onChanged: (newValue) => _onTaxiPricingFieldChanged(pricingId, field, newValue),
        ),
      ],
    );
  }

  Widget _buildTaxiTimeFieldNew(String label, Map<String, dynamic> startData, Map<String, dynamic> endData, String pricingId, String startField, String endField) {
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
                  hintText: 'Baslangic',
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
                  hintText: 'Bitis',
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
    // Her iki provider'ı da yenile - senkronizasyon için
    ref.invalidate(taxiPricingProvider);
    ref.invalidate(vehicleTypesProvider);
  }

  Future<void> _saveAllTaxiPricingChanges() async {
    if (_taxiPricingChanges.isEmpty) return;

    setState(() => _isSavingTaxiPricing = true);

    try {
      final supabase = ref.read(supabaseProvider);

      // Önce taxi_pricing verisini al - vehicle_type_id'yi bulmak için
      final taxiPricingData = ref.read(taxiPricingProvider).valueOrNull ?? [];

      for (final entry in _taxiPricingChanges.entries) {
        final pricingId = entry.key;
        final changes = Map<String, dynamic>.from(entry.value);

        if (changes.isNotEmpty) {
          changes['updated_at'] = DateTime.now().toIso8601String();

          // taxi_pricing tablosunu güncelle
          await supabase.from('taxi_pricing').update(changes).eq('id', pricingId);

          // vehicle_types tablosunu da güncelle - senkronizasyon için
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
              await supabase.from('vehicle_types').update(vehicleTypeChanges).eq('id', vehicleTypeId);
            }
          }
        }
      }

      setState(() {
        _taxiPricingChanges.clear();
        _hasTaxiPricingChanges = false;
        _isSavingTaxiPricing = false;
      });

      // Her iki provider'ı da yenile - senkronizasyon için
      ref.invalidate(taxiPricingProvider);
      ref.invalidate(vehicleTypesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tum taksi fiyatlandirmalari basariyla kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isSavingTaxiPricing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTaxiCalculationExampleNew(String pricingId, Map<String, dynamic> originalPricing) {
    // Değişiklik varsa onu kullan, yoksa orijinal değeri kullan
    dynamic getValue(String field) {
      if (_taxiPricingChanges.containsKey(pricingId) && _taxiPricingChanges[pricingId]!.containsKey(field)) {
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

    // Example: 5 km, 15 min
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
              Text('Hesaplama Ornekleri (5 km, 15 dk)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Normal tarife
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
                          const Text('Normal', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${normalTotal.toStringAsFixed(2)} TL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Surge tarife
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
                          Text('Yogun Saat (x$surgeMultiplier)', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${surgeTotal.toStringAsFixed(2)} TL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.warning)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Gece tarife
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
                          Text('Gece (x$nightMultiplier)', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${nightTotal.toStringAsFixed(2)} TL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.info)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Formul: $baseFare TL (acilis) + (5 km x $perKm TL) + (15 dk x $perMin TL) = ${normalTotal.toStringAsFixed(2)} TL',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==================== KURYE UCRETLERI TAB ====================
  Widget _buildCourierPricingTab() {
    final pricingAsync = ref.watch(deliveryPricingProvider);

    return pricingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (pricing) {
        // ID'yi kaydet
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
                            'Platform kuryelerinin teslimat ucretleri mesafeye gore hesaplanir.\n'
                            'Musteriye yansiyacak ucret = Baz Ucret + (Mesafe x KM Ucreti) x Carpanlar',
                            style: TextStyle(color: AppColors.info, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Basic pricing
                  Text('Temel Ucretler', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildDeliveryPricingCardNew('Baz Ucret', pricing, 'base_fee', 'TL', Icons.delivery_dining, AppColors.primary)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDeliveryPricingCardNew('KM Basina', pricing, 'per_km_fee', 'TL', Icons.straighten, AppColors.success)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDeliveryPricingCardNew('Min. Ucret', pricing, 'min_fee', 'TL', Icons.arrow_downward, AppColors.warning)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDeliveryPricingCardNew('Maks. Ucret', pricing, 'max_fee', 'TL', Icons.arrow_upward, AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Distance tiers
                  Text('Mesafe Kademeleri', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Farkli mesafe araliklari icin sabit ucretler belirleyebilirsiniz', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTierCardNew('Kademe 1', '0 - ${_getDeliveryValue(pricing, 'tier_1_km') ?? 3} km', pricing, 'tier_1_fee', AppColors.success)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTierCardNew('Kademe 2', '${_getDeliveryValue(pricing, 'tier_1_km') ?? 3} - ${_getDeliveryValue(pricing, 'tier_2_km') ?? 7} km', pricing, 'tier_2_fee', AppColors.info)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTierCardNew('Kademe 3', '${_getDeliveryValue(pricing, 'tier_2_km') ?? 7} - ${_getDeliveryValue(pricing, 'tier_3_km') ?? 15} km', pricing, 'tier_3_fee', AppColors.warning)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTierCardNew('15+ km', 'Her ek km icin', pricing, 'extra_km_fee', AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Multipliers
                  Text('Carpanlar', style: Theme.of(context).textTheme.titleMedium),
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
                                    const Text('Surge (Yogun Saat)'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDeliveryMultiplierFieldNew('Surge Carpani', pricing, 'surge_multiplier'),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildDeliveryTimeFieldNew('Ogle', pricing, 'surge_start_hour', 'surge_end_hour')),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildDeliveryTimeFieldNew('Aksam', pricing, 'evening_surge_start', 'evening_surge_end')),
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
                                _buildDeliveryMultiplierFieldNew('Gece Carpani', pricing, 'night_multiplier'),
                                const SizedBox(height: 12),
                                _buildDeliveryTimeFieldNew('Gece Saatleri', pricing, 'night_start_hour', 'night_end_hour'),
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
                                    const Text('Kotu Hava'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDeliveryMultiplierFieldNew('Hava Carpani', pricing, 'bad_weather_multiplier'),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Yagmur, kar gibi kotu hava kosullarinda otomatik uygulanir',
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

                  // Calculation example
                  _buildCourierCalculationExampleNew(pricing),

                  // Kaydet butonu için boşluk
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
                          '${_deliveryPricingChanges.length} alanda degisiklik var',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: _discardDeliveryPricingChanges,
                        child: const Text('Vazgec'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isSavingDeliveryPricing ? null : _saveAllDeliveryPricingChanges,
                        icon: _isSavingDeliveryPricing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(_isSavingDeliveryPricing ? 'Kaydediliyor...' : 'Tum Degisiklikleri Kaydet'),
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

  Widget _buildDeliveryPricingCardNew(String title, Map<String, dynamic>? pricing, String field, String unit, IconData icon, Color color) {
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
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
                if (isChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('*', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
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

  Widget _buildTierCardNew(String title, String range, Map<String, dynamic>? pricing, String field, Color color) {
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
                  child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (isChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('*', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
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

  Widget _buildDeliveryMultiplierFieldNew(String label, Map<String, dynamic>? pricing, String field) {
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

  Widget _buildDeliveryTimeFieldNew(String label, Map<String, dynamic>? pricing, String startField, String endField) {
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
            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('-')),
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

      await supabase.from('delivery_pricing').update(changes).eq('id', _currentDeliveryPricingId!);

      setState(() {
        _deliveryPricingChanges.clear();
        _hasDeliveryPricingChanges = false;
        _isSavingDeliveryPricing = false;
      });

      ref.invalidate(deliveryPricingProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kurye fiyatlandirmalari basariyla kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isSavingDeliveryPricing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCourierCalculationExampleNew(Map<String, dynamic>? pricing) {
    final baseFee = (_getDeliveryValue(pricing, 'base_fee') as num?)?.toDouble() ?? 15.0;
    final perKm = (_getDeliveryValue(pricing, 'per_km_fee') as num?)?.toDouble() ?? 2.0;
    final surgeMultiplier = (_getDeliveryValue(pricing, 'surge_multiplier') as num?)?.toDouble() ?? 1.5;
    final minFee = (_getDeliveryValue(pricing, 'min_fee') as num?)?.toDouble() ?? 10.0;
    final maxFee = (_getDeliveryValue(pricing, 'max_fee') as num?)?.toDouble() ?? 100.0;

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
                Text('Hesaplama Ornekleri', style: Theme.of(context).textTheme.titleMedium),
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
                        const Text('5 km Normal', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            const Text('5 km Surge', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('x$surgeMultiplier', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${normalFee.toStringAsFixed(2)} x $surgeMultiplier = ${surgeFee.toStringAsFixed(2)} TL'),
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

  // ==================== KOMISYONLAR TAB ====================
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
                          'Platform komisyonlari, her islemden platformun alacagi payi belirler.\n'
                          'Ornek: %20 komisyon = 100 TL islemden platform 20 TL, surucu/kurye 80 TL alir.',
                          style: TextStyle(color: AppColors.warning, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Commission cards
                ...commissions.map((commission) => _buildCommissionCardNew(commission)),

                if (commissions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.percent, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text('Komisyon ayari bulunamadi', style: TextStyle(color: AppColors.textMuted)),
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
                        '${_commissionChanges.length} serviste degisiklik var',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _discardCommissionChanges,
                      child: const Text('Vazgec'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSavingCommissions ? null : _saveAllCommissionChanges,
                      icon: _isSavingCommissions
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isSavingCommissions ? 'Kaydediliyor...' : 'Tum Degisiklikleri Kaydet'),
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
        color = const Color(0xFF9C27B0); // Purple
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
                    Text('Servis Tipi: $serviceType', style: TextStyle(color: AppColors.textMuted)),
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
                    child: Text('Degistirildi', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                _buildStatusBadge(commission['is_active'] == true),
              ],
            ),
            const SizedBox(height: 24),

            // Commission fields
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
                    'Surucu/Kurye Payi',
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
                    'Sigorta Ucreti',
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

            // Example
            _buildCommissionExampleNew(commission, commissionId),
          ],
        ),
      ),
    );
  }

  dynamic _getCommissionValue(Map<String, dynamic> commission, String commissionId, String field) {
    if (_commissionChanges.containsKey(commissionId) && _commissionChanges[commissionId]!.containsKey(field)) {
      return _commissionChanges[commissionId]![field];
    }
    return commission[field];
  }

  Widget _buildCommissionFieldNew(String label, Map<String, dynamic> commission, String field, String unit, String commissionId, Color color) {
    final value = _getCommissionValue(commission, commissionId, field);
    final isChanged = _commissionChanges.containsKey(commissionId) && _commissionChanges[commissionId]!.containsKey(field);

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

  Widget _buildCommissionExampleNew(Map<String, dynamic> commission, String commissionId) {
    final platformRate = (_getCommissionValue(commission, commissionId, 'platform_commission_rate') as num?)?.toDouble() ?? 20.0;
    final driverRate = (_getCommissionValue(commission, commissionId, 'driver_earning_rate') as num?)?.toDouble() ?? 80.0;
    final serviceFee = (_getCommissionValue(commission, commissionId, 'service_fee') as num?)?.toDouble() ?? 0;

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
              'Ornek: ${exampleAmount.toStringAsFixed(0)} TL islem = Platform ${platformEarning.toStringAsFixed(2)} TL, Surucu/Kurye ${driverEarning.toStringAsFixed(2)} TL${serviceFee > 0 ? ' + $serviceFee TL hizmet bedeli' : ''}',
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
          await supabase.from('platform_commissions').update(changes).eq('id', commissionId);
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
          content: Text('Komisyon ayarlari basariyla kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isSavingCommissions = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== HELPER METHODS ====================
  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
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

  void _showVehicleTypeDialog({Map<String, dynamic>? vehicleType}) {
    final isEditing = vehicleType != null;

    // taxi_pricing verisi varsa oradan al, yoksa default değerleri kullan
    final pricing = vehicleType?['taxi_pricing'];
    final pricingData = pricing is List && pricing.isNotEmpty ? pricing.first : (pricing is Map ? pricing : null);

    final nameController = TextEditingController(text: vehicleType?['name'] ?? '');
    final displayNameController = TextEditingController(text: vehicleType?['display_name'] ?? '');
    final baseFareController = TextEditingController(text: (pricingData?['base_fare'] ?? vehicleType?['default_base_fare'] ?? '').toString());
    final perKmController = TextEditingController(text: (pricingData?['per_km_fare'] ?? vehicleType?['default_per_km'] ?? '').toString());
    final perMinuteController = TextEditingController(text: (pricingData?['per_minute_fare'] ?? vehicleType?['default_per_minute'] ?? '').toString());
    final minFareController = TextEditingController(text: (pricingData?['minimum_fare'] ?? vehicleType?['default_minimum_fare'] ?? '').toString());
    final capacityController = TextEditingController(text: vehicleType?['capacity']?.toString() ?? '4');

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Arac Tipini Duzenle' : 'Yeni Arac Tipi'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tip Adi (orn: standard)'),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(labelText: 'Gorunen Ad (orn: Standart)'),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: baseFareController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Acilis Ucreti (TL)'),
                            enabled: !isLoading,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: perKmController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'KM Basina (TL)'),
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
                            decoration: const InputDecoration(labelText: 'Dakika Basina (TL)'),
                            enabled: !isLoading,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: minFareController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Minimum Ucret (TL)'),
                            enabled: !isLoading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Kapasite (Kisi)'),
                      enabled: !isLoading,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  // Validasyon
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Tip adi bos olamaz'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (displayNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Gorunen ad bos olamaz'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  setDialogState(() => isLoading = true);

                  final baseFare = double.tryParse(baseFareController.text) ?? 0;
                  final perKm = double.tryParse(perKmController.text) ?? 0;
                  final perMinute = double.tryParse(perMinuteController.text) ?? 0;
                  final minFare = double.tryParse(minFareController.text) ?? 0;

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
                      // vehicle_types güncelle
                      await supabase.from('vehicle_types').update(vehicleData).eq('id', vehicleType['id']);
                      // taxi_pricing güncelle
                      if (pricingData != null && pricingData['id'] != null) {
                        await supabase.from('taxi_pricing').update(pricingUpdateData).eq('id', pricingData['id']);
                      } else {
                        // taxi_pricing yoksa oluştur
                        await supabase.from('taxi_pricing').insert({
                          ...pricingUpdateData,
                          'vehicle_type_id': vehicleType['id'],
                          'is_active': true,
                        });
                      }
                    } else {
                      // Yeni araç tipi ve taxi_pricing oluştur
                      final result = await supabase.from('vehicle_types').insert(vehicleData).select().single();
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
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? 'Arac tipi guncellendi' : 'Yeni arac tipi eklendi'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    if (dialogContext.mounted) {
                      String errorMessage = 'Hata: $e';
                      // Duplicate key hatası için özel mesaj
                      if (e.toString().contains('duplicate key') || e.toString().contains('unique constraint')) {
                        errorMessage = 'Bu tip adi zaten mevcut! Lutfen farkli bir tip adi girin.';
                      }
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEditing ? 'Guncelle' : 'Ekle'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleVehicleTypeStatus(Map<String, dynamic> vt) async {
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('vehicle_types')
        .update({'is_active': !(vt['is_active'] == true)})
        .eq('id', vt['id']);
    ref.invalidate(vehicleTypesProvider);
  }
}
