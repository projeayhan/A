import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emlakci_panel/core/services/log_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/realtor_provider.dart';
import '../../providers/theme_provider.dart';

class EmlakShell extends ConsumerStatefulWidget {
  final Widget child;

  const EmlakShell({super.key, required this.child});

  @override
  ConsumerState<EmlakShell> createState() => _EmlakShellState();
}

class _EmlakShellState extends ConsumerState<EmlakShell> {
  bool _isCollapsed = false;

  // Session idle timeout
  Timer? _idleTimer;
  static const _idleTimeout = Duration(minutes: 30);

  // Search focus
  final _searchFocusNode = FocusNode();

  // Scaffold key for mobile drawer
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _handleIdleTimeout);
  }

  Future<void> _handleIdleTimeout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e, st) {
      LogService.error('Sign out failed', error: e, stackTrace: st, source: 'EmlakShell:_handleIdleTimeout');
    }
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Route → page title mapping
  String _getPageTitle(String route) {
    if (route.startsWith('/listings')) return 'Ilanlarim';
    if (route.startsWith('/appointments')) return 'Randevular';
    if (route.startsWith('/clients')) return 'Musteriler';
    if (route.startsWith('/analytics')) return 'Performans';
    if (route.startsWith('/promotions')) return 'One Cikarma';
    if (route.startsWith('/banner-ads')) return 'Banner Reklamları';
    if (route.startsWith('/chat')) return 'Mesajlar';
    if (route.startsWith('/profile')) return 'Profil';
    if (route.startsWith('/settings')) return 'Ayarlar';
    return 'Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () =>
            context.go('/dashboard'),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          } else {
            setState(() => _isCollapsed = !_isCollapsed);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Listener(
          onPointerDown: (_) => _resetIdleTimer(),
          onPointerMove: (_) => _resetIdleTimer(),
          child: Scaffold(
            key: _scaffoldKey,
            drawer: isMobile
                ? Drawer(
                    backgroundColor: AppColors.sidebarBg,
                    child: _buildSidebarContent(currentRoute, isDark,
                        isMobileDrawer: true),
                  )
                : null,
            body: Row(
              children: [
                // Desktop sidebar
                if (!isMobile)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isCollapsed ? 80 : 280,
                    child: _buildSidebar(currentRoute, isDark),
                  ),
                // Main content
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(currentRoute, isMobile, isDark),
                      Expanded(
                        child: Container(
                          color: isDark
                              ? AppColors.backgroundDark
                              : AppColors.backgroundLight,
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // SIDEBAR
  // ============================================

  Widget _buildSidebar(String currentRoute, bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(
          right: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      child: _buildSidebarContent(currentRoute, isDark),
    );
  }

  Widget _buildSidebarContent(String currentRoute, bool isDark,
      {bool isMobileDrawer = false}) {
    final showLabels = isMobileDrawer || !_isCollapsed;
    final unreadMessages = ref.watch(unreadMessagesCountProvider);

    return Column(
      children: [
        // Logo header
        Container(
          height: 70,
          padding: EdgeInsets.symmetric(
              horizontal: (!isMobileDrawer && _isCollapsed) ? 16 : 24),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.home_work_rounded,
                    color: Colors.white, size: 24),
              ),
              if (showLabels) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Emlakci Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'SuperCyp Emlak',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const Divider(color: Color(0xFF334155), height: 1),

        // Navigation items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            children: [
              // ANA MENU
              if (showLabels) _buildSectionLabel('ANA MENU'),
              _buildNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                route: '/dashboard',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),
              _buildNavItem(
                icon: Icons.home_work_rounded,
                label: 'Ilanlarim',
                route: '/listings',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),
              _buildNavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Randevular',
                route: '/appointments',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),
              _buildNavItem(
                icon: Icons.people_rounded,
                label: 'Musteriler',
                route: '/clients',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),

              const SizedBox(height: 16),

              // RAPORLAR
              if (showLabels) _buildSectionLabel('RAPORLAR'),
              _buildNavItem(
                icon: Icons.analytics_rounded,
                label: 'Performans',
                route: '/analytics',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),
              _buildNavItem(
                icon: Icons.star_rounded,
                label: 'One Cikarma',
                route: '/promotions',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),
              _buildNavItem(
                icon: Icons.campaign_rounded,
                label: 'Banner Reklamları',
                route: '/banner-ads',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),

              const SizedBox(height: 16),

              // ILETISIM
              if (showLabels) _buildSectionLabel('ILETISIM'),
              _buildNavItem(
                icon: Icons.message_rounded,
                label: 'Mesajlar',
                route: '/chat',
                currentRoute: currentRoute,
                showLabel: showLabels,
                badgeCount: unreadMessages,
                isMobileDrawer: isMobileDrawer,
              ),

              const SizedBox(height: 16),

              // AYARLAR
              if (showLabels) _buildSectionLabel('AYARLAR'),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
                route: '/profile',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: 'Ayarlar',
                route: '/settings',
                currentRoute: currentRoute,
                showLabel: showLabels,
                isMobileDrawer: isMobileDrawer,
              ),
            ],
          ),
        ),

        // Logout button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                try {
                  await Supabase.instance.client.auth.signOut();
                } catch (e, st) {
                  LogService.error('Sign out failed', error: e, stackTrace: st, source: 'EmlakShell:signOut');
                }
                if (mounted) {
                  if (isMobileDrawer) Navigator.of(context).pop();
                  context.go('/login');
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: showLabels ? 16 : 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: showLabels
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: AppColors.error, size: 22),
                    if (showLabels) ...[
                      const SizedBox(width: 12),
                      const Text(
                        'Cikis Yap',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Collapse button (desktop only)
        if (!isMobileDrawer)
          Container(
            padding: const EdgeInsets.all(12),
            child: IconButton(
              onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              icon: Icon(
                _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: Colors.white38,
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF334155).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String route,
    required String currentRoute,
    required bool showLabel,
    bool isMobileDrawer = false,
    int badgeCount = 0,
  }) {
    final isSelected = currentRoute == route ||
        (route != '/dashboard' && currentRoute.startsWith(route));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isMobileDrawer) Navigator.of(context).pop();
            context.go(route);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
                horizontal: showLabel ? 16 : 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.sidebarActive.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: AppColors.sidebarActive.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              mainAxisAlignment:
                  showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: isSelected
                          ? AppColors.sidebarActive
                          : AppColors.sidebarText,
                      size: 22,
                    ),
                    if (badgeCount > 0 && !showLabel)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 18, minHeight: 18),
                          child: Text(
                            badgeCount > 99
                                ? '99+'
                                : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (showLabel) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.sidebarActive
                            : AppColors.sidebarText,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99
                            ? '99+'
                            : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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

  // ============================================
  // TOP BAR
  // ============================================

  Widget _buildTopBar(String currentRoute, bool isMobile, bool isDark) {
    final profileAsync = ref.watch(realtorProfileProvider);
    final topBarBg = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);
    final textMuted = AppColors.textMuted(isDark);
    final searchBg = isDark ? AppColors.backgroundDark : const Color(0xFFF1F5F9);

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: topBarBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Mobile: hamburger menu
          if (isMobile)
            IconButton(
              onPressed: () =>
                  _scaffoldKey.currentState?.openDrawer(),
              icon: Icon(Icons.menu_rounded, color: textSecondary),
            ),

          // Page title
          if (!isMobile) ...[
            Text(
              _getPageTitle(currentRoute),
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
          ] else ...[
            const SizedBox(width: 8),
            Text(
              _getPageTitle(currentRoute),
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
          ],

          // "Yeni Ilan" button
          if (!isMobile)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/listings/add'),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Yeni Ilan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),

          // Theme toggle
          IconButton(
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: textSecondary,
            ),
            tooltip: isDark ? 'Acik Tema' : 'Koyu Tema',
            style: IconButton.styleFrom(
              backgroundColor: searchBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(width: 8),

          // Notifications bell
          IconButton(
            onPressed: () {
              // TODO: Notifications panel
            },
            icon: Badge(
              smallSize: 8,
              child: Icon(Icons.notifications_outlined, color: textSecondary),
            ),
            style: IconButton.styleFrom(
              backgroundColor: searchBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            tooltip: 'Bildirimler',
          ),

          const SizedBox(width: 12),

          // Profile card
          profileAsync.when(
            data: (profile) {
              final companyName =
                  profile?['company_name'] as String? ?? 'Emlakci';
              final city = profile?['city'] as String? ?? '';
              final initials = companyName.isNotEmpty
                  ? companyName.substring(0, 1).toUpperCase()
                  : 'E';

              return PopupMenuButton<String>(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              companyName,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (city.isNotEmpty)
                              Text(
                                city,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.keyboard_arrow_down,
                            color: textMuted, size: 20),
                      ],
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 12),
                        Text('Profil'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Ayarlar'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: AppColors.error),
                        SizedBox(width: 12),
                        Text('Cikis Yap',
                            style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'logout') {
                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (e, st) {
                      LogService.error('Sign out failed', error: e, stackTrace: st, source: 'EmlakShell:popupSignOut');
                    }
                    if (mounted) context.go('/login');
                  } else if (value == 'profile') {
                    context.go('/profile');
                  } else if (value == 'settings') {
                    context.go('/settings');
                  }
                },
              );
            },
            loading: () => const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.error.withValues(alpha: 0.2),
              child: const Icon(Icons.error_outline,
                  color: AppColors.error, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
