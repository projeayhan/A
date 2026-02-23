import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/support_auth_service.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/ticket_providers.dart';
import 'global_search_dialog.dart';

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

class SupportShell extends ConsumerStatefulWidget {
  final Widget child;
  const SupportShell({super.key, required this.child});

  @override
  ConsumerState<SupportShell> createState() => _SupportShellState();
}

class _SupportShellState extends ConsumerState<SupportShell> {
  bool _isCollapsed = false;

  void _openGlobalSearch() {
    showDialog(context: context, builder: (_) => const GlobalSearchDialog());
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(currentAgentProvider).value;
    final openCount = ref.watch(openTicketCountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final route = GoRouterState.of(context).matchedLocation;

    final bgColor = isDark ? AppColors.background : AppColors.lightBackground;
    final sidebarColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): const _OpenSearchIntent(),
      },
      child: Actions(
        actions: {
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (_) { _openGlobalSearch(); return null; },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: bgColor,
            body: Row(
              children: [
                // Sidebar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isCollapsed ? 72 : 260,
                  decoration: BoxDecoration(
                    color: sidebarColor,
                    border: Border(right: BorderSide(color: borderColor)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        height: 64,
                        padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 12 : 20),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.support_agent, color: AppColors.primary, size: 22),
                            ),
                            if (!_isCollapsed) ...[
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Destek Paneli', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Nav items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildNavItem(Icons.dashboard_outlined, 'Dashboard', AppRoutes.dashboard, route, textPrimary, textMuted),
                            _buildNavItem(Icons.confirmation_number_outlined, 'Ticketlar', AppRoutes.tickets, route, textPrimary, textMuted, badge: openCount > 0 ? openCount : null),
                            _buildNavItem(Icons.people_outline, 'Müşteriler', AppRoutes.customers, route, textPrimary, textMuted),
                            _buildNavItem(Icons.chat_outlined, 'Canlı Chat', AppRoutes.liveChat, route, textPrimary, textMuted),
                            _buildNavItem(Icons.store_outlined, 'İşletmeler', AppRoutes.businesses, route, textPrimary, textMuted),
                            const Divider(height: 24),
                            _buildNavItem(Icons.settings_outlined, 'Ayarlar', AppRoutes.settings, route, textPrimary, textMuted),
                          ],
                        ),
                      ),

                      // Collapse toggle
                      Container(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                        child: ListTile(
                          dense: true,
                          leading: Icon(_isCollapsed ? Icons.chevron_right : Icons.chevron_left, color: textMuted, size: 20),
                          title: _isCollapsed ? null : Text('Daralt', style: TextStyle(color: textMuted, fontSize: 13)),
                          onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: Column(
                    children: [
                      // Top bar
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: sidebarColor,
                          border: Border(bottom: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            // Breadcrumb placeholder
                            Expanded(
                              child: Text(
                                _getPageTitle(route),
                                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),

                            // Global search button
                            IconButton(
                              icon: Icon(Icons.search, color: textMuted, size: 20),
                              onPressed: _openGlobalSearch,
                              tooltip: 'Ara (Ctrl+K)',
                            ),
                            const SizedBox(width: 8),

                            // Agent status toggle
                            if (agent != null) ...[
                              _buildStatusChip(agent.status, textMuted),
                              const SizedBox(width: 16),
                            ],

                            // Theme toggle
                            IconButton(
                              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textMuted, size: 20),
                              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                              tooltip: isDark ? 'Açık Tema' : 'Koyu Tema',
                            ),
                            const SizedBox(width: 8),

                            // Agent info
                            if (agent != null) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                child: Text(
                                  agent.fullName.isNotEmpty ? agent.fullName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!_isCollapsed)
                                Text(agent.fullName, style: TextStyle(color: textPrimary, fontSize: 13)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.logout, color: textMuted, size: 20),
                                onPressed: _handleLogout,
                                tooltip: 'Çıkış Yap',
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Page content
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ); // Shortcuts
  }

  Widget _buildNavItem(IconData icon, String label, String route, String currentRoute, Color textPrimary, Color textMuted, {int? badge}) {
    final isActive = currentRoute == route || (route != '/' && currentRoute.startsWith(route));
    final color = isActive ? AppColors.primary : textMuted;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 8 : 12, vertical: 2),
      child: Material(
        color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(route),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 12 : 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive ? AppColors.primary : textPrimary,
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color textMuted) {
    Color color;
    String label;
    switch (status) {
      case 'online': color = AppColors.success; label = 'Çevrimiçi'; break;
      case 'busy': color = AppColors.warning; label = 'Meşgul'; break;
      case 'break': color = AppColors.info; label = 'Mola'; break;
      default: color = textMuted; label = 'Çevrimdışı';
    }

    return PopupMenuButton<String>(
      onSelected: (newStatus) {
        ref.read(currentAgentProvider.notifier).updateStatus(newStatus);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'online', child: Text('Çevrimiçi')),
        const PopupMenuItem(value: 'busy', child: Text('Meşgul')),
        const PopupMenuItem(value: 'break', child: Text('Mola')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  String _getPageTitle(String route) {
    if (route == '/') return 'Dashboard';
    if (route.startsWith('/tickets')) return 'Ticketlar';
    if (route.startsWith('/customers')) return 'Müşteriler';
    if (route.startsWith('/businesses')) return 'İşletmeler';
    if (route.startsWith('/live-chat')) return 'Canlı Chat';
    if (route.startsWith('/settings')) return 'Ayarlar';
    return '';
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(supportAuthServiceProvider).signOut();
      ref.read(currentAgentProvider.notifier).clear();
      if (mounted) context.go(AppRoutes.login);
    }
  }
}
