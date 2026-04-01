import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sector_type.dart';
import '../services/admin_auth_service.dart';
import '../services/permission_config.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/users/screens/users_screen.dart';
import '../../features/partners/screens/partners_screen.dart';
import '../../features/finance/screens/finance_dashboard_screen.dart';
import '../../features/finance/screens/income_expense_screen.dart';
import '../../features/finance/screens/commission_management_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/banners/screens/banners_screen.dart';
import '../../features/banners/screens/banner_packages_screen.dart';
import '../../features/invoices/screens/invoices_screen.dart';
import '../../features/applications/screens/applications_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/sanctions/screens/sanctions_screen.dart';
import '../../features/logs/screens/logs_screen.dart';
import '../../features/security/screens/security_screen.dart';
import '../../features/system_health/screens/system_health_screen.dart';
import '../../features/support/screens/ai_support_screen.dart';
// Eski sektör ekran importları kaldırıldı (dosyalar hala mevcut)
import '../../features/courier/screens/courier_vehicle_types_screen.dart';
import '../../features/support_agents/screens/support_agents_screen.dart';
import '../../features/support_monitoring/screens/support_dashboard_screen.dart';
import '../../features/support_monitoring/screens/ticket_review_screen.dart';
import '../../features/support_monitoring/screens/agent_performance_screen.dart';
import '../../features/support_monitoring/screens/support_reports_screen.dart';
import '../../features/support_monitoring/screens/order_history_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/promotions/screens/promotion_requests_screen.dart';
import '../../features/business/screens/business_listing_screen.dart';
import '../../features/business/screens/business_overview_screen.dart';
import '../../features/business/screens/sector_settings_screen.dart';
import '../../features/business/screens/placeholder_tab_screen.dart';
import '../../features/business/widgets/business_detail_shell.dart';
import '../../features/merchant_management/screens/admin_orders_kanban_screen.dart';
import '../../features/merchant_management/screens/admin_menu_screen.dart';
import '../../features/merchant_management/screens/admin_products_screen.dart';
import '../../features/merchant_management/screens/admin_inventory_screen.dart';
import '../../features/merchant_management/screens/admin_merchant_finance_screen.dart';
import '../../features/merchant_management/screens/admin_reviews_screen.dart';
import '../../features/merchant_management/screens/admin_couriers_screen.dart';
import '../../features/merchant_management/screens/admin_messages_screen.dart';
import '../../features/merchant_management/screens/admin_merchant_settings_screen.dart';
// Emlak Management (Phase 3)
import '../../features/emlak_management/screens/admin_property_listings_screen.dart';
import '../../features/emlak_management/screens/admin_crm_screen.dart';
import '../../features/emlak_management/screens/admin_appointments_screen.dart';
import '../../features/emlak_management/screens/admin_emlak_analytics_screen.dart';
// Car Sales Management (Phase 3)
import '../../features/car_sales_management/screens/admin_car_listings_screen.dart';
import '../../features/car_sales_management/screens/admin_car_performance_screen.dart';
import '../../features/car_sales_management/screens/admin_dealer_messages_screen.dart';
// Taxi Management (Phase 4)
import '../../features/taxi_management/screens/admin_rides_screen.dart';
import '../../features/taxi_management/screens/admin_driver_earnings_screen.dart';
import '../../features/taxi_management/screens/admin_driver_settings_screen.dart';
// Jobs Management (Phase 4)
import '../../features/jobs_management/screens/admin_company_jobs_screen.dart';
import '../../features/jobs_management/screens/admin_job_applicants_screen.dart';
import '../../features/jobs_management/screens/admin_company_settings_screen.dart';
import '../../features/rental_management/screens/admin_rental_settings_screen.dart';
import '../../features/emlak_management/screens/admin_realtor_settings_screen.dart';
import '../../features/car_sales_management/screens/admin_dealer_settings_screen.dart';
// Rental Management (Phase 3)
import '../../features/rental_management/screens/admin_rental_cars_screen.dart';
import '../../features/rental_management/screens/admin_rental_bookings_screen.dart';
import '../../features/rental_management/screens/admin_rental_calendar_screen.dart';
import '../../features/rental_management/screens/admin_rental_locations_screen.dart';
import '../../features/rental_management/screens/admin_rental_packages_screen.dart';
import '../../features/rental_management/screens/admin_rental_finance_screen.dart';
import '../../shared/widgets/admin_shell.dart';

