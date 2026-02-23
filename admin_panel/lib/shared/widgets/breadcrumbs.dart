import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

class AdminBreadcrumbs extends StatelessWidget {
  const AdminBreadcrumbs({super.key});

  static const Map<String, String> _routeLabels = {
    '/': 'Dashboard',
    '/users': 'Kullanıcılar',
    '/merchants': 'İşletmeler',
    '/partners': 'Partnerler',
    '/applications': 'Başvurular',
    '/orders': 'Siparişler',
    '/notifications': 'Bildirimler',
    '/sanctions': 'Yaptırımlar',
    '/finance': 'Finans',
    '/earnings': 'Kazançlar',
    '/invoices': 'Faturalar',
    '/pricing': 'Fiyatlandırma',
    '/surge': 'Surge Pricing',
    '/banners': 'Bannerlar',
    '/settings': 'Genel Ayarlar',
    '/security': 'Güvenlik',
    '/logs': 'Log Kayıtları',
    '/system-health': 'Sistem Sağlığı',
    '/ai-support': 'AI Destek',
    '/food': 'Yemek',
    '/food/categories': 'Restoran Kategorileri',
    '/rental': 'Araç Kiralama',
    '/rental/vehicles': 'Araçlar',
    '/rental/bookings': 'Rezervasyonlar',
    '/rental/locations': 'Lokasyonlar',
    '/emlak': 'Emlak',
    '/emlak/listings': 'İlanlar',
    '/emlak/cities': 'Şehirler',
    '/emlak/districts': 'İlçeler',
    '/emlak/property-types': 'Emlak Türleri',
    '/emlak/amenities': 'Özellikler',
    '/emlak/pricing': 'Fiyatlandırma',
    '/emlak/settings': 'Ayarlar',
    '/emlak/realtor-applications': 'Emlakçı Başvuruları',
    '/car-sales': 'Araç Satış',
    '/car-sales/listings': 'İlanlar',
    '/car-sales/brands': 'Markalar',
    '/car-sales/features': 'Özellikler',
    '/car-sales/pricing': 'Fiyatlandırma',
    '/car-sales/body-types': 'Gövde Tipleri',
    '/car-sales/fuel-types': 'Yakıt Tipleri',
    '/car-sales/transmissions': 'Vites Tipleri',
    '/job-listings': 'İş İlanları',
    '/job-listings/listings': 'İlanlar',
    '/job-listings/companies': 'Şirketler',
    '/job-listings/categories': 'Kategoriler',
    '/job-listings/skills': 'Yetenekler',
    '/job-listings/benefits': 'Yan Haklar',
    '/job-listings/pricing': 'Fiyatlandırma',
    '/job-listings/settings': 'Ayarlar',
  };

  @override
  Widget build(BuildContext context) {
    final route = GoRouterState.of(context).matchedLocation;
    if (route == '/') return const SizedBox.shrink();

    final segments = _buildSegments(route);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final activeColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go(AppRoutes.dashboard),
            borderRadius: BorderRadius.circular(4),
            child: Icon(Icons.home_outlined, size: 16, color: mutedColor),
          ),
          ...segments.asMap().entries.expand((entry) {
            final isLast = entry.key == segments.length - 1;
            final segment = entry.value;
            return [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right, size: 14, color: mutedColor),
              ),
              isLast
                  ? Text(
                      segment.label,
                      style: TextStyle(color: activeColor, fontSize: 13, fontWeight: FontWeight.w500),
                    )
                  : InkWell(
                      onTap: () => context.go(segment.route),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        segment.label,
                        style: TextStyle(color: mutedColor, fontSize: 13),
                      ),
                    ),
            ];
          }),
        ],
      ),
    );
  }

  List<_BreadcrumbSegment> _buildSegments(String route) {
    final segments = <_BreadcrumbSegment>[];
    final parts = route.split('/').where((p) => p.isNotEmpty).toList();

    String accumulator = '';
    for (final part in parts) {
      accumulator = '$accumulator/$part';
      final label = _routeLabels[accumulator];
      if (label != null) {
        segments.add(_BreadcrumbSegment(route: accumulator, label: label));
      }
    }

    return segments;
  }
}

class _BreadcrumbSegment {
  final String route;
  final String label;
  const _BreadcrumbSegment({required this.route, required this.label});
}
