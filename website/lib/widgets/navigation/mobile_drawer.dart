import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';

class MobileDrawer extends StatelessWidget {
  const MobileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textOnDarkMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.apps_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'SuperCyp',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Menu items
          _MenuItem(
            icon: Icons.home_rounded,
            label: 'Ana Sayfa',
            path: AppRoutes.home,
            isActive: currentPath == AppRoutes.home,
          ),
          _MenuItem(
            icon: Icons.grid_view_rounded,
            label: 'Hizmetler',
            path: AppRoutes.services,
            isActive: currentPath == AppRoutes.services,
          ),
          _MenuItem(
            icon: Icons.business_rounded,
            label: 'İşletmeler İçin',
            path: AppRoutes.business,
            isActive: currentPath == AppRoutes.business,
          ),
          _MenuItem(
            icon: Icons.download_rounded,
            label: 'İndir',
            path: AppRoutes.download,
            isActive: currentPath == AppRoutes.download,
            highlight: true,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool isActive;
  final bool highlight;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.path,
    this.isActive = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).pop();
            context.go(path);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : null,
              gradient: highlight && !isActive
                  ? LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.cyan.withValues(alpha: 0.05),
                      ],
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? AppColors.primaryLight
                      : AppColors.textOnDarkSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? AppColors.primaryLight
                        : AppColors.textOnDark,
                  ),
                ),
                if (highlight) ...[
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ücretsiz',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
