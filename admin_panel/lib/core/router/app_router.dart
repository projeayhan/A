import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/users/screens/users_screen.dart';
import '../../features/merchants/screens/merchants_screen.dart';
import '../../features/partners/screens/partners_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/finance/screens/finance_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/pricing/screens/pricing_screen.dart';
import '../../features/banners/screens/banners_screen.dart';
import '../../features/invoices/screens/invoices_screen.dart';
import '../../features/surge/screens/surge_screen.dart';
import '../../features/earnings/screens/earnings_screen.dart';
import '../../features/applications/screens/applications_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/sanctions/screens/sanctions_screen.dart';
import '../../features/logs/screens/logs_screen.dart';
import '../../features/security/screens/security_screen.dart';
import '../../features/system_health/screens/system_health_screen.dart';
import '../../features/support/screens/ai_support_screen.dart';
import '../../features/rental/screens/rental_dashboard_screen.dart';
import '../../features/rental/screens/rental_vehicles_screen.dart';
import '../../features/rental/screens/rental_bookings_screen.dart';
import '../../features/rental/screens/rental_locations_screen.dart';
import '../../features/emlak/screens/emlak_dashboard_screen.dart';
import '../../features/emlak/screens/emlak_cities_screen.dart';
import '../../features/emlak/screens/emlak_districts_screen.dart';
import '../../features/emlak/screens/emlak_listings_screen.dart';
import '../../features/emlak/screens/emlak_property_types_screen.dart';
import '../../features/emlak/screens/emlak_amenities_screen.dart';
import '../../features/emlak/screens/emlak_settings_screen.dart';
import '../../features/emlak/screens/emlak_realtor_applications_screen.dart';
import '../../features/emlak/screens/emlak_pricing_screen.dart';
import '../../features/car_sales/screens/car_sales_dashboard_screen.dart';
import '../../features/car_sales/screens/car_sales_listings_screen.dart';
import '../../features/car_sales/screens/car_sales_brands_screen.dart';
import '../../features/car_sales/screens/car_sales_features_screen.dart';
import '../../features/car_sales/screens/car_sales_pricing_screen.dart';
import '../../features/car_sales/screens/car_sales_body_types_screen.dart';
import '../../features/car_sales/screens/car_sales_fuel_types_screen.dart';
import '../../features/car_sales/screens/car_sales_transmissions_screen.dart';
import '../../features/job_listings/screens/job_listings_dashboard_screen.dart';
import '../../features/job_listings/screens/job_categories_screen.dart';
import '../../features/job_listings/screens/job_skills_screen.dart';
import '../../features/job_listings/screens/job_benefits_screen.dart';
import '../../features/job_listings/screens/job_listings_list_screen.dart';
import '../../features/job_listings/screens/job_companies_screen.dart';
import '../../features/job_listings/screens/job_pricing_screen.dart';
import '../../features/job_listings/screens/job_settings_screen.dart';
import '../../shared/widgets/admin_shell.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/';
  static const String users = '/users';
  static const String merchants = '/merchants';
  static const String partners = '/partners';
  static const String orders = '/orders';
  static const String finance = '/finance';
  static const String settings = '/settings';
  static const String pricing = '/pricing';
  static const String banners = '/banners';
  static const String invoices = '/invoices';
  static const String surge = '/surge';
  static const String earnings = '/earnings';
  static const String applications = '/applications';
  static const String notifications = '/notifications';
  static const String sanctions = '/sanctions';
  static const String logs = '/logs';
  static const String security = '/security';
  static const String systemHealth = '/system-health';
  static const String aiSupport = '/ai-support';
  static const String rentalDashboard = '/rental';
  static const String rentalVehicles = '/rental/vehicles';
  static const String rentalBookings = '/rental/bookings';
  static const String rentalLocations = '/rental/locations';
  // Emlak
  static const String emlakDashboard = '/emlak';
  static const String emlakCities = '/emlak/cities';
  static const String emlakDistricts = '/emlak/districts';
  static const String emlakListings = '/emlak/listings';
  static const String emlakPropertyTypes = '/emlak/property-types';
  static const String emlakAmenities = '/emlak/amenities';
  static const String emlakSettings = '/emlak/settings';
  static const String emlakRealtorApplications = '/emlak/realtor-applications';
  static const String emlakPricing = '/emlak/pricing';
  // Araç Satış
  static const String carSalesDashboard = '/car-sales';
  static const String carSalesListings = '/car-sales/listings';
  static const String carSalesBrands = '/car-sales/brands';
  static const String carSalesFeatures = '/car-sales/features';
  static const String carSalesPricing = '/car-sales/pricing';
  static const String carSalesBodyTypes = '/car-sales/body-types';
  static const String carSalesFuelTypes = '/car-sales/fuel-types';
  static const String carSalesTransmissions = '/car-sales/transmissions';
  // İş İlanları
  static const String jobListingsDashboard = '/job-listings';
  static const String jobCategories = '/job-listings/categories';
  static const String jobSkills = '/job-listings/skills';
  static const String jobBenefits = '/job-listings/benefits';
  static const String jobListingsList = '/job-listings/listings';
  static const String jobCompanies = '/job-listings/companies';
  static const String jobPricing = '/job-listings/pricing';
  static const String jobSettings = '/job-listings/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = Supabase.instance.client.auth.currentSession;

  return GoRouter(
    initialLocation: session != null ? AppRoutes.dashboard : AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isLoginRoute) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isLoginRoute) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.users,
            name: 'users',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UsersScreen()),
          ),
          GoRoute(
            path: AppRoutes.merchants,
            name: 'merchants',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MerchantsScreen()),
          ),
          GoRoute(
            path: AppRoutes.partners,
            name: 'partners',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PartnersScreen()),
          ),
          GoRoute(
            path: AppRoutes.orders,
            name: 'orders',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OrdersScreen()),
          ),
          GoRoute(
            path: AppRoutes.finance,
            name: 'finance',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FinanceScreen()),
          ),
          GoRoute(
            path: AppRoutes.pricing,
            name: 'pricing',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PricingScreen()),
          ),
          GoRoute(
            path: AppRoutes.banners,
            name: 'banners',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BannersScreen()),
          ),
          GoRoute(
            path: AppRoutes.invoices,
            name: 'invoices',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InvoicesScreen()),
          ),
          GoRoute(
            path: AppRoutes.surge,
            name: 'surge',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SurgeScreen()),
          ),
          GoRoute(
            path: AppRoutes.earnings,
            name: 'earnings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EarningsScreen()),
          ),
          GoRoute(
            path: AppRoutes.applications,
            name: 'applications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ApplicationsScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
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
            path: AppRoutes.logs,
            name: 'logs',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LogsScreen()),
          ),
          GoRoute(
            path: AppRoutes.security,
            name: 'security',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SecurityScreen()),
          ),
          GoRoute(
            path: AppRoutes.systemHealth,
            name: 'system-health',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SystemHealthScreen()),
          ),
          GoRoute(
            path: AppRoutes.aiSupport,
            name: 'ai-support',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AiSupportScreen()),
          ),
          GoRoute(
            path: AppRoutes.rentalDashboard,
            name: 'rental-dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RentalDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.rentalVehicles,
            name: 'rental-vehicles',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RentalVehiclesScreen()),
          ),
          GoRoute(
            path: AppRoutes.rentalBookings,
            name: 'rental-bookings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RentalBookingsScreen()),
          ),
          GoRoute(
            path: AppRoutes.rentalLocations,
            name: 'rental-locations',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RentalLocationsScreen()),
          ),
          // Emlak Routes
          GoRoute(
            path: AppRoutes.emlakDashboard,
            name: 'emlak-dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.emlakCities,
            name: 'emlak-cities',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakCitiesScreen()),
          ),
          GoRoute(
            path: AppRoutes.emlakDistricts,
            name: 'emlak-districts',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakDistrictsScreen()),
          ),
          GoRoute(
            path: AppRoutes.emlakListings,
            name: 'emlak-listings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakListingsScreen()),
          ),
          GoRoute(
            path: AppRoutes.emlakPropertyTypes,
            name: 'emlak-property-types',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakPropertyTypesScreen()),
          ),
          GoRoute(
            path: AppRoutes.emlakAmenities,
            name: 'emlak-amenities',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakAmenitiesScreen()),
          ),
          GoRoute(
            path: AppRoutes.emlakSettings,
            name: 'emlak-settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakSettingsScreen()),
          ),
          GoRoute(
            path: AppRoutes.emlakRealtorApplications,
            name: 'emlak-realtor-applications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakRealtorApplicationsScreen()),
          ),
          GoRoute(
            path: AppRoutes.emlakPricing,
            name: 'emlak-pricing',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmlakPricingScreen()),
          ),
          // Car Sales Routes
          GoRoute(
            path: AppRoutes.carSalesDashboard,
            name: 'car-sales-dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CarSalesDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.carSalesListings,
            name: 'car-sales-listings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CarSalesListingsScreen()),
          ),
          GoRoute(
            path: AppRoutes.carSalesBrands,
            name: 'car-sales-brands',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CarSalesBrandsScreen()),
          ),
          GoRoute(
            path: AppRoutes.carSalesFeatures,
            name: 'car-sales-features',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CarSalesFeaturesScreen()),
          ),
          GoRoute(
            path: AppRoutes.carSalesPricing,
            name: 'car-sales-pricing',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CarSalesPricingScreen()),
          ),
          GoRoute(
            path: AppRoutes.carSalesBodyTypes,
            name: 'car-sales-body-types',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CarSalesBodyTypesScreen()),
          ),
          GoRoute(
            path: AppRoutes.carSalesFuelTypes,
            name: 'car-sales-fuel-types',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CarSalesFuelTypesScreen()),
          ),
          GoRoute(
            path: AppRoutes.carSalesTransmissions,
            name: 'car-sales-transmissions',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CarSalesTransmissionsScreen()),
          ),
          // Job Listings Routes
          GoRoute(
            path: AppRoutes.jobListingsDashboard,
            name: 'job-listings-dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: JobListingsDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.jobCategories,
            name: 'job-categories',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: JobCategoriesScreen()),
          ),
          GoRoute(
            path: AppRoutes.jobSkills,
            name: 'job-skills',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: JobSkillsScreen()),
          ),
          GoRoute(
            path: AppRoutes.jobBenefits,
            name: 'job-benefits',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: JobBenefitsScreen()),
          ),
          GoRoute(
            path: AppRoutes.jobListingsList,
            name: 'job-listings-list',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: JobListingsListScreen()),
          ),
          GoRoute(
            path: AppRoutes.jobCompanies,
            name: 'job-companies',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: JobCompaniesScreen()),
          ),
          GoRoute(
            path: AppRoutes.jobPricing,
            name: 'job-pricing',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: JobPricingScreen()),
          ),
          GoRoute(
            path: AppRoutes.jobSettings,
            name: 'job-settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: JobSettingsScreen()),
          ),
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
