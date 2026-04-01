import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/sector_type.dart';
import '../widgets/stat_card.dart';
import '../widgets/chart_card.dart';
import '../widgets/recent_orders_card.dart';
import '../widgets/top_merchants_card.dart';

// Dashboard stats provider - 7 hizmet için tüm istatistikleri alır
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final result = await supabase.rpc('get_dashboard_stats');
  final data = result as Map<String, dynamic>;

  return DashboardStats.fromJson(data);
});

// Daily revenue provider - son N günün gelir verilerini alır
final dailyRevenueProvider = FutureProvider.family<DailyRevenueData, int>((ref, days) async {
  final supabase = ref.watch(supabaseProvider);
  final result = await supabase.rpc('get_daily_revenue', params: {'p_days': days});
  return DailyRevenueData.fromJson(result as Map<String, dynamic>);
});

class DailyRevenueItem {
  final DateTime date;
  final String dayName;
  final double totalRevenue;
  final double foodRevenue;
  final double storeRevenue;
  final double taxiRevenue;
  final double rentalRevenue;

  DailyRevenueItem({
    required this.date,
    required this.dayName,
    required this.totalRevenue,
    required this.foodRevenue,
    required this.storeRevenue,
    required this.taxiRevenue,
    required this.rentalRevenue,
  });

