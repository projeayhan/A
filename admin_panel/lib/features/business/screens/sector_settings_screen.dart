import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/sector_type.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Mevcut ayar ekranlarını import et
import '../../food/screens/restaurant_categories_screen.dart';
import '../../store/screens/store_categories_screen.dart';
import '../../emlak/screens/emlak_property_types_screen.dart';
import '../../emlak/screens/emlak_amenities_screen.dart';
import '../../emlak/screens/emlak_cities_screen.dart';
import '../../emlak/screens/emlak_districts_screen.dart';
import '../../emlak/screens/emlak_pricing_screen.dart';
import '../../emlak/screens/emlak_settings_screen.dart';
import '../../car_sales/screens/car_sales_brands_screen.dart';
import '../../car_sales/screens/car_sales_features_screen.dart';
import '../../car_sales/screens/car_sales_body_types_screen.dart';
import '../../car_sales/screens/car_sales_fuel_types_screen.dart';
import '../../car_sales/screens/car_sales_transmissions_screen.dart';
import '../../car_sales/screens/car_sales_pricing_screen.dart';
import '../../job_listings/screens/job_categories_screen.dart';
import '../../job_listings/screens/job_skills_screen.dart';
import '../../job_listings/screens/job_benefits_screen.dart';
import '../../job_listings/screens/job_pricing_screen.dart';
import '../../job_listings/screens/job_settings_screen.dart';
import '../../rental/screens/rental_locations_screen.dart';

class SectorSettingsScreen extends ConsumerStatefulWidget {
  final SectorType sector;

  const SectorSettingsScreen({super.key, required this.sector});

  @override
  ConsumerState<SectorSettingsScreen> createState() => _SectorSettingsScreenState();
}

class _SectorSettingsScreenState extends ConsumerState<SectorSettingsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  List<_SettingsTab> get _settingsTabs {
    switch (widget.sector) {
      case SectorType.food:
        return [
          _SettingsTab('Restoran Kategorileri', Icons.category_outlined, const RestaurantCategoriesScreen()),
        ];
      case SectorType.market:
        return [
          _SettingsTab('Mağaza Kategorileri', Icons.category_outlined, const StoreCategoriesScreen()),
        ];
      case SectorType.store:
        return [
          _SettingsTab('Mağaza Kategorileri', Icons.category_outlined, const StoreCategoriesScreen()),
        ];
      case SectorType.realEstate:
        return [
          _SettingsTab('Emlak Türleri', Icons.category_outlined, const EmlakPropertyTypesScreen()),
          _SettingsTab('Özellikler', Icons.featured_play_list_outlined, const EmlakAmenitiesScreen()),
          _SettingsTab('Şehirler', Icons.location_city_outlined, const EmlakCitiesScreen()),
          _SettingsTab('İlçeler', Icons.map_outlined, const EmlakDistrictsScreen()),
          _SettingsTab('Fiyatlandırma', Icons.price_change_outlined, const EmlakPricingScreen()),
          _SettingsTab('Ayarlar', Icons.settings_outlined, const EmlakSettingsScreen()),
        ];
      case SectorType.taxi:
        return [
          _SettingsTab('Genel Ayarlar', Icons.settings_outlined, const _TaxiSettingsContent()),
        ];
      case SectorType.carSales:
        return [
          _SettingsTab('Markalar', Icons.branding_watermark_outlined, const CarSalesBrandsScreen()),
          _SettingsTab('Özellikler', Icons.featured_play_list_outlined, const CarSalesFeaturesScreen()),
          _SettingsTab('Gövde Tipleri', Icons.directions_car_outlined, const CarSalesBodyTypesScreen()),
          _SettingsTab('Yakıt Tipleri', Icons.local_gas_station_outlined, const CarSalesFuelTypesScreen()),
          _SettingsTab('Vites Tipleri', Icons.settings_outlined, const CarSalesTransmissionsScreen()),
          _SettingsTab('Fiyatlandırma', Icons.price_change_outlined, const CarSalesPricingScreen()),
        ];
      case SectorType.jobs:
        return [
          _SettingsTab('Kategoriler', Icons.category_outlined, const JobCategoriesScreen()),
          _SettingsTab('Yetenekler', Icons.psychology_outlined, const JobSkillsScreen()),
          _SettingsTab('Yan Haklar', Icons.card_giftcard_outlined, const JobBenefitsScreen()),
          _SettingsTab('Fiyatlandırma', Icons.monetization_on_outlined, const JobPricingScreen()),
          _SettingsTab('Ayarlar', Icons.tune_outlined, const JobSettingsScreen()),
        ];
      case SectorType.carRental:
        return [
          _SettingsTab('Lokasyonlar', Icons.location_on_outlined, const RentalLocationsScreen()),
          _SettingsTab('Genel Ayarlar', Icons.settings_outlined, const _CarRentalSettingsContent()),
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _settingsTabs.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant SectorSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sector != widget.sector) {
      _tabController.dispose();
      _tabController = TabController(length: _settingsTabs.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => context.go(widget.sector.baseRoute),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: '${widget.sector.label} Listesine Dön',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 16),
              Icon(widget.sector.icon, size: 28, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                '${widget.sector.label} Ayarları',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? AppColors.textMuted : Colors.grey.shade600,
              dividerColor: Colors.transparent,
              tabs: _settingsTabs.map((tab) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 18),
                    const SizedBox(width: 8),
                    Text(tab.label),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _settingsTabs.map((tab) => tab.content).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab {
  final String label;
  final IconData icon;
  final Widget content;

  const _SettingsTab(this.label, this.icon, this.content);
}

// ==================== Taxi Settings ====================

final _taxiSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final response = await supabase
        .from('system_settings')
        .select()
        .eq('category', 'taxi');
    final settings = <String, dynamic>{};
    for (final row in List<Map<String, dynamic>>.from(response)) {
      settings[row['key'] as String] = row['value'];
    }
    return settings;
  } catch (_) {
    return <String, dynamic>{};
  }
});

class _TaxiSettingsContent extends ConsumerStatefulWidget {
  const _TaxiSettingsContent();