class AppRoutes {
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/';
  static const String users = '/users';
  static const String partners = '/partners';
  static const String finance = '/finans';
  static const String financeInvoices = '/finans/faturalar';
  static const String financeBatchInvoice = '/finans/toplu-fatura';
  static const String financeIncomeExpense = '/finans/gelir-gider';
  static const String financeTax = '/finans/vergi';
  static const String financeBalanceSheet = '/finans/bilanco';
  static const String financeProfitLoss = '/finans/kar-zarar';
  static const String financeCommission = '/finans/komisyon';
  static const String financePaymentTracking = '/finans/odeme-takip';
  static const String financeBudget = '/finans/butce';
  static const String settings = '/settings';
  static const String banners = '/banners';
  static const String bannerPackages = '/banners/packages';
  static const String applications = '/applications';
  static const String notifications = '/notifications';
  static const String sanctions = '/sanctions';
  static const String logs = '/logs';
  static const String security = '/security';
  static const String systemHealth = '/system-health';
  static const String aiSupport = '/ai-support';
  // Kurye
  static const String courierVehicleTypes = '/courier/vehicle-types';
  // Eski rota sabitleri (ekranlar hala referans ediyor, rotalar kaldırıldı)
  static const String jobListingsDashboard = '/job-listings';
  static const String jobCategories = '/job-listings/categories';
  static const String jobSkills = '/job-listings/skills';
  static const String jobBenefits = '/job-listings/benefits';
  static const String jobListingsList = '/job-listings/listings';
  static const String jobCompanies = '/job-listings/companies';
  static const String jobPricing = '/job-listings/pricing';
  static const String jobSettings = '/job-listings/settings';
  static const String rentalDashboard = '/rental';
  static const String rentalVehicles = '/rental/vehicles';
  static const String rentalBookings = '/rental/bookings';
  static const String rentalLocations = '/rental/locations';
  static const String emlakDashboard = '/emlak';
  static const String emlakCities = '/emlak/cities';
  static const String emlakDistricts = '/emlak/districts';
  static const String emlakListings = '/emlak/listings';
  static const String emlakPropertyTypes = '/emlak/property-types';
  static const String emlakAmenities = '/emlak/amenities';
  static const String emlakSettings = '/emlak/settings';
  static const String emlakRealtorApplications = '/emlak/realtor-applications';
  static const String emlakPricing = '/emlak/pricing';
  static const String carSalesDashboard = '/car-sales';
  static const String carSalesListings = '/car-sales/listings';
  static const String carSalesBrands = '/car-sales/brands';
  static const String carSalesFeatures = '/car-sales/features';
  static const String carSalesPricing = '/car-sales/pricing';
  static const String carSalesBodyTypes = '/car-sales/body-types';
  static const String carSalesFuelTypes = '/car-sales/fuel-types';
  static const String carSalesTransmissions = '/car-sales/transmissions';
  static const String storeCategories = '/store/categories';
  static const String restaurantCategories = '/food/categories';
  // Destek
  static const String supportAgents = '/support-agents';
  static const String supportDashboard = '/support-dashboard';
  static const String ticketReview = '/ticket-review';
  static const String agentPerformance = '/agent-performance';
  static const String supportReports = '/support-reports';
  static const String orderHistory = '/destek/siparis-gecmisi';
  // Raporlar
  static const String reports = '/reports';
  // Öne Çıkarma Talepleri
  static const String promotionRequests = '/promotion-requests';
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = Supabase.instance.client.auth.currentSession;

  return GoRouter(
    initialLocation: session != null ? AppRoutes.dashboard : AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      final isForgotPasswordRoute = state.matchedLocation == AppRoutes.forgotPassword;

      if (!isLoggedIn && !isLoginRoute && !isForgotPasswordRoute) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isLoginRoute) {
        return AppRoutes.dashboard;
      }

      // RBAC: check permissions for authenticated routes
      if (isLoggedIn && !isLoginRoute && !isForgotPasswordRoute) {
        final adminAsync = ref.read(currentAdminProvider);
        if (adminAsync.isLoading) {
          return null;
        }
        if (adminAsync.hasError) {
          return AppRoutes.login;
        }
        final admin = adminAsync.valueOrNull;
        if (admin == null) {
          return AppRoutes.login;
        }
        final permission = PermissionConfig.getPermissionForPath(state.matchedLocation);
        if (permission != null && !admin.hasPermission(permission.$1, permission.$2)) {
          return AppRoutes.dashboard;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          // ==================== DASHBOARD ====================
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.reports,
            name: 'reports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: AppRoutes.promotionRequests,
            name: 'promotion-requests',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PromotionRequestsScreen()),
          ),

          // ==================== YENİ SEKTÖR ROTALARI ====================
          ..._buildSectorRoutes(SectorType.food),
          ..._buildSectorRoutes(SectorType.market),
          ..._buildSectorRoutes(SectorType.store),
          ..._buildSectorRoutes(SectorType.realEstate),
          ..._buildSectorRoutes(SectorType.taxi),
          ..._buildSectorRoutes(SectorType.carSales),
          ..._buildSectorRoutes(SectorType.jobs),
          ..._buildSectorRoutes(SectorType.carRental),