  factory DailyRevenueItem.fromJson(Map<String, dynamic> json) {
    return DailyRevenueItem(
      date: DateTime.parse(json['date'] as String),
      dayName: json['day_name'] as String? ?? '',
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      foodRevenue: (json['food_revenue'] as num?)?.toDouble() ?? 0,
      storeRevenue: (json['store_revenue'] as num?)?.toDouble() ?? 0,
      taxiRevenue: (json['taxi_revenue'] as num?)?.toDouble() ?? 0,
      rentalRevenue: (json['rental_revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DailyRevenueData {
  final List<DailyRevenueItem> days;
  final double total;
  final double average;
  final double max;
  final double min;

  DailyRevenueData({
    required this.days,
    required this.total,
    required this.average,
    required this.max,
    required this.min,
  });

  factory DailyRevenueData.fromJson(Map<String, dynamic> json) {
    final daysList = (json['days'] as List<dynamic>?)
        ?.map((e) => DailyRevenueItem.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    return DailyRevenueData(
      days: daysList,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      max: (json['max'] as num?)?.toDouble() ?? 0,
      min: (json['min'] as num?)?.toDouble() ?? 0,
    );
  }
}

// Nested model for each service
class ServiceStats {
  final int count;
  final int activeCount;
  final int pendingCount;
  final int ordersCount;
  final int todayOrders;
  final double revenue;
  final double avgRating;

  ServiceStats({
    this.count = 0,
    this.activeCount = 0,
    this.pendingCount = 0,
    this.ordersCount = 0,
    this.todayOrders = 0,
    this.revenue = 0,
    this.avgRating = 0,
  });
}

class TaxiStats {
  final int driversCount;
  final int activeDrivers;
  final int pendingDrivers;
  final int ridesCount;
  final int todayRides;
  final int activeRides;
  final int completedRides;
  final double revenue;
  final double avgRating;

  TaxiStats({
    this.driversCount = 0,
    this.activeDrivers = 0,
    this.pendingDrivers = 0,
    this.ridesCount = 0,
    this.todayRides = 0,
    this.activeRides = 0,
    this.completedRides = 0,
    this.revenue = 0,
    this.avgRating = 0,
  });
}

class RentalStats {
  final int companiesCount;
  final int pendingCompanies;
  final int carsCount;
  final int availableCars;
  final int bookingsCount;
  final int todayBookings;
  final int activeBookings;
  final double revenue;
  final double avgRating;

  RentalStats({
    this.companiesCount = 0,
    this.pendingCompanies = 0,
    this.carsCount = 0,
    this.availableCars = 0,
    this.bookingsCount = 0,
    this.todayBookings = 0,
    this.activeBookings = 0,
    this.revenue = 0,
    this.avgRating = 0,
  });
}

class CarSalesStats {
  final int dealersCount;
  final int pendingDealers;
  final int individualSellers;
  final int listingsCount;
  final int activeListings;
  final int pendingListings;
  final int soldListings;
  final int todayListings;
  final int contactRequests;
  final int todayContacts;

  CarSalesStats({
    this.dealersCount = 0,
    this.pendingDealers = 0,
    this.individualSellers = 0,
    this.listingsCount = 0,
    this.activeListings = 0,
    this.pendingListings = 0,
    this.soldListings = 0,
    this.todayListings = 0,
    this.contactRequests = 0,
    this.todayContacts = 0,
  });
}

class EmlakStats {
  final int realtorsCount;
  final int pendingRealtors;
  final int propertiesCount;
  final int activeProperties;
  final int pendingProperties;
  final int soldProperties;
  final int rentedProperties;
  final int todayProperties;
  final int propertyViews;
  final int todayViews;
  final double avgRating;

  EmlakStats({
    this.realtorsCount = 0,
    this.pendingRealtors = 0,
    this.propertiesCount = 0,
    this.activeProperties = 0,
    this.pendingProperties = 0,
    this.soldProperties = 0,
    this.rentedProperties = 0,
    this.todayProperties = 0,
    this.propertyViews = 0,
    this.todayViews = 0,
    this.avgRating = 0,
  });
}

class JobsStats {
  final int postersCount;
  final int pendingPosters;
  final int listingsCount;
  final int activeListings;
  final int pendingListings;
  final int expiredListings;
  final int todayListings;
  final int applicationsCount;
  final int todayApplications;
  final int pendingApplications;

  JobsStats({
    this.postersCount = 0,
    this.pendingPosters = 0,
    this.listingsCount = 0,
    this.activeListings = 0,
    this.pendingListings = 0,
    this.expiredListings = 0,
    this.todayListings = 0,
    this.applicationsCount = 0,
    this.todayApplications = 0,
    this.pendingApplications = 0,
  });
}

class GeneralStats {
  final int totalUsers;
  final int couriersCount;
  final int activeCouriers;
  final int onlineCouriers;
  final int partnersCount;
  final double totalRevenue;

  GeneralStats({
    this.totalUsers = 0,
    this.couriersCount = 0,
    this.activeCouriers = 0,
    this.onlineCouriers = 0,
    this.partnersCount = 0,
    this.totalRevenue = 0,
  });
}

class SummaryStats {
  final int totalBusinesses;
  final int totalActiveListings;
  final int todayTotalTransactions;

  SummaryStats({
    this.totalBusinesses = 0,
    this.totalActiveListings = 0,
    this.todayTotalTransactions = 0,
  });
}

class DashboardStats {
  final GeneralStats general;
  final ServiceStats restaurants;
  final ServiceStats markets;
  final ServiceStats stores;
  final TaxiStats taxi;
  final RentalStats rental;
  final CarSalesStats carSales;
  final EmlakStats emlak;
  final JobsStats jobs;
  final SummaryStats summary;

  DashboardStats({
    required this.general,
    required this.restaurants,
    required this.markets,
    required this.stores,
    required this.taxi,
    required this.rental,
    required this.carSales,
    required this.emlak,
    required this.jobs,
    required this.summary,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final generalData = json['general'] as Map<String, dynamic>? ?? {};
    final restaurantsData = json['restaurants'] as Map<String, dynamic>? ?? {};
    final marketsData = json['markets'] as Map<String, dynamic>? ?? {};
    final storesData = json['stores'] as Map<String, dynamic>? ?? {};
    final taxiData = json['taxi'] as Map<String, dynamic>? ?? {};
    final rentalData = json['rental'] as Map<String, dynamic>? ?? {};
    final carSalesData = json['car_sales'] as Map<String, dynamic>? ?? {};
    final emlakData = json['emlak'] as Map<String, dynamic>? ?? {};
    final jobsData = json['jobs'] as Map<String, dynamic>? ?? {};
    final summaryData = json['summary'] as Map<String, dynamic>? ?? {};

    return DashboardStats(
      general: GeneralStats(
        totalUsers: generalData['total_users_count'] as int? ?? 0,
        couriersCount: generalData['couriers_count'] as int? ?? 0,
        activeCouriers: generalData['active_couriers_count'] as int? ?? 0,
        onlineCouriers: generalData['online_couriers_count'] as int? ?? 0,
        partnersCount: generalData['partners_count'] as int? ?? 0,
        totalRevenue: (generalData['total_revenue'] as num?)?.toDouble() ?? 0,
      ),
      restaurants: ServiceStats(
        count: restaurantsData['count'] as int? ?? 0,
        activeCount: restaurantsData['active_count'] as int? ?? 0,
        pendingCount: restaurantsData['pending_count'] as int? ?? 0,
        ordersCount: restaurantsData['orders_count'] as int? ?? 0,
        todayOrders: restaurantsData['today_orders'] as int? ?? 0,
        revenue: (restaurantsData['revenue'] as num?)?.toDouble() ?? 0,
        avgRating: (restaurantsData['avg_rating'] as num?)?.toDouble() ?? 0,
      ),
      markets: ServiceStats(
        count: marketsData['count'] as int? ?? 0,
        activeCount: marketsData['active_count'] as int? ?? 0,
        pendingCount: marketsData['pending_count'] as int? ?? 0,
        ordersCount: marketsData['orders_count'] as int? ?? 0,
        todayOrders: marketsData['today_orders'] as int? ?? 0,
        revenue: (marketsData['revenue'] as num?)?.toDouble() ?? 0,
        avgRating: (marketsData['avg_rating'] as num?)?.toDouble() ?? 0,
      ),
      stores: ServiceStats(
        count: storesData['count'] as int? ?? 0,
        activeCount: storesData['active_count'] as int? ?? 0,
        pendingCount: storesData['pending_count'] as int? ?? 0,
        ordersCount: storesData['orders_count'] as int? ?? 0,
        todayOrders: storesData['today_orders'] as int? ?? 0,
        revenue: (storesData['revenue'] as num?)?.toDouble() ?? 0,
        avgRating: (storesData['avg_rating'] as num?)?.toDouble() ?? 0,
      ),
      taxi: TaxiStats(
        driversCount: taxiData['drivers_count'] as int? ?? 0,
        activeDrivers: taxiData['active_drivers'] as int? ?? 0,
        pendingDrivers: taxiData['pending_drivers'] as int? ?? 0,
        ridesCount: taxiData['rides_count'] as int? ?? 0,
        todayRides: taxiData['today_rides'] as int? ?? 0,
        activeRides: taxiData['active_rides'] as int? ?? 0,
        completedRides: taxiData['completed_rides'] as int? ?? 0,
        revenue: (taxiData['revenue'] as num?)?.toDouble() ?? 0,
        avgRating: (taxiData['avg_rating'] as num?)?.toDouble() ?? 0,
      ),
      rental: RentalStats(
        companiesCount: rentalData['companies_count'] as int? ?? 0,
        pendingCompanies: rentalData['pending_companies'] as int? ?? 0,
        carsCount: rentalData['cars_count'] as int? ?? 0,
        availableCars: rentalData['available_cars'] as int? ?? 0,
        bookingsCount: rentalData['bookings_count'] as int? ?? 0,
        todayBookings: rentalData['today_bookings'] as int? ?? 0,
        activeBookings: rentalData['active_bookings'] as int? ?? 0,
        revenue: (rentalData['revenue'] as num?)?.toDouble() ?? 0,
        avgRating: (rentalData['avg_rating'] as num?)?.toDouble() ?? 0,
      ),
      carSales: CarSalesStats(
        dealersCount: carSalesData['dealers_count'] as int? ?? 0,
        pendingDealers: carSalesData['pending_dealers'] as int? ?? 0,
        individualSellers: carSalesData['individual_sellers'] as int? ?? 0,
        listingsCount: carSalesData['listings_count'] as int? ?? 0,
        activeListings: carSalesData['active_listings'] as int? ?? 0,
        pendingListings: carSalesData['pending_listings'] as int? ?? 0,
        soldListings: carSalesData['sold_listings'] as int? ?? 0,
        todayListings: carSalesData['today_listings'] as int? ?? 0,
        contactRequests: carSalesData['contact_requests'] as int? ?? 0,
        todayContacts: carSalesData['today_contacts'] as int? ?? 0,
      ),
      emlak: EmlakStats(
        realtorsCount: emlakData['realtors_count'] as int? ?? 0,
        pendingRealtors: emlakData['pending_realtors'] as int? ?? 0,
        propertiesCount: emlakData['properties_count'] as int? ?? 0,
        activeProperties: emlakData['active_properties'] as int? ?? 0,
        pendingProperties: emlakData['pending_properties'] as int? ?? 0,
        soldProperties: emlakData['sold_properties'] as int? ?? 0,
        rentedProperties: emlakData['rented_properties'] as int? ?? 0,
        todayProperties: emlakData['today_properties'] as int? ?? 0,
        propertyViews: emlakData['property_views'] as int? ?? 0,
        todayViews: emlakData['today_views'] as int? ?? 0,
        avgRating: (emlakData['avg_rating'] as num?)?.toDouble() ?? 0,
      ),
      jobs: JobsStats(
        postersCount: jobsData['posters_count'] as int? ?? 0,
        pendingPosters: jobsData['pending_posters'] as int? ?? 0,
        listingsCount: jobsData['listings_count'] as int? ?? 0,
        activeListings: jobsData['active_listings'] as int? ?? 0,
        pendingListings: jobsData['pending_listings'] as int? ?? 0,
        expiredListings: jobsData['expired_listings'] as int? ?? 0,
        todayListings: jobsData['today_listings'] as int? ?? 0,
        applicationsCount: jobsData['applications_count'] as int? ?? 0,
        todayApplications: jobsData['today_applications'] as int? ?? 0,
        pendingApplications: jobsData['pending_applications'] as int? ?? 0,
      ),
      summary: SummaryStats(
        totalBusinesses: summaryData['total_businesses'] as int? ?? 0,
        totalActiveListings: summaryData['total_active_listings'] as int? ?? 0,
        todayTotalTransactions: summaryData['today_total_transactions'] as int? ?? 0,
      ),
    );
  }
}

// Son 10 aktivite provider
final recentActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  // Son siparişler, rezervasyonlar ve yeni kayıtları birleştir
  final orders = await supabase
      .from('orders')
      .select('id, customer_name, total_amount, status, created_at, merchant_id, merchants(business_name)')
      .order('created_at', ascending: false)
      .limit(5);

  final activities = <Map<String, dynamic>>[];

  for (final order in orders) {
    activities.add({
      'type': 'order',
      'icon': 'receipt',
      'title': '${order['customer_name'] ?? 'Müşteri'} yeni sipariş verdi',
      'subtitle': order['merchants']?['business_name'] ?? '',
      'amount': order['total_amount'],
      'status': order['status'],
      'created_at': order['created_at'],
    });
  }

  // Son 5 yeni işletme kaydı
  try {
    final merchants = await supabase
        .from('merchants')
        .select('id, business_name, type, is_approved, created_at')
        .order('created_at', ascending: false)
        .limit(5);

    for (final m in merchants) {
      activities.add({
        'type': 'merchant',
        'icon': 'store',
        'title': '${m['business_name'] ?? 'İşletme'} kaydoldu',
        'subtitle': _merchantTypeLabel(m['type'] as String?),
        'status': m['is_approved'] == true ? 'active' : 'pending',
        'created_at': m['created_at'],
      });
    }
  } catch (_) {}

  // Sort by created_at descending, take 10
  activities.sort((a, b) {
    final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
    final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
    return bDate.compareTo(aDate);
  });

  return activities.take(10).toList();
});

String _merchantTypeLabel(String? type) {
  switch (type) {
    case 'restaurant':
      return 'Restoran';
    case 'market':
      return 'Market';
    case 'store':
      return 'Mağaza';
    default:
      return 'İşletme';
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final dailyRevenueAsync = ref.watch(dailyRevenueProvider(7));
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hoş geldiniz! İşte platformunuzun özeti.',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildDateRangeButton(),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rapor indirme özelliği yakında eklenecek')),
                        );
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Rapor İndir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ==================== SEKTÖR ÖZET KARTLARI ====================
            statsAsync.when(
              data: (stats) => _buildSectorSummaryCards(context, stats),
              loading: () => _buildSectorSummaryCardsLoading(),
              error: (e, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Stats Cards
            statsAsync.when(
              data: (stats) => _buildStatsGrid(stats),
              loading: () => _buildStatsGridLoading(),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),

            const SizedBox(height: 24),

            // Charts Row (responsive)
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              if (isNarrow) {
                return Column(
                  children: [
                    ChartCard(
                      title: 'Gelir Grafiği',
                      subtitle: 'Son 7 gün',
                      chart: dailyRevenueAsync.when(
                        data: (data) => _buildRevenueChart(data),
                        loading: () => _buildRevenueChartLoading(),
                        error: (e, _) => Center(child: Text('Hata: $e')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ChartCard(
                      title: 'Hizmet Dağılımı',
                      subtitle: 'İşlem bazında',
                      chart: statsAsync.maybeWhen(
                        data: (stats) => _buildPieChart(stats),
                        orElse: () => _buildPieChart(null),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: ChartCard(
                      title: 'Gelir Grafiği',
                      subtitle: 'Son 7 gün',
                      chart: dailyRevenueAsync.when(
                        data: (data) => _buildRevenueChart(data),
                        loading: () => _buildRevenueChartLoading(),
                        error: (e, _) => Center(child: Text('Hata: $e')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ChartCard(
                      title: 'Hizmet Dağılımı',
                      subtitle: 'İşlem bazında',
                      chart: statsAsync.maybeWhen(
                        data: (stats) => _buildPieChart(stats),
                        orElse: () => _buildPieChart(null),
                      ),
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 24),

            // Bottom Row: Recent Orders + Top Merchants (responsive)
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return const Column(
                  children: [
                    RecentOrdersCard(),
                    SizedBox(height: 16),
                    TopMerchantsCard(),
                  ],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: RecentOrdersCard()),
                  SizedBox(width: 24),
                  Expanded(child: TopMerchantsCard()),
                ],
              );
            }),

            const SizedBox(height: 24),

            // ==================== SON 10 AKTİVİTE ====================
            _buildRecentActivitySection(activityAsync),
          ],
        ),
      ),
    );
  }

  /// Sektör özet kartları - tıklanabilir, sektöre navigasyon
  Widget _buildSectorSummaryCards(BuildContext context, DashboardStats stats) {
    final sectors = [
      _SectorSummary(SectorType.food, 'Yemek', Icons.restaurant_rounded, Colors.deepOrange,
          stats.restaurants.count, stats.restaurants.todayOrders, stats.restaurants.revenue),
      _SectorSummary(SectorType.market, 'Market', Icons.local_grocery_store_rounded, Colors.green,
          stats.markets.count, stats.markets.todayOrders, stats.markets.revenue),
      _SectorSummary(SectorType.store, 'Mağaza', Icons.storefront_rounded, Colors.teal,
          stats.stores.count, stats.stores.todayOrders, stats.stores.revenue),
      _SectorSummary(SectorType.taxi, 'Taksi', Icons.local_taxi_rounded, Colors.amber.shade700,
          stats.taxi.driversCount, stats.taxi.todayRides, stats.taxi.revenue),
      _SectorSummary(SectorType.realEstate, 'Emlak', Icons.home_work_rounded, Colors.indigo,
          stats.emlak.realtorsCount, stats.emlak.todayProperties, 0),
      _SectorSummary(SectorType.carSales, 'Galeri', Icons.directions_car_filled_rounded, Colors.cyan.shade700,
          stats.carSales.dealersCount, stats.carSales.todayListings, 0),
      _SectorSummary(SectorType.jobs, 'İş İlanları', Icons.work_rounded, Colors.deepPurple,
          stats.jobs.postersCount, stats.jobs.todayListings, 0),
      _SectorSummary(SectorType.carRental, 'Kiralama', Icons.car_rental_rounded, Colors.blue,
          stats.rental.companiesCount, stats.rental.todayBookings, stats.rental.revenue),
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 900 ? 2 : (width < 1200 ? 3 : 4);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: sectors.length,
      itemBuilder: (context, index) {
        final s = sectors[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(s.sector.baseRoute),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: s.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s.icon, color: s.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s.label,
                          style: TextStyle(
                            color: s.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.businessCount} işletme',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${s.todayCount}',
                        style: TextStyle(
                          color: s.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'bugün',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: s.color.withValues(alpha: 0.5), size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectorSummaryCardsLoading() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  /// Son 10 aktivite bölümü
  Widget _buildRecentActivitySection(AsyncValue<List<Map<String, dynamic>>> activityAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.update_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text(
                'Son Aktiviteler',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          activityAsync.when(
            data: (activities) {
              if (activities.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Henüz aktivite yok', style: TextStyle(color: AppColors.textMuted))),
                );
              }
              return Column(
                children: activities.map((a) => _buildActivityRow(a)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Center(
              child: Padding(padding: const EdgeInsets.all(24), child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> activity) {
    final type = activity['type'] as String? ?? '';
    final title = activity['title'] as String? ?? '';
    final subtitle = activity['subtitle'] as String? ?? '';
    final status = activity['status'] as String? ?? '';
    final createdAt = DateTime.tryParse(activity['created_at']?.toString() ?? '');
    final timeAgo = createdAt != null ? _timeAgo(createdAt) : '';

    IconData icon;
    Color iconColor;
    if (type == 'order') {
      icon = Icons.receipt_long_rounded;
      iconColor = AppColors.primary;
    } else {
      icon = Icons.store_rounded;
      iconColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (status.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          Text(timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    return '${diff.inDays}g';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
      case 'active':
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      case 'preparing':
      case 'on_the_way':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'delivered':
        return 'Teslim';
      case 'active':
        return 'Aktif';
      case 'approved':
        return 'Onaylı';
      case 'pending':
        return 'Bekliyor';
      case 'cancelled':
        return 'İptal';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'on_the_way':
        return 'Yolda';
      default:
        return status;
    }
  }

  Widget _buildDateRangeButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Text(
            'Son 7 Gün',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================
        // GENEL ÖZET
        // ============================================
        _buildSectionHeader('Genel Özet', Icons.dashboard_rounded, AppColors.primary),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Toplam Kullanıcı',
              value: _formatNumber(stats.general.totalUsers),
              icon: Icons.people_rounded,
              color: AppColors.info,
            ),
            StatCard(
              title: 'Toplam İşletme',
              value: _formatNumber(stats.summary.totalBusinesses),
              icon: Icons.business_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Aktif İlan',
              value: _formatNumber(stats.summary.totalActiveListings),
              icon: Icons.list_alt_rounded,
              color: Colors.orange,
            ),
            StatCard(
              title: 'Bugünkü İşlem',
              value: _formatNumber(stats.summary.todayTotalTransactions),
              icon: Icons.trending_up_rounded,
              color: Colors.purple,
            ),
            StatCard(
              title: 'Toplam Gelir',
              value: '${_formatNumber(stats.general.totalRevenue.toInt())} ₺',
              icon: Icons.monetization_on_rounded,
              color: AppColors.primary,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ============================================
        // 1. YEMEK
        // ============================================
        _buildSectionHeader('Yemek', Icons.restaurant_rounded, Colors.deepOrange),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Restoran',
              value: _formatNumber(stats.restaurants.count),
              icon: Icons.storefront_rounded,
              color: Colors.deepOrange,
              subtitle: '${stats.restaurants.activeCount} açık',
            ),
            StatCard(
              title: 'Onay Bekleyen',
              value: _formatNumber(stats.restaurants.pendingCount),
              icon: Icons.pending_rounded,
              color: AppColors.warning,
            ),
            StatCard(
              title: 'Toplam Sipariş',
              value: _formatNumber(stats.restaurants.ordersCount),
              icon: Icons.receipt_long_rounded,
              color: AppColors.info,
            ),
            StatCard(
              title: 'Bugün Sipariş',
              value: _formatNumber(stats.restaurants.todayOrders),
              icon: Icons.today_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Gelir',
              value: '${_formatNumber(stats.restaurants.revenue.toInt())} ₺',
              icon: Icons.payments_rounded,
              color: AppColors.primary,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ============================================
        // 2. MARKET/MAĞAZA
        // ============================================
        _buildSectionHeader('Market / Mağaza', Icons.local_grocery_store_rounded, Colors.green),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Mağaza',
              value: _formatNumber(stats.stores.count),
              icon: Icons.store_rounded,
              color: Colors.green,
              subtitle: '${stats.stores.activeCount} açık',
            ),
            StatCard(
              title: 'Onay Bekleyen',
              value: _formatNumber(stats.stores.pendingCount),
              icon: Icons.pending_rounded,
              color: AppColors.warning,
            ),
            StatCard(
              title: 'Toplam Sipariş',
              value: _formatNumber(stats.stores.ordersCount),
              icon: Icons.shopping_bag_rounded,
              color: AppColors.info,
            ),
            StatCard(
              title: 'Bugün Sipariş',
              value: _formatNumber(stats.stores.todayOrders),
              icon: Icons.today_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Gelir',
              value: '${_formatNumber(stats.stores.revenue.toInt())} ₺',
              icon: Icons.payments_rounded,
              color: AppColors.primary,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ============================================
        // 3. TAKSİ
        // ============================================
        _buildSectionHeader('Taksi', Icons.local_taxi_rounded, Colors.amber.shade700),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Şoför',
              value: _formatNumber(stats.taxi.driversCount),
              icon: Icons.person_rounded,
              color: Colors.amber.shade700,
              subtitle: '${stats.taxi.activeDrivers} aktif',
            ),
            StatCard(
              title: 'Onay Bekleyen',
              value: _formatNumber(stats.taxi.pendingDrivers),
              icon: Icons.pending_rounded,
              color: AppColors.warning,
            ),
            StatCard(
              title: 'Bugün Yolculuk',
              value: _formatNumber(stats.taxi.todayRides),
              icon: Icons.route_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Aktif Yolculuk',
              value: _formatNumber(stats.taxi.activeRides),
              icon: Icons.directions_car_rounded,
              color: AppColors.info,
            ),
            StatCard(
              title: 'Gelir',
              value: '${_formatNumber(stats.taxi.revenue.toInt())} ₺',
              icon: Icons.payments_rounded,
              color: AppColors.primary,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ============================================
        // 4. ARAÇ KİRALAMA
        // ============================================
        _buildSectionHeader('Araç Kiralama', Icons.car_rental_rounded, Colors.blue),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Firma',
              value: _formatNumber(stats.rental.companiesCount),
              icon: Icons.business_rounded,
              color: Colors.blue,
              subtitle: '${stats.rental.pendingCompanies} bekliyor',
            ),
            StatCard(
              title: 'Araç',
              value: _formatNumber(stats.rental.carsCount),
              icon: Icons.directions_car_rounded,
              color: Colors.blueGrey,
              subtitle: '${stats.rental.availableCars} müsait',
            ),
            StatCard(
              title: 'Bugün Rezerv.',
              value: _formatNumber(stats.rental.todayBookings),
              icon: Icons.calendar_today_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Aktif Kiralama',
              value: _formatNumber(stats.rental.activeBookings),
              icon: Icons.key_rounded,
              color: AppColors.info,
            ),
            StatCard(
              title: 'Gelir',
              value: '${_formatNumber(stats.rental.revenue.toInt())} ₺',
              icon: Icons.payments_rounded,
              color: AppColors.primary,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ============================================
        // 5. ARAÇ SATIŞ
        // ============================================
        _buildSectionHeader('Araç Satış', Icons.directions_car_filled_rounded, Colors.teal),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Galeri',
              value: _formatNumber(stats.carSales.dealersCount),
              icon: Icons.garage_rounded,
              color: Colors.teal,
              subtitle: '${stats.carSales.pendingDealers} bekliyor',
            ),
            StatCard(
              title: 'Bireysel Satıcı',
              value: _formatNumber(stats.carSales.individualSellers),
              icon: Icons.person_rounded,
              color: Colors.cyan,
            ),
            StatCard(
              title: 'Aktif İlan',
              value: _formatNumber(stats.carSales.activeListings),
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              subtitle: '${stats.carSales.pendingListings} onay bkl.',
            ),
            StatCard(
              title: 'Satılan',
              value: _formatNumber(stats.carSales.soldListings),
              icon: Icons.sell_rounded,
              color: AppColors.primary,
            ),
            StatCard(
              title: 'İletişim Talep',
              value: _formatNumber(stats.carSales.contactRequests),
              icon: Icons.contact_phone_rounded,
              color: AppColors.info,
              subtitle: '${stats.carSales.todayContacts} bugün',
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ============================================
        // 6. EMLAK
        // ============================================
        _buildSectionHeader('Emlak', Icons.home_rounded, Colors.indigo),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Emlakçı',
              value: _formatNumber(stats.emlak.realtorsCount),
              icon: Icons.real_estate_agent_rounded,
              color: Colors.indigo,
              subtitle: '${stats.emlak.pendingRealtors} bekliyor',
            ),
            StatCard(
              title: 'Aktif İlan',
              value: _formatNumber(stats.emlak.activeProperties),
              icon: Icons.home_work_rounded,
              color: AppColors.success,
              subtitle: '${stats.emlak.pendingProperties} onay bkl.',
            ),
            StatCard(
              title: 'Satılan',
              value: _formatNumber(stats.emlak.soldProperties),
              icon: Icons.sell_rounded,
              color: AppColors.primary,
            ),
            StatCard(
              title: 'Kiralanan',
              value: _formatNumber(stats.emlak.rentedProperties),
              icon: Icons.vpn_key_rounded,
              color: Colors.purple,
            ),
            StatCard(
              title: 'Görüntülenme',
              value: _formatNumber(stats.emlak.propertyViews),
              icon: Icons.visibility_rounded,
              color: AppColors.info,
              subtitle: '${stats.emlak.todayViews} bugün',
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ============================================
        // 7. İŞ İLANLARI
        // ============================================
        _buildSectionHeader('İş İlanları', Icons.work_rounded, Colors.deepPurple),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'İşveren',
              value: _formatNumber(stats.jobs.postersCount),
              icon: Icons.business_center_rounded,
              color: Colors.deepPurple,
              subtitle: '${stats.jobs.pendingPosters} bekliyor',
            ),
            StatCard(
              title: 'Aktif İlan',
              value: _formatNumber(stats.jobs.activeListings),
              icon: Icons.work_rounded,
              color: AppColors.success,
              subtitle: '${stats.jobs.pendingListings} onay bkl.',
            ),
            StatCard(
              title: 'Başvuru',
              value: _formatNumber(stats.jobs.applicationsCount),
              icon: Icons.assignment_rounded,
              color: AppColors.info,
              subtitle: '${stats.jobs.todayApplications} bugün',
            ),
            StatCard(
              title: 'Bekleyen Başvuru',
              value: _formatNumber(stats.jobs.pendingApplications),
              icon: Icons.pending_actions_rounded,
              color: AppColors.warning,
            ),
            StatCard(
              title: 'Süresi Dolan',
              value: _formatNumber(stats.jobs.expiredListings),
              icon: Icons.event_busy_rounded,
              color: Colors.grey,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ============================================
        // KURYE & PARTNER
        // ============================================
        _buildSectionHeader('Kurye & Partner', Icons.delivery_dining_rounded, Colors.orange),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Kurye',
              value: _formatNumber(stats.general.couriersCount),
              icon: Icons.delivery_dining_rounded,
              color: Colors.orange,
              subtitle: '${stats.general.onlineCouriers} online',
            ),
            StatCard(
              title: 'Müsait Kurye',
              value: _formatNumber(stats.general.activeCouriers),
              icon: Icons.person_pin_circle_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Partner',
              value: _formatNumber(stats.general.partnersCount),
              icon: Icons.handshake_rounded,
              color: AppColors.info,
            ),
            StatCard(
              title: 'Ort. Puan',
              value: stats.restaurants.avgRating > 0
                  ? stats.restaurants.avgRating.toStringAsFixed(1)
                  : '-',
              icon: Icons.star_rounded,
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGridLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 8; i++) ...[
          _buildSectionHeaderLoading(),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 3.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(5, (_) => const StatCardLoading()),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _buildSectionHeaderLoading() {
    return Container(
      width: 180,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildRevenueChartLoading() {
    return SizedBox(
      height: 250,
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildRevenueChart(DailyRevenueData data) {
    // Build FlSpot list from real data
    final spots = <FlSpot>[];
    for (int i = 0; i < data.days.length; i++) {
      spots.add(FlSpot(i.toDouble(), data.days[i].totalRevenue));
    }

    // Calculate maxY dynamically based on actual data
    final maxRevenue = data.max > 0 ? data.max : 1000.0;
    final maxY = (maxRevenue * 1.2).ceil().toDouble(); // Add 20% padding

    // Calculate horizontal interval
    final double interval = maxY > 0 ? (maxY / 4).ceil().toDouble() : 1000.0;

    // Turkish day names mapping
    const dayNames = {
      'Mon': 'Pzt', 'Tue': 'Sal', 'Wed': 'Çar',
      'Thu': 'Per', 'Fri': 'Cum', 'Sat': 'Cmt', 'Sun': 'Paz'
    };

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  '${(value / 1000).toInt()}K',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.days.length) {
                    final dayName = data.days[index].dayName;
                    final turkishDay = dayNames[dayName] ?? dayName;
                    return Text(
                      turkishDay,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          minY: 0,
          maxY: maxY,
        ),
      ),
    );
  }

  Widget _buildPieChart(DashboardStats? stats) {
    // Calculate percentages based on real data
    final restaurantOrders = stats?.restaurants.ordersCount ?? 0;
    final storeOrders = stats?.stores.ordersCount ?? 0;
    final taxiRides = stats?.taxi.ridesCount ?? 0;
    final rentalBookings = stats?.rental.bookingsCount ?? 0;

    final total = restaurantOrders + storeOrders + taxiRides + rentalBookings;
    final hasData = total > 0;

    return SizedBox(
      height: 250,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: hasData ? [
                  PieChartSectionData(
                    value: restaurantOrders.toDouble(),
                    title: '${((restaurantOrders / total) * 100).toInt()}%',
                    color: Colors.deepOrange,
                    radius: 45,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: storeOrders.toDouble(),
                    title: '${((storeOrders / total) * 100).toInt()}%',
                    color: Colors.green,
                    radius: 45,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: taxiRides.toDouble(),
                    title: '${((taxiRides / total) * 100).toInt()}%',
                    color: Colors.amber.shade700,
                    radius: 45,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: rentalBookings.toDouble(),
                    title: '${((rentalBookings / total) * 100).toInt()}%',
                    color: Colors.blue,
                    radius: 45,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ] : [
                  PieChartSectionData(
                    value: 1,
                    title: '',
                    color: AppColors.surfaceLight,
                    radius: 45,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Yemek', Colors.deepOrange),
              _buildLegendItem('Market', Colors.green),
              _buildLegendItem('Taksi', Colors.amber.shade700),
              _buildLegendItem('Kiralama', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _SectorSummary {
  final SectorType sector;
  final String label;
  final IconData icon;
  final Color color;
  final int businessCount;
  final int todayCount;
  final double revenue;

  const _SectorSummary(
    this.sector,
    this.label,
    this.icon,
    this.color,
    this.businessCount,
    this.todayCount,
    this.revenue,
  );
}