  @override
  ConsumerState<_TaxiSettingsContent> createState() => _TaxiSettingsContentState();
}

class _TaxiSettingsContentState extends ConsumerState<_TaxiSettingsContent> {
  final _formKey = GlobalKey<FormState>();
  final _commissionController = TextEditingController();
  final _baseFareController = TextEditingController();
  final _perKmController = TextEditingController();
  final _perMinController = TextEditingController();
  final _minFareController = TextEditingController();
  final _surgeMultiplierController = TextEditingController();
  final _maxWaitTimeController = TextEditingController();
  bool _isSaving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _commissionController.dispose();
    _baseFareController.dispose();
    _perKmController.dispose();
    _perMinController.dispose();
    _minFareController.dispose();
    _surgeMultiplierController.dispose();
    _maxWaitTimeController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> settings) {
    if (_loaded) return;
    _loaded = true;
    _commissionController.text = (settings['commission_rate'] ?? 20).toString();
    _baseFareController.text = (settings['base_fare'] ?? 30).toString();
    _perKmController.text = (settings['per_km_rate'] ?? 15).toString();
    _perMinController.text = (settings['per_min_rate'] ?? 3).toString();
    _minFareController.text = (settings['min_fare'] ?? 50).toString();
    _surgeMultiplierController.text = (settings['max_surge_multiplier'] ?? 3.0).toString();
    _maxWaitTimeController.text = (settings['max_wait_time_minutes'] ?? 10).toString();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final entries = {
        'commission_rate': num.tryParse(_commissionController.text) ?? 20,
        'base_fare': num.tryParse(_baseFareController.text) ?? 30,
        'per_km_rate': num.tryParse(_perKmController.text) ?? 15,
        'per_min_rate': num.tryParse(_perMinController.text) ?? 3,
        'min_fare': num.tryParse(_minFareController.text) ?? 50,
        'max_surge_multiplier': num.tryParse(_surgeMultiplierController.text) ?? 3.0,
        'max_wait_time_minutes': num.tryParse(_maxWaitTimeController.text) ?? 10,
      };

      for (final entry in entries.entries) {
        await supabase.from('system_settings').upsert({
          'category': 'taxi',
          'key': entry.key,
          'value': entry.value.toString(),
        }, onConflict: 'category,key');
      }

      ref.invalidate(_taxiSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taksi ayarları kaydedildi'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(_taxiSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (settings) {
        _populateFields(settings);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commission Section
                _SectorSettingsSection(
                  title: 'Komisyon',
                  icon: Icons.percent,
                  color: AppColors.warning,
                  children: [
                    _SectorSettingsField(
                      controller: _commissionController,
                      label: 'Komisyon Oranı',
                      hint: 'Yüzde olarak',
                      suffix: '%',
                      validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Fare Section
                _SectorSettingsSection(
                  title: 'Ücretlendirme',
                  icon: Icons.attach_money,
                  color: AppColors.success,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _baseFareController,
                            label: 'Açılış Ücreti',
                            suffix: '₺',
                            validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _perKmController,
                            label: 'Km Başına Ücret',
                            suffix: '₺/km',
                            validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _perMinController,
                            label: 'Dakika Başına Ücret',
                            suffix: '₺/dk',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _minFareController,
                            label: 'Minimum Ücret',
                            suffix: '₺',
                            validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Operational Section
                _SectorSettingsSection(
                  title: 'Operasyonel',
                  icon: Icons.tune,
                  color: AppColors.info,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _surgeMultiplierController,
                            label: 'Maks. Surge Çarpanı',
                            hint: 'Örn: 3.0',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _maxWaitTimeController,
                            label: 'Maks. Bekleme Süresi',
                            suffix: 'dk',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 18),
                    label: const Text('Kaydet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== Car Rental Settings ====================

final _carRentalSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final response = await supabase
        .from('system_settings')
        .select()
        .eq('category', 'car_rental');
    final settings = <String, dynamic>{};
    for (final row in List<Map<String, dynamic>>.from(response)) {
      settings[row['key'] as String] = row['value'];
    }
    return settings;
  } catch (_) {
    return <String, dynamic>{};
  }
});

class _CarRentalSettingsContent extends ConsumerStatefulWidget {
  const _CarRentalSettingsContent();

  @override
  ConsumerState<_CarRentalSettingsContent> createState() => _CarRentalSettingsContentState();
}

class _CarRentalSettingsContentState extends ConsumerState<_CarRentalSettingsContent> {
  final _formKey = GlobalKey<FormState>();
  final _commissionController = TextEditingController();
  final _minRentalDaysController = TextEditingController();
  final _maxRentalDaysController = TextEditingController();
  final _depositPercentController = TextEditingController();
  final _lateFeeController = TextEditingController();
  final _freeKmController = TextEditingController();
  final _extraKmFeeController = TextEditingController();
  bool _isSaving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _commissionController.dispose();
    _minRentalDaysController.dispose();
    _maxRentalDaysController.dispose();
    _depositPercentController.dispose();
    _lateFeeController.dispose();
    _freeKmController.dispose();
    _extraKmFeeController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> settings) {
    if (_loaded) return;
    _loaded = true;
    _commissionController.text = (settings['commission_rate'] ?? 15).toString();
    _minRentalDaysController.text = (settings['min_rental_days'] ?? 1).toString();
    _maxRentalDaysController.text = (settings['max_rental_days'] ?? 90).toString();
    _depositPercentController.text = (settings['deposit_percentage'] ?? 20).toString();
    _lateFeeController.text = (settings['late_return_fee_per_hour'] ?? 50).toString();
    _freeKmController.text = (settings['free_km_per_day'] ?? 300).toString();
    _extraKmFeeController.text = (settings['extra_km_fee'] ?? 5).toString();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final entries = {
        'commission_rate': num.tryParse(_commissionController.text) ?? 15,
        'min_rental_days': num.tryParse(_minRentalDaysController.text) ?? 1,
        'max_rental_days': num.tryParse(_maxRentalDaysController.text) ?? 90,
        'deposit_percentage': num.tryParse(_depositPercentController.text) ?? 20,
        'late_return_fee_per_hour': num.tryParse(_lateFeeController.text) ?? 50,
        'free_km_per_day': num.tryParse(_freeKmController.text) ?? 300,
        'extra_km_fee': num.tryParse(_extraKmFeeController.text) ?? 5,
      };

      for (final entry in entries.entries) {
        await supabase.from('system_settings').upsert({
          'category': 'car_rental',
          'key': entry.key,
          'value': entry.value.toString(),
        }, onConflict: 'category,key');
      }

      ref.invalidate(_carRentalSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Araç kiralama ayarları kaydedildi'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(_carRentalSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (settings) {
        _populateFields(settings);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commission Section
                _SectorSettingsSection(
                  title: 'Komisyon',
                  icon: Icons.percent,
                  color: AppColors.warning,
                  children: [
                    _SectorSettingsField(
                      controller: _commissionController,
                      label: 'Platform Komisyon Oranı',
                      hint: 'Yüzde olarak',
                      suffix: '%',
                      validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Rental Duration Section
                _SectorSettingsSection(
                  title: 'Kiralama Süreleri',
                  icon: Icons.schedule,
                  color: AppColors.info,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _minRentalDaysController,
                            label: 'Min. Kiralama Süresi',
                            suffix: 'gün',
                            validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _maxRentalDaysController,
                            label: 'Maks. Kiralama Süresi',
                            suffix: 'gün',
                            validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Financial Section
                _SectorSettingsSection(
                  title: 'Finansal Ayarlar',
                  icon: Icons.attach_money,
                  color: AppColors.success,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _depositPercentController,
                            label: 'Depozito Oranı',
                            suffix: '%',
                            validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _lateFeeController,
                            label: 'Geç Teslim Ücreti',
                            suffix: '₺/saat',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // KM Section
                _SectorSettingsSection(
                  title: 'Kilometre Ayarları',
                  icon: Icons.speed,
                  color: AppColors.primary,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _freeKmController,
                            label: 'Günlük Ücretsiz KM',
                            suffix: 'km',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SectorSettingsField(
                            controller: _extraKmFeeController,
                            label: 'Ekstra KM Ücreti',
                            suffix: '₺/km',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 18),
                    label: const Text('Kaydet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== Shared Sector Settings Widgets ====================

class _SectorSettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectorSettingsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SectorSettingsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final String? Function(String?)? validator;

  const _SectorSettingsField({
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: validator,
    );
  }
}
