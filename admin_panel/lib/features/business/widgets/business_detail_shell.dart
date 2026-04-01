import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/sector_type.dart';
import '../../../core/theme/app_theme.dart';
import '../services/business_service.dart';

class BusinessDetailShell extends ConsumerStatefulWidget {
  final SectorType sector;
  final String businessId;
  final Widget child;

  const BusinessDetailShell({
    super.key,
    required this.sector,
    required this.businessId,
    required this.child,
  });

  @override
  ConsumerState<BusinessDetailShell> createState() => _BusinessDetailShellState();
}

class _BusinessDetailShellState extends ConsumerState<BusinessDetailShell> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabs = widget.sector.tabs;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    // Determine active tab index
    int activeIndex = 0;
    for (int i = 0; i < tabs.length; i++) {
      final tabRoute = '${widget.sector.baseRoute}/${widget.businessId}/${tabs[i].routeSegment}';
      if (currentRoute == tabRoute || (i == 0 && currentRoute == '${widget.sector.baseRoute}/${widget.businessId}')) {
        activeIndex = i;
        break;
      }
    }

    final businessAsync = ref.watch(
      businessDetailProvider((sector: widget.sector, id: widget.businessId)),
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button + business name
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
              Icon(widget.sector.icon, size: 24, color: AppColors.primary),
              const SizedBox(width: 8),
              businessAsync.when(
                data: (data) => Text(
                  data?[widget.sector.nameField] ?? data?['name'] ?? data?['full_name'] ?? data?['company_name'] ?? data?['business_name'] ?? 'İşletme Detayı',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                loading: () => const SizedBox(
                  width: 120,
                  height: 20,
                  child: LinearProgressIndicator(),
                ),
                error: (_, _) => const Text('Hata'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Horizontal tab bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final tab = tabs[index];
                  final isActive = index == activeIndex;

                  return InkWell(
                    onTap: () {
                      if (index == 0) {
                        context.go('${widget.sector.baseRoute}/${widget.businessId}');
                      } else {
                        context.go('${widget.sector.baseRoute}/${widget.businessId}/${tab.routeSegment}');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isActive ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab.icon,
                            size: 18,
                            color: isActive ? AppColors.primary : (isDark ? AppColors.textMuted : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tab.label,
                            style: TextStyle(
                              color: isActive ? AppColors.primary : (isDark ? AppColors.textSecondary : Colors.grey.shade700),
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Child content
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
