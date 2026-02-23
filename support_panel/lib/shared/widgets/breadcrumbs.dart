import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

class SupportBreadcrumbs extends StatelessWidget {
  const SupportBreadcrumbs({super.key});

  static const Map<String, String> _routeLabels = {
    '/': 'Dashboard',
    '/tickets': 'Ticketlar',
    '/customers': 'Müşteriler',
    '/businesses': 'İşletmeler',
    '/settings': 'Ayarlar',
  };

  @override
  Widget build(BuildContext context) {
    final route = GoRouterState.of(context).matchedLocation;
    if (route == '/') return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final activeColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    final segments = _buildSegments(route);

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
                  ? Text(segment.label, style: TextStyle(color: activeColor, fontSize: 13, fontWeight: FontWeight.w500))
                  : InkWell(
                      onTap: () => context.go(segment.route),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(segment.label, style: TextStyle(color: mutedColor, fontSize: 13)),
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
