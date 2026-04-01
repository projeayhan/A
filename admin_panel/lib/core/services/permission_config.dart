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
    // Users & Management
    AppRoutes.users: (users, 'read'),
    AppRoutes.partners: (partners, 'read'),
    AppRoutes.applications: (users, 'read'),
    // Notifications
    AppRoutes.notifications: (notifications, 'read'),
    AppRoutes.sanctions: (users, 'write'),
    // Finance
    AppRoutes.finance: (finance, 'read'),
    AppRoutes.financeInvoices: (finance, 'read'),
    AppRoutes.financeBatchInvoice: (finance, 'write'),
    AppRoutes.financeIncomeExpense: (finance, 'read'),
    AppRoutes.financeCommission: (finance, 'write'),
    // Support
    AppRoutes.supportDashboard: (support, 'read'),
    AppRoutes.ticketReview: (support, 'read'),
    AppRoutes.agentPerformance: (support, 'read'),
    AppRoutes.supportReports: (support, 'read'),
    AppRoutes.supportAgents: (support, 'read'),
    // Reports
    AppRoutes.reports: (finance, 'read'),
    // System
    AppRoutes.settings: (settings, 'read'),
    AppRoutes.banners: (settings, 'read'),
    AppRoutes.security: (system, 'read'),
    AppRoutes.logs: (system, 'read'),
    AppRoutes.systemHealth: (system, 'read'),
    AppRoutes.aiSupport: (system, 'read'),
    AppRoutes.courierVehicleTypes: (system, 'read'),
    // Sektör rotaları (ana liste + ayarlar)
    '/yemek': (food, 'read'),
    '/yemek/ayarlar': (food, 'write'),
    '/market': (food, 'read'),
    '/market/ayarlar': (food, 'write'),
    '/magaza': (food, 'read'),
    '/magaza/ayarlar': (food, 'write'),
    '/emlak': (emlak, 'read'),
    '/emlak/ayarlar': (emlak, 'write'),
    '/taksi': (taxi, 'read'),
    '/taksi/ayarlar': (taxi, 'write'),
    '/galeri': (carSales, 'read'),
    '/galeri/ayarlar': (carSales, 'write'),
    '/is-ilanlari': (jobs, 'read'),
    '/is-ilanlari/ayarlar': (jobs, 'write'),
    '/arac-kiralama': (rental, 'read'),
    '/arac-kiralama/ayarlar': (rental, 'write'),
  };

  /// Sektör detay rotalarını kontrol et (dynamic path: /yemek/:id/siparisler gibi)
  /// Router redirect'inde matchedLocation üzerinden sektör base path'ini bulur
  static (String, String)? getPermissionForPath(String path) {
    // Önce exact match dene
    final exact = routePermissions[path];
    if (exact != null) return exact;

    // Sektör detay rotaları: /yemek/:id, /yemek/:id/siparisler vb.
    for (final sector in SectorType.values) {
      if (path.startsWith(sector.baseRoute)) {
        final perm = sectorPermissions[sector];
        if (perm != null) return (perm, 'read');
      }
    }

    return null;
  }

  /// Sidebar group → module mapping
  /// '*' means accessible to all authenticated admins
  static const Map<String, String> groupPermissions = {
    'services': '*',
    'management': finance,
    'support': system,
    'system': system,
  };
}
