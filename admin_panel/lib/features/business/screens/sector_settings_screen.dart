import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/sector_type.dart';
import '../../../core/theme/app_theme.dart';

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
          _SettingsTab('Genel Ayarlar', Icons.settings_outlined, const _PlaceholderContent(message: 'Taksi ayarları yakında aktif olacak')),
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
          _SettingsTab('Genel Ayarlar', Icons.settings_outlined, const _PlaceholderContent(message: 'Araç kiralama ayarları yakında aktif olacak')),
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

class _PlaceholderContent extends StatelessWidget {
  final String message;

  const _PlaceholderContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
