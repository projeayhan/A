import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import 'mobile_drawer.dart';

class AppNavBar extends StatefulWidget {
  final bool isScrolled;
  const AppNavBar({super.key, this.isScrolled = false});

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final currentPath = GoRouterState.of(context).uri.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: widget.isScrolled
            ? AppColors.backgroundDark.withValues(alpha: 0.95)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: widget.isScrolled ? AppColors.glassBorder : Colors.transparent,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: widget.isScrolled
              ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            height: 76,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40),
            child: Row(
              children: [
                // Logo
                _Logo(),
                const Spacer(),
                // Desktop menu
                if (!isMobile) ...[
                  _NavItem(
                    label: 'Ana Sayfa',
                    path: AppRoutes.home,
                    isActive: currentPath == AppRoutes.home,
                  ),
                  const SizedBox(width: 8),
                  _NavItem(
                    label: 'Hizmetler',
                    path: AppRoutes.services,
                    isActive: currentPath == AppRoutes.services,
                  ),
                  const SizedBox(width: 8),
                  _NavItem(
                    label: 'İşletmeler',
                    path: AppRoutes.business,
                    isActive: currentPath == AppRoutes.business,
                  ),
                  const SizedBox(width: 24),
                  _DownloadCTA(),
                ] else
                  IconButton(
                    onPressed: () => _showMobileMenu(context),
                    icon: const Icon(Icons.menu_rounded,
                        color: AppColors.textOnDark, size: 28),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const MobileDrawer(),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.home),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Image.asset(
          'assets/images/supercyp_logo_horizontal.png',
          height: 50,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final String path;
  final bool isActive;

  const _NavItem({
    required this.label,
    required this.path,
    required this.isActive,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.isActive
                ? AppColors.primary.withValues(alpha: 0.15)
                : _hovered
                    ? AppColors.glassFillHover
                    : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight:
                  widget.isActive || _hovered ? FontWeight.w600 : FontWeight.w400,
              color: widget.isActive
                  ? AppColors.primaryLight
                  : _hovered
                      ? AppColors.textOnDark
                      : AppColors.textOnDarkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadCTA extends StatefulWidget {
  @override
  State<_DownloadCTA> createState() => _DownloadCTAState();
}

class _DownloadCTAState extends State<_DownloadCTA> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.download),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [AppColors.primaryLight, AppColors.cyan]
                  : [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Text(
            'İndir',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