          // ==================== YÖNETİM ====================
          GoRoute(
            path: AppRoutes.finance,
            name: 'finance',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FinanceDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.financeInvoices,
            name: 'finance-invoices',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InvoicesScreen()),
          ),
          // Toplu Fatura artık Faturalar ekranının bir tab'ı
          GoRoute(
            path: AppRoutes.financeBatchInvoice,
            name: 'finance-batch-invoice',
            redirect: (context, state) => AppRoutes.financeInvoices,
          ),
          GoRoute(
            path: AppRoutes.financeIncomeExpense,
            name: 'finance-income-expense',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: IncomeExpenseScreen()),
          ),
          // Kaldırılan ekranlar → Dashboard'a redirect
          GoRoute(
            path: AppRoutes.financeTax,
            name: 'finance-tax',
            redirect: (context, state) => AppRoutes.finance,
          ),
          GoRoute(
            path: AppRoutes.financeBalanceSheet,
            name: 'finance-balance-sheet',
            redirect: (context, state) => AppRoutes.finance,
          ),
          GoRoute(
            path: AppRoutes.financeProfitLoss,
            name: 'finance-profit-loss',
            redirect: (context, state) => AppRoutes.finance,
          ),
          GoRoute(
            path: AppRoutes.financeCommission,
            name: 'finance-commission',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CommissionManagementScreen()),
          ),
          // Ödeme Takip artık Faturalar ekranının bir tab'ı
          GoRoute(
            path: AppRoutes.financePaymentTracking,
            name: 'finance-payment-tracking',
            redirect: (context, state) => AppRoutes.financeInvoices,
          ),
          GoRoute(
            path: AppRoutes.financeBudget,
            name: 'finance-budget',
            redirect: (context, state) => AppRoutes.finance,
          ),
          GoRoute(
            path: AppRoutes.applications,
            name: 'applications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ApplicationsScreen()),
          ),
          GoRoute(
            path: AppRoutes.users,
            name: 'users',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UsersScreen()),
          ),
          GoRoute(
            path: AppRoutes.partners,
            name: 'partners',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PartnersScreen()),
          ),

          // ==================== DESTEK ====================
          GoRoute(
            path: AppRoutes.supportDashboard,
            name: 'support-dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SupportDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.ticketReview,
            name: 'ticket-review',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TicketReviewScreen()),
          ),
          GoRoute(
            path: AppRoutes.agentPerformance,
            name: 'agent-performance',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AgentPerformanceScreen()),
          ),
          GoRoute(
            path: AppRoutes.supportReports,
            name: 'support-reports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SupportReportsScreen()),
          ),
          GoRoute(
            path: AppRoutes.aiSupport,
            name: 'ai-support',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AiSupportScreen()),
          ),
          GoRoute(
            path: AppRoutes.supportAgents,
            name: 'support-agents',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SupportAgentsScreen()),
          ),
          GoRoute(
            path: AppRoutes.orderHistory,
            name: 'order-history',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OrderHistoryScreen()),
          ),

          // ==================== SİSTEM ====================
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: AppRoutes.security,
            name: 'security',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SecurityScreen()),
          ),
          GoRoute(
            path: AppRoutes.logs,
            name: 'logs',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LogsScreen()),
          ),
          GoRoute(
            path: AppRoutes.systemHealth,
            name: 'system-health',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SystemHealthScreen()),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NotificationsScreen()),
          ),
          GoRoute(
            path: AppRoutes.sanctions,
            name: 'sanctions',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SanctionsScreen()),
          ),
          GoRoute(
            path: AppRoutes.courierVehicleTypes,
            name: 'courier-vehicle-types',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CourierVehicleTypesScreen()),
          ),
          GoRoute(
            path: AppRoutes.banners,
            name: 'banners',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BannersScreen()),
          ),
          GoRoute(
            path: AppRoutes.bannerPackages,
            name: 'banner-packages',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BannerPackagesScreen()),
          ),

          // Eski sektör rotaları kaldırıldı (yeni sektör rotaları yukarıda)
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Sayfa Bulunamadi',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(state.matchedLocation),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Ana Sayfaya Don'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Her sektör için nested route listesi oluşturur
List<RouteBase> _buildSectorRoutes(SectorType sector) {
  final tabs = sector.tabs;

  return [
    // Sektör ana sayfası - işletme listesi
    GoRoute(
      path: sector.baseRoute,
      name: '${sector.name}-listing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: BusinessListingScreen(sector: sector),
      ),
    ),
    // Sektör ayarları
    GoRoute(
      path: '${sector.baseRoute}/ayarlar',
      name: '${sector.name}-settings',
      pageBuilder: (context, state) => NoTransitionPage(
        child: SectorSettingsScreen(sector: sector),
      ),
    ),
    // İşletme detay - genel (default tab)
    GoRoute(
      path: '${sector.baseRoute}/:id',
      name: '${sector.name}-detail',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return NoTransitionPage(
          child: BusinessDetailShell(
            sector: sector,
            businessId: id,
            child: BusinessOverviewScreen(sector: sector, businessId: id),
          ),
        );
      },
    ),
    // Her tab için ayrı rota (genel hariç)
    ...tabs.where((tab) => tab.routeSegment != 'genel').map((tab) => GoRoute(
      path: '${sector.baseRoute}/:id/${tab.routeSegment}',
      name: '${sector.name}-${tab.routeSegment}',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return NoTransitionPage(
          child: BusinessDetailShell(
            sector: sector,
            businessId: id,
            child: _buildTabScreen(sector, tab, id),
          ),
        );
      },
    )),
  ];
}

