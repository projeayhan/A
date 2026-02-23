import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class Breadcrumbs extends ConsumerWidget {
  const Breadcrumbs({super.key});

  static const Map<String, String> _routeLabels = {
    '/dashboard': 'Dashboard',
    '/listings': 'İlanlarım',
    '/listings/add': 'Yeni İlan',
    '/appointments': 'Randevular',
    '/clients': 'Müşteriler',
    '/analytics': 'Performans',
    '/chat': 'Mesajlar',
    '/profile': 'Profil',
    '/settings': 'Ayarlar',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = GoRouterState.of(context).matchedLocation;
    if (route == '/dashboard') return const SizedBox.shrink();

    final segments = _buildSegments(route);
    if (segments.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = AppColors.textMuted(isDark);
    final activeColor = AppColors.textPrimary(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border(isDark)),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/dashboard'),
            borderRadius: BorderRadius.circular(4),
            child: Icon(Icons.home_outlined, size: 16, color: mutedColor),
          ),
          ...segments.asMap().entries.expand((entry) {
            final isLast = entry.key == segments.length - 1;
            final segment = entry.value;
            return [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: mutedColor,
                ),
              ),
              isLast
                  ? Text(
                      segment.label,
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : InkWell(
                      onTap: () => context.go(segment.route),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        segment.label,
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 13,
                        ),
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
