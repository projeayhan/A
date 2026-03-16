import '../models/sector_type.dart';
import '../../core/router/app_router.dart';

/// Route-to-permission mapping for RBAC enforcement
class PermissionConfig {
  // Module names matching the DB permission keys
  static const String users = 'users';
  static const String merchants = 'merchants';
  static const String partners = 'partners';
  static const String orders = 'orders';
  static const String finance = 'finance';
  static const String settings = 'settings';
  static const String food = 'food';
  static const String rental = 'rental';
  static const String emlak = 'emlak';
  static const String carSales = 'car_sales';
  static const String jobs = 'jobs';
  static const String system = 'system';
  static const String notifications = 'notifications';
  static const String support = 'support';
  static const String taxi = 'taxi';

  /// Sektör → permission modülü eşlemesi
  static const Map<SectorType, String> sectorPermissions = {
    SectorType.food: food,
    SectorType.market: food,
    SectorType.store: food,
    SectorType.realEstate: emlak,
    SectorType.taxi: taxi,
    SectorType.carSales: carSales,
    SectorType.jobs: jobs,
    SectorType.carRental: rental,
  };

  /// Route → required (module, action) mapping
  static const Map<String, (String, String)> routePermissions = {
    // Users & Merchants
    AppRoutes.users: (users, 'read'),
    AppRoutes.merchants: (merchants, 'read'),
    AppRoutes.partners: (partners, 'read'),
    AppRoutes.applications: (users, 'read'),
    // Operations
    AppRoutes.orders: (orders, 'read'),
    AppRoutes.notifications: (notifications, 'read'),
    AppRoutes.sanctions: (users, 'write'),
    // Finance
    AppRoutes.finance: (finance, 'read'),
    AppRoutes.earnings: (finance, 'read'),
    AppRoutes.invoices: (finance, 'read'),
    AppRoutes.pricing: (finance, 'write'),
    AppRoutes.surge: (finance, 'write'),
    // Food
    AppRoutes.restaurantCategories: (food, 'read'),
    // Rental (eski rotalar)
    AppRoutes.rentalDashboard: (rental, 'read'),
    AppRoutes.rentalVehicles: (rental, 'read'),
    AppRoutes.rentalBookings: (rental, 'read'),
    AppRoutes.rentalLocations: (rental, 'read'),
    // Emlak (eski rotalar)
    AppRoutes.emlakDashboard: (emlak, 'read'),
    AppRoutes.emlakListings: (emlak, 'read'),
    AppRoutes.emlakCities: (emlak, 'read'),
    AppRoutes.emlakDistricts: (emlak, 'read'),
    AppRoutes.emlakPropertyTypes: (emlak, 'read'),
    AppRoutes.emlakAmenities: (emlak, 'read'),
    AppRoutes.emlakPricing: (emlak, 'write'),
    AppRoutes.emlakSettings: (emlak, 'write'),
    AppRoutes.emlakRealtorApplications: (emlak, 'read'),
    // Car Sales (eski rotalar)
    AppRoutes.carSalesDashboard: (carSales, 'read'),
    AppRoutes.carSalesListings: (carSales, 'read'),
    AppRoutes.carSalesBrands: (carSales, 'read'),
    AppRoutes.carSalesFeatures: (carSales, 'read'),
    AppRoutes.carSalesPricing: (carSales, 'write'),
    AppRoutes.carSalesBodyTypes: (carSales, 'read'),
    AppRoutes.carSalesFuelTypes: (carSales, 'read'),
    AppRoutes.carSalesTransmissions: (carSales, 'read'),
    // Job Listings (eski rotalar)
    AppRoutes.jobListingsDashboard: (jobs, 'read'),
    AppRoutes.jobListingsList: (jobs, 'read'),
    AppRoutes.jobCompanies: (jobs, 'read'),
    AppRoutes.jobCategories: (jobs, 'read'),
    AppRoutes.jobSkills: (jobs, 'read'),
    AppRoutes.jobBenefits: (jobs, 'read'),
    AppRoutes.jobPricing: (jobs, 'write'),
    AppRoutes.jobSettings: (jobs, 'write'),
    // Support
    AppRoutes.supportDashboard: (system, 'read'),
    AppRoutes.ticketReview: (system, 'read'),
    AppRoutes.agentPerformance: (system, 'read'),
    AppRoutes.supportReports: (system, 'read'),
    AppRoutes.supportAgents: (system, 'read'),
    // Reports
    AppRoutes.reports: (finance, 'read'),
    // System
    AppRoutes.settings: (settings, 'read'),
    AppRoutes.banners: (settings, 'read'),
    AppRoutes.security: (system, 'read'),
    AppRoutes.logs: (system, 'read'),
    AppRoutes.systemHealth: (system, 'read'),
    AppRoutes.aiSupport: (system, 'read'),
    // Yeni sektör rotaları
    '/yemek': (food, 'read'),
    '/market': (food, 'read'),
    '/magaza': (food, 'read'),
    '/emlak-sektor': (emlak, 'read'),
    '/taksi': (taxi, 'read'),
    '/galeri': (carSales, 'read'),
    '/is-ilanlari': (jobs, 'read'),
    '/arac-kiralama': (rental, 'read'),
  };

  /// Sidebar group → module mapping
  /// '*' means accessible to all authenticated admins
  static const Map<String, String> groupPermissions = {
    'services': '*',
    'management': finance,
    'support': system,
    'system': system,
  };
}