/// Route segment'e göre doğru ekranı döndürür
Widget _buildTabScreen(SectorType sector, SectorTab tab, String id) {
  switch (tab.routeSegment) {
    // ==================== ORTAK TABLAR ====================
    case 'siparisler':
      return AdminOrdersKanbanScreen(merchantId: id, sectorLabel: sector.label);
    case 'urunler':
      if (sector == SectorType.food) {
        return AdminMenuScreen(merchantId: id);
      }
      return AdminProductsScreen(merchantId: id);
    case 'stok':
      return AdminInventoryScreen(merchantId: id);
    case 'kuryeler':
      return AdminCouriersScreen(merchantId: id);
    case 'yorumlar':
      return AdminReviewsScreen(
        entityType: sector.tableName,
        entityId: id,
      );
    case 'mesajlar':
    case 'sohbet':
      if (sector == SectorType.carSales) {
        return AdminDealerMessagesScreen(dealerId: id);
      }
      return AdminMessagesScreen(
        entityType: sector.tableName,
        entityId: id,
      );
    case 'basvurular':
      if (sector == SectorType.jobs) {
        return AdminJobApplicantsScreen(companyId: id);
      }
      return PlaceholderTabScreen(tabName: tab.label, sectorName: sector.label);

    // ==================== TAKSİ TABLARI ====================
    case 'seferler':
      return AdminRidesScreen(driverId: id);
    case 'kazanclar':
      return AdminDriverEarningsScreen(driverId: id);

    case 'ayarlar':
      if (sector == SectorType.taxi) {
        return AdminDriverSettingsScreen(driverId: id);
      }
      if (sector == SectorType.jobs) {
        return AdminCompanySettingsScreen(companyId: id);
      }
      if (sector == SectorType.carRental) {
        return AdminRentalSettingsScreen(companyId: id);
      }
      if (sector == SectorType.realEstate) {
        return AdminRealtorSettingsScreen(realtorId: id);
      }
      if (sector == SectorType.carSales) {
        return AdminDealerSettingsScreen(dealerId: id);
      }
      return AdminMerchantSettingsScreen(merchantId: id);

    // ==================== EMLAK TABLARI ====================
    case 'ilanlar':
      if (sector == SectorType.realEstate) {
        return AdminPropertyListingsScreen(realtorId: id);
      }
      if (sector == SectorType.carSales) {
        return AdminCarListingsScreen(dealerId: id);
      }
      if (sector == SectorType.jobs) {
        return AdminCompanyJobsScreen(companyId: id);
      }
      return PlaceholderTabScreen(tabName: tab.label, sectorName: sector.label);
    case 'crm':
      return AdminCrmScreen(realtorId: id);
    case 'randevular':
      return AdminAppointmentsScreen(realtorId: id);
    case 'analitik':
      return AdminEmlakAnalyticsScreen(realtorId: id);

    // ==================== GALERİ TABLARI ====================
    case 'performans':
      return AdminCarPerformanceScreen(dealerId: id);

    // ==================== ARAÇ KİRALAMA TABLARI ====================
    case 'araclar':
      return AdminRentalCarsScreen(companyId: id);
    case 'rezervasyonlar':
      return AdminRentalBookingsScreen(companyId: id);
    case 'takvim':
      return AdminRentalCalendarScreen(companyId: id);
    case 'lokasyonlar':
      return AdminRentalLocationsScreen(companyId: id);
    case 'paketler':
      return AdminRentalPackagesScreen(companyId: id);
    case 'finans':
      if (sector == SectorType.carRental) {
        return AdminRentalFinanceScreen(companyId: id);
      }
      return AdminMerchantFinanceScreen(merchantId: id);

    default:
      return PlaceholderTabScreen(
        tabName: tab.label,
        sectorName: sector.label,
      );
  }
}
