import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/models/sector_type.dart';
import '../../features/business/services/business_service.dart';

class AdminBreadcrumbs extends ConsumerWidget {
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
    '/reports': 'Raporlar',
    // Finans
    '/finans': 'Finans',
    '/finans/faturalar': 'Faturalar',
    '/finans/toplu-fatura': 'Toplu Fatura',
    '/finans/gelir-gider': 'Gelir/Gider',
    '/finans/vergi': 'Vergi Raporu',
    '/finans/bilanco': 'Bilanço',
    '/finans/kar-zarar': 'Kar/Zarar',
    '/finans/komisyon': 'Komisyon',
    '/finans/odeme-takip': 'Ödeme Takip',
    // Destek
    '/support-dashboard': 'Destek Dashboard',
    '/ticket-review': 'Ticket İnceleme',
    '/agent-performance': 'Temsilci Performans',
    '/support-reports': 'Destek Raporları',
    '/support-agents': 'Destek Agentları',
    // Sistem
    '/courier/vehicle-types': 'Kurye Araç Tipleri',
    '/food/categories': 'Restoran Kategorileri',
    '/store/categories': 'Mağaza Kategorileri',
  };

  /// Tab route segment → label
  static const Map<String, String> _tabLabels = {
    'genel': 'Genel',
    'siparisler': 'Siparişler',
    'urunler': 'Ürünler',
    'stok': 'Stok',
    'finans': 'Finans',
    'yorumlar': 'Yorumlar',
    'kuryeler': 'Kuryeler',
    'mesajlar': 'Mesajlar',
    'sohbet': 'Sohbet',
    'ayarlar': 'Ayarlar',
    'ilanlar': 'İlanlar',
    'crm': 'CRM',
    'randevular': 'Randevular',
    'analitik': 'Analitik',
    'performans': 'Performans',
    'araclar': 'Araçlar',
    'rezervasyonlar': 'Rezervasyonlar',
    'takvim': 'Takvim',
    'lokasyonlar': 'Lokasyonlar',
    'paketler': 'Paketler',
    'seferler': 'Seferler',
    'kazanclar': 'Kazançlar',
    'basvurular': 'Başvurular',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = GoRouterState.of(context).matchedLocation;
    if (route == '/') return const SizedBox.shrink();

    final segments = _buildSegments(route, ref);
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
                  ? Flexible(
                      child: Text(
                        segment.label,
                        style: TextStyle(color: activeColor, fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  List<_BreadcrumbSegment> _buildSegments(String route, WidgetRef ref) {
    // Check if this is a sector route with business detail
    final sectorMatch = _matchSectorRoute(route);
    if (sectorMatch != null) {
      return _buildSectorBreadcrumbs(sectorMatch, ref);
    }

    // Standard route breadcrumbs
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

  /// Try to match sector base routes and extract business ID / tab
  _SectorRouteMatch? _matchSectorRoute(String route) {
    for (final sector in SectorType.values) {
      if (route.startsWith(sector.baseRoute)) {
        final remaining = route.substring(sector.baseRoute.length);

        // /yemek/ayarlar → sector settings
        if (remaining == '/ayarlar') {
          return _SectorRouteMatch(sector: sector, businessId: null, tabSegment: 'ayarlar', isSettings: true);
        }

        // /yemek → listing page
        if (remaining.isEmpty) {
          return _SectorRouteMatch(sector: sector);
        }

        // /yemek/:id or /yemek/:id/tab
        final parts = remaining.split('/').where((p) => p.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          final businessId = parts[0];
          final tabSegment = parts.length > 1 ? parts[1] : null;
          return _SectorRouteMatch(sector: sector, businessId: businessId, tabSegment: tabSegment);
        }
      }
    }
    return null;
  }

  List<_BreadcrumbSegment> _buildSectorBreadcrumbs(_SectorRouteMatch match, WidgetRef ref) {
    final segments = <_BreadcrumbSegment>[];

    // 1. Sektör adı → sektör listesine link
    segments.add(_BreadcrumbSegment(
      route: match.sector.baseRoute,
      label: match.sector.label,
    ));

    // Sector settings page
    if (match.isSettings) {
      segments.add(_BreadcrumbSegment(
        route: '${match.sector.baseRoute}/ayarlar',
        label: 'Ayarlar',
      ));
      return segments;
    }

    // 2. İşletme adı (async)
    if (match.businessId != null) {
      final detailAsync = ref.watch(
        businessDetailProvider((sector: match.sector, id: match.businessId!)),
      );
      final businessName = detailAsync.when(
        data: (data) {
          if (data != null) {
            return data['name'] as String?
                ?? data['business_name'] as String?
                ?? data['full_name'] as String?
                ?? data['company_name'] as String?
                ?? 'İşletme';
          }
          return 'İşletme';
        },
        loading: () => 'Yükleniyor...',
        error: (_, _) => 'Hata',
      );

      segments.add(_BreadcrumbSegment(
        route: '${match.sector.baseRoute}/${match.businessId}',
        label: businessName,
      ));

      // 3. Tab adı
      if (match.tabSegment != null) {
        final tabLabel = _tabLabels[match.tabSegment!] ?? match.tabSegment!;
        segments.add(_BreadcrumbSegment(
          route: '${match.sector.baseRoute}/${match.businessId}/${match.tabSegment}',
          label: tabLabel,
        ));
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

class _SectorRouteMatch {
  final SectorType sector;
  final String? businessId;
  final String? tabSegment;
  final bool isSettings;

  const _SectorRouteMatch({
    required this.sector,
    this.businessId,
    this.tabSegment,
    this.isSettings = false,
  });
}
