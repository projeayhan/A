import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/admin_auth_service.dart';
import '../../core/services/admin_log_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/models/sector_type.dart';
import '../../core/services/permission_config.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/router/app_router.dart';
import 'breadcrumbs.dart';
import 'floating_ai_assistant.dart';
import 'global_search_overlay.dart';

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _isCollapsed = false;

  // Collapsible menü grupları için state
  final Map<String, bool> _expandedGroups = {
    'services': true,
    'finance': false,
    'management': false,
    'support': false,
    'system': false,
  };

  // Session idle timeout
  Timer? _idleTimer;
  static const _idleTimeout = Duration(minutes: 30);
  DateTime _lastActivity = DateTime.now();
  static const _idleThrottle = Duration(seconds: 30);

  // Search focus
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    // Throttle: sadece 30 saniyede bir Timer yeniden oluştur
    final now = DateTime.now();
    if (now.difference(_lastActivity) < _idleThrottle) return;
    _lastActivity = now;
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _handleIdleTimeout);
  }

  Future<void> _handleIdleTimeout() async {
    try {
      final logService = ref.read(adminLogServiceProvider);
      await logService.logLogout();
    } catch (_) {}
    try {
      final authService = ref.read(adminAuthServiceProvider);
      await authService.signOut();
      ref.read(currentAdminProvider.notifier).clear();
    } catch (_) {}
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminAsync = ref.watch(currentAdminProvider);
    final currentRoute = GoRouterState.of(context).matchedLocation;
    // Sadece total değiştiğinde rebuild — tüm PendingApplicationCounts objesini dinlemiyoruz
    final pendingTotal = ref.watch(notificationServiceProvider.select((c) => c.total));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () => context.go(AppRoutes.dashboard),
        const SingleActivator(LogicalKeyboardKey.keyU, control: true): () => context.go(AppRoutes.users),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => context.go(AppRoutes.finance),
        // Ctrl+1-8: Sektör kısayolları
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => context.go(SectorType.food.baseRoute),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => context.go(SectorType.market.baseRoute),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => context.go(SectorType.store.baseRoute),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => context.go(SectorType.realEstate.baseRoute),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => context.go(SectorType.taxi.baseRoute),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true): () => context.go(SectorType.carSales.baseRoute),
        const SingleActivator(LogicalKeyboardKey.digit7, control: true): () => context.go(SectorType.jobs.baseRoute),
        const SingleActivator(LogicalKeyboardKey.digit8, control: true): () => context.go(SectorType.carRental.baseRoute),
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
            body: Stack(
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isCollapsed ? 80 : 280,
                      child: _buildSidebar(currentRoute, adminAsync, pendingTotal, isDark),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _buildTopBar(adminAsync, isDark),
                          const AdminBreadcrumbs(),
                          Expanded(
                            child: Container(
                              color: theme.scaffoldBackgroundColor,
                              child: widget.child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const FloatingAIAssistant(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // RBAC: check if admin has access to a sidebar group
  bool _hasGroupAccess(AdminUser? admin, String groupKey) {
    if (admin == null) return false;
    if (admin.isSuperAdmin) return true;
    final module = PermissionConfig.groupPermissions[groupKey];
    if (module == null) return true;
    // For groups that map to multiple modules, check if admin has access to any
    if (module == '*') return true;
    return admin.hasPermission(module, 'read');
  }

  Widget _buildSidebar(String currentRoute, AsyncValue<AdminUser?> adminAsync, int pendingTotal, bool isDark) {
    final admin = adminAsync.valueOrNull;
    final sidebarBg = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 72,
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 16 : 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 24),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SuperCyp', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Admin Panel', style: TextStyle(color: textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(color: borderColor, height: 1),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                // Dashboard - her zaman görünür
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: AppRoutes.dashboard,
                  currentRoute: currentRoute,
                  isDark: isDark,
                ),

                _buildNavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Raporlar',
                  route: AppRoutes.reports,
                  currentRoute: currentRoute,
                  isDark: isDark,
                ),

                const SizedBox(height: 8),

                // ─── HİZMETLER ───
                if (!_isCollapsed)
                  _buildSectionLabel('HİZMETLER', isDark),

                if (_hasGroupAccess(admin, 'services'))
                  _buildNavGroup(
                    groupKey: 'services',
                    icon: Icons.business_rounded,
                    label: 'Hizmetler',
                    currentRoute: currentRoute,
                    isDark: isDark,
                    children: [
                      _NavChild(SectorType.food.icon, SectorType.food.label, SectorType.food.baseRoute),
                      _NavChild(SectorType.market.icon, SectorType.market.label, SectorType.market.baseRoute),
                      _NavChild(SectorType.store.icon, SectorType.store.label, SectorType.store.baseRoute),
                      _NavChild(SectorType.realEstate.icon, SectorType.realEstate.label, SectorType.realEstate.baseRoute),
                      _NavChild(SectorType.taxi.icon, SectorType.taxi.label, SectorType.taxi.baseRoute),
                      _NavChild(SectorType.carSales.icon, SectorType.carSales.label, SectorType.carSales.baseRoute),
                      _NavChild(SectorType.jobs.icon, SectorType.jobs.label, SectorType.jobs.baseRoute),
                      _NavChild(SectorType.carRental.icon, SectorType.carRental.label, SectorType.carRental.baseRoute),
                    ],
                  ),

                const SizedBox(height: 8),

                // ─── YÖNETİM ───
                if (!_isCollapsed)
                  _buildSectionLabel('YÖNETİM', isDark),

                if (_hasGroupAccess(admin, 'management'))
                  _buildNavGroup(
                    groupKey: 'finance',
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Finans',
                    currentRoute: currentRoute,
                    isDark: isDark,
                    children: [
                      _NavChild(Icons.dashboard_outlined, 'Dashboard', AppRoutes.finance),
                      _NavChild(Icons.receipt_long_outlined, 'Faturalar', AppRoutes.financeInvoices),
                      _NavChild(Icons.swap_horiz_outlined, 'Gelir/Gider', AppRoutes.financeIncomeExpense),
                      _NavChild(Icons.percent_outlined, 'Komisyon', AppRoutes.financeCommission),
                      _NavChild(Icons.assessment_outlined, 'Raporlar', AppRoutes.reports),
                    ],
                  ),

                if (_hasGroupAccess(admin, 'management'))
                  _buildNavGroup(
                    groupKey: 'management',
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Yönetim',
                    currentRoute: currentRoute,
                    badgeCount: pendingTotal,
                    isDark: isDark,
                    children: [
                      _NavChild(Icons.assignment_outlined, 'Başvurular', AppRoutes.applications, badgeCount: pendingTotal),
                      _NavChild(Icons.people_outline, 'Kullanıcılar', AppRoutes.users),
                      _NavChild(Icons.delivery_dining_outlined, 'Sürücü Yönetimi', AppRoutes.partners),
                      _NavChild(Icons.star_outline_rounded, 'Öne Çıkarma Talepleri', AppRoutes.promotionRequests),
                    ],
                  ),

                const SizedBox(height: 8),

                // ─── DESTEK ───
                if (!_isCollapsed)
                  _buildSectionLabel('DESTEK', isDark),

                if (_hasGroupAccess(admin, 'support'))
                  _buildNavGroup(
                    groupKey: 'support',
                    icon: Icons.headset_mic_rounded,
                    label: 'Destek Yönetimi',
                    currentRoute: currentRoute,
                    isDark: isDark,
                    children: [
                      _NavChild(Icons.dashboard_outlined, 'Dashboard', AppRoutes.supportDashboard),
                      _NavChild(Icons.assignment_outlined, 'Ticket İnceleme', AppRoutes.ticketReview),
                      _NavChild(Icons.bar_chart_outlined, 'Temsilci Performans', AppRoutes.agentPerformance),
                      _NavChild(Icons.analytics_outlined, 'Raporlar', AppRoutes.supportReports),
                      _NavChild(Icons.support_agent_outlined, 'AI Destek', AppRoutes.aiSupport),
                      _NavChild(Icons.people_outline, 'Destek Agentları', AppRoutes.supportAgents),
                      _NavChild(Icons.receipt_long, 'Sipariş Geçmişi', AppRoutes.orderHistory),
                    ],
                  ),

                const SizedBox(height: 8),

                // ─── SİSTEM ───
                if (!_isCollapsed)
                  _buildSectionLabel('SİSTEM', isDark),

                if (_hasGroupAccess(admin, 'system'))
                  _buildNavGroup(
                    groupKey: 'system',
                    icon: Icons.settings_rounded,
                    label: 'Sistem',
                    currentRoute: currentRoute,
                    isDark: isDark,
                    children: [
                      _NavChild(Icons.settings_outlined, 'Ayarlar', AppRoutes.settings),
                      _NavChild(Icons.security_outlined, 'Güvenlik', AppRoutes.security),
                      _NavChild(Icons.history_outlined, 'Loglar', AppRoutes.logs),
                      _NavChild(Icons.monitor_heart_outlined, 'Sistem Sağlığı', AppRoutes.systemHealth),
                      _NavChild(Icons.notifications_outlined, 'Bildirimler', AppRoutes.notifications),
                      _NavChild(Icons.gavel_outlined, 'Yaptırımlar', AppRoutes.sanctions),
                      _NavChild(Icons.two_wheeler_outlined, 'Kurye Araç Tipleri', AppRoutes.courierVehicleTypes),
                      _NavChild(Icons.image_outlined, 'Bannerlar', AppRoutes.banners),
                      _NavChild(Icons.inventory_2_outlined, 'Banner Paketleri', AppRoutes.bannerPackages),
                    ],
                  ),
              ],
            ),
          ),

          // Collapse Button
          Container(
            padding: const EdgeInsets.all(12),
            child: IconButton(
              onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              icon: Icon(
                _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
              ),
              style: IconButton.styleFrom(
                backgroundColor: (isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0)).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _audioInitialized = false;

  void _initAudioOnFirstClick() {
    if (!_audioInitialized) {
      _audioInitialized = true;
      try {
        ref.read(notificationServiceProvider.notifier).playNotificationSound();
      } catch (e) {
        // Sessizce devam et
      }
    }
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          color: textMuted,
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
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = currentRoute == route;
    final textSecondary = isDark ? AppColors.textSecondary : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _initAudioOnFirstClick();
            context.go(route);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 12 : 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: isSelected ? AppColors.primary : textSecondary, size: 22),
                    if (badgeCount > 0)
                      Positioned(
                        right: -8, top: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildTopBar(AsyncValue<AdminUser?> adminAsync, bool isDark) {
    final topBarBg = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final searchBg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);
    final textSecondary = isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final textPrimary = isDark ? AppColors.textPrimary : const Color(0xFF0F172A);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: topBarBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: GlobalSearchOverlay(focusNode: _searchFocusNode),
          ),

          const SizedBox(width: 24),

          // Theme toggle
          IconButton(
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: textSecondary,
            ),
            tooltip: isDark ? 'Açık Tema' : 'Koyu Tema',
            style: IconButton.styleFrom(
              backgroundColor: searchBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(width: 12),

          // Notifications
          IconButton(
            onPressed: () {
              final notificationService = ref.read(notificationServiceProvider.notifier);
              notificationService.playNotificationSound();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bildirim sesi aktif edildi'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: Badge(
              smallSize: 8,
              child: Icon(Icons.notifications_outlined, color: textSecondary),
            ),
            style: IconButton.styleFrom(
              backgroundColor: searchBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            tooltip: 'Bildirim sesini test et',
          ),

          const SizedBox(width: 12),

          // Profile
          adminAsync.when(
            data: (admin) => PopupMenuButton<String>(
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        admin?.fullName.isNotEmpty == true ? admin!.fullName.substring(0, 1).toUpperCase() : 'A',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(admin?.fullName ?? 'Admin', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(admin?.roleDisplayName ?? 'Yönetici', style: TextStyle(color: textMuted, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down, color: textMuted, size: 20),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(children: [Icon(Icons.person_outline, size: 20), SizedBox(width: 12), Text('Profil')]),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [Icon(Icons.settings_outlined, size: 20), SizedBox(width: 12), Text('Ayarlar')]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Çıkış Yap', style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
              onSelected: (value) async {
                if (value == 'logout') {
                  final logService = ref.read(adminLogServiceProvider);
                  await logService.logLogout();
                  final authService = ref.read(adminAuthServiceProvider);
                  await authService.signOut();
                  ref.read(currentAdminProvider.notifier).clear();
                  if (mounted) context.go(AppRoutes.login);
                } else if (value == 'profile') {
                  context.go(AppRoutes.settings);
                } else if (value == 'settings') {
                  context.go(AppRoutes.settings);
                }
              },
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => const Icon(Icons.error),
          ),
        ],
      ),
    );
  }

  // Collapsible navigation group widget
  Widget _buildNavGroup({
    required String groupKey,
    required IconData icon,
    required String label,
    required String currentRoute,
    required List<_NavChild> children,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isExpanded = _expandedGroups[groupKey] ?? false;
    final hasActiveChild = children.any((child) => currentRoute == child.route || currentRoute.startsWith('${child.route}/'));
    final textSecondary = isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);

    // Eğer aktif child varsa grubu otomatik aç
    if (hasActiveChild && !isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _expandedGroups[groupKey] = true);
      });
    }

    return Column(
      children: [
        // Group Header
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expandedGroups[groupKey] = !isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 12 : 16, vertical: 12),
              decoration: BoxDecoration(
                color: hasActiveChild ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, color: hasActiveChild ? AppColors.primary : textSecondary, size: 22),
                      if (badgeCount > 0 && _isCollapsed)
                        Positioned(
                          right: -8, top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: hasActiveChild ? AppColors.primary : textSecondary,
                          fontWeight: hasActiveChild ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: hasActiveChild ? AppColors.primary : textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Children (when expanded and not collapsed)
        if (isExpanded && !_isCollapsed)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: children.map((child) {
                final isSelected = currentRoute == child.route || currentRoute.startsWith('${child.route}/');
                return Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go(child.route),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(child.icon, color: isSelected ? AppColors.primary : textMuted, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                child.label,
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : textSecondary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (child.badgeCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  child.badgeCount > 99 ? '99+' : child.badgeCount.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// Navigation child item data class
class _NavChild {
  final IconData icon;
  final String label;
  final String route;
  final int badgeCount;

  const _NavChild(this.icon, this.label, this.route, {this.badgeCount = 0});
}
