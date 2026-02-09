import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/emlak_models.dart';
import '../../providers/property_provider.dart';
import '../../providers/realtor_provider.dart';
import '../../services/notification_sound_service.dart';
import '../chat/chat_list_screen.dart';

/// Emlakçı Panel Ana Ekranı - Responsive Web Panel
class RealtorPanelScreen extends ConsumerStatefulWidget {
  const RealtorPanelScreen({super.key});

  @override
  ConsumerState<RealtorPanelScreen> createState() => _RealtorPanelScreenState();
}

class _RealtorPanelScreenState extends ConsumerState<RealtorPanelScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Performans sayfası için state
  int _selectedTimePeriod = 1; // 0: 7 gün, 1: 30 gün, 2: 3 ay
  String? _selectedPropertyForGraph; // Grafik için seçili ilan ID

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isMobile = screenWidth < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isMobile ? _buildDrawer() : null,
      body: Row(
        children: [
          // Sidebar - Desktop & Tablet
          if (!isMobile)
            _buildSidebar(isCollapsed: isTablet),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(isMobile),

                // Content
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E293B),
      child: _buildSidebarContent(isCollapsed: false),
    );
  }

  Widget _buildSidebar({bool isCollapsed = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 80 : 260,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: _buildSidebarContent(isCollapsed: isCollapsed),
    );
  }

  Widget _buildSidebarContent({required bool isCollapsed}) {
    return Column(
      children: [
        // Logo Header
        Container(
          height: 70,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 16 : 20),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white10),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.real_estate_agent, color: Colors.white, size: 24),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Emlakçı Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Navigation Items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 8),
                    child: Text(
                      'ANA MENÜ',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard', isCollapsed),
                _buildNavItem(1, Icons.home_work_rounded, 'İlanlarım', isCollapsed),
                _buildNavItem(2, Icons.calendar_month_rounded, 'Randevular', isCollapsed),

                const SizedBox(height: 16),
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 8),
                    child: Text(
                      'RAPORLAR',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                _buildNavItem(3, Icons.analytics_rounded, 'Performans', isCollapsed),

                const SizedBox(height: 16),
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 8),
                    child: Text(
                      'AYARLAR',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                _buildNavItem(4, Icons.person_rounded, 'Profil', isCollapsed),
                _buildNavItem(5, Icons.settings_rounded, 'Ayarlar', isCollapsed),
              ],
            ),
          ),
        ),

        // Logout Button
        Container(
          padding: EdgeInsets.all(isCollapsed ? 12 : 16),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white10),
            ),
          ),
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    const Text(
                      'Çıkış Yap',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isCollapsed) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            NotificationSoundService.initializeAudio();
            setState(() => _selectedIndex = index);
            if (MediaQuery.of(context).size.width < 768) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)) : null,
            ),
            child: Row(
              mainAxisSize: isCollapsed ? MainAxisSize.min : MainAxisSize.max,
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF3B82F6) : Colors.white60,
                  size: 20,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
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

  Widget _buildTopBar(bool isMobile) {
    final realtorProfile = ref.watch(realtorProfileProvider);
    final profile = realtorProfile.valueOrNull;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF1E293B)),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          if (!isMobile)
            Text(
              _getPageTitle(),
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

          const Spacer(),

          // Quick Actions
          if (!isMobile)
            _buildTopBarButton(Icons.add_home_rounded, 'Yeni İlan', () => context.push('/add-property'))
          else
            IconButton(
              icon: const Icon(Icons.add_home_rounded, color: Color(0xFF3B82F6)),
              onPressed: () => context.push('/add-property'),
            ),
          const SizedBox(width: 4),

          // Notifications
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF64748B)),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 4),

          // Profile
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      (profile?['company_name'] as String? ?? 'E')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?['company_name'] ?? 'Emlakçı',
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            profile?['city'] ?? '',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'İlanlarım';
      case 2: return 'Randevular';
      case 3: return 'Performans';
      case 4: return 'Profil';
      case 5: return 'Ayarlar';
      default: return 'Dashboard';
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardContent();
      case 1: return _buildListingsContent();
      case 2: return _buildAppointmentsContent();
      case 3: return _buildPerformanceContent();
      case 4: return _buildProfileContent();
      case 5: return _buildSettingsContent();
      default: return _buildDashboardContent();
    }
  }

  // ==================== DASHBOARD ====================
  Widget _buildDashboardContent() {
    final dashboardStats = ref.watch(realtorDashboardStatsProvider);
    final userProperties = ref.watch(userPropertiesProvider);
    final appointmentsState = ref.watch(realtorAppointmentsProvider);
    final stats = dashboardStats.valueOrNull ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hoş Geldiniz! 👋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'İşte bugünkü özet bilgileriniz',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.trending_up, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth > 600 ? 2.0 : 2.5,
                children: [
                  _buildStatCard('Aktif İlanlar', '${userProperties.activeProperties.length}', Icons.home_work_rounded, const Color(0xFF10B981), '+12%'),
                  _buildStatCard('Bekleyen İlanlar', '${userProperties.pendingProperties.length}', Icons.hourglass_empty_rounded, const Color(0xFFF59E0B), ''),
                  _buildStatCard('Bugünkü Randevu', '${stats['today_appointments'] ?? 0}', Icons.calendar_today_rounded, const Color(0xFF3B82F6), ''),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Actions & Recent Activity
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildQuickActionsCard()),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: _buildTodayAppointmentsCard(appointmentsState)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildQuickActionsCard(),
                  const SizedBox(height: 24),
                  _buildTodayAppointmentsCard(appointmentsState),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trend.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          trend,
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hızlı İşlemler',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionItem(Icons.add_home_rounded, 'Yeni İlan Ekle', const Color(0xFF3B82F6), () => context.push('/add-property')),
          _buildQuickActionItem(Icons.calendar_month_rounded, 'Randevu Oluştur', const Color(0xFFF59E0B), () => _showAddAppointmentDialog()),
          _buildQuickActionItem(Icons.message_rounded, 'Mesajlar', const Color(0xFF10B981), () => _openMessages()),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayAppointmentsCard(RealtorAppointmentsState appointmentsState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bugünkü Randevular',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 3),
                child: const Text('Tümünü Gör'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (appointmentsState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (appointmentsState.todayAppointments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'Bugün randevunuz yok',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ...appointmentsState.todayAppointments.take(3).map((apt) => _buildAppointmentItem(apt)),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(Map<String, dynamic> appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.access_time, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment['properties']?['title'] ?? appointment['title'] ?? 'Randevu',
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  appointment['appointment_time'] != null
                      ? (appointment['appointment_time'] as String).substring(0, 5)
                      : (appointment['scheduled_at'] != null
                          ? DateTime.parse(appointment['scheduled_at']).toString().substring(11, 16)
                          : ''),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(appointment['status']).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusLabel(appointment['status']),
              style: TextStyle(
                color: _getStatusColor(appointment['status']),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'scheduled': return const Color(0xFF3B82F6);
      case 'pending': return const Color(0xFFF59E0B);  // Beklemede - sarı
      case 'confirmed': return const Color(0xFF3B82F6); // Onaylandı - mavi
      case 'completed': return const Color(0xFF10B981);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'scheduled': return 'Planlandı';
      case 'pending': return 'Beklemede';
      case 'confirmed': return 'Onaylandı';
      case 'completed': return 'Tamamlandı';
      case 'cancelled': return 'İptal';
      default: return status ?? '';
    }
  }

  // ==================== LISTINGS ====================
  Widget _buildListingsContent() {
    final userProperties = ref.watch(userPropertiesProvider);

    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'İlan ara...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.filter_list, color: Color(0xFF64748B), size: 20),
                    SizedBox(width: 8),
                    Text('Filtrele', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Listings
        Expanded(
          child: userProperties.isLoading
              ? const Center(child: CircularProgressIndicator())
              : userProperties.allProperties.isEmpty
                  ? _buildEmptyState('Henüz ilanınız yok', Icons.home_work_outlined, 'Yeni İlan Ekle', () => context.push('/add-property'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: userProperties.allProperties.length,
                      itemBuilder: (context, index) => _buildPropertyCard(userProperties.allProperties[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => context.push('/property/${property.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: property.images.isNotEmpty
                    ? Image.network(
                        property.images.first,
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 80,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 80,
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.location.shortAddress,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          property.formattedPrice,
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: property.status == PropertyStatus.active
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            property.status.label,
                            style: TextStyle(
                              color: property.status == PropertyStatus.active
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== CLIENTS ====================
  // ==================== APPOINTMENTS ====================
  Widget _buildAppointmentsContent() {
    final appointmentsState = ref.watch(realtorAppointmentsProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Text(
                'Tüm Randevular',
                style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddAppointmentDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Randevu Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Appointments List
        Expanded(
          child: appointmentsState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : appointmentsState.appointments.isEmpty
                  ? _buildEmptyState('Henüz randevunuz yok', Icons.calendar_today_outlined, 'Randevu Ekle', _showAddAppointmentDialog)
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: appointmentsState.appointments.length,
                      itemBuilder: (context, index) => _buildAppointmentCard(appointmentsState.appointments[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    // appointment_date ve appointment_time kullan (appointments tablosu) veya scheduled_at (eski format)
    DateTime? scheduledAt;
    String? timeStr;

    if (appointment['appointment_date'] != null) {
      final dateStr = appointment['appointment_date'] as String;
      timeStr = appointment['appointment_time'] as String?;
      scheduledAt = DateTime.parse(dateStr);
    } else if (appointment['scheduled_at'] != null) {
      scheduledAt = DateTime.parse(appointment['scheduled_at']);
      timeStr = scheduledAt.toString().substring(11, 16);
    }

    final appointmentType = appointment['appointment_type'] as String? ?? 'showing';
    final property = appointment['properties'] as Map<String, dynamic>?;
    final requester = appointment['requester'] as Map<String, dynamic>?;
    final title = property?['title'] ?? appointment['title'] ?? 'Randevu Talebi';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showAppointmentDetailDialog(appointment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getAppointmentTypeColor(appointmentType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getAppointmentTypeIcon(appointmentType), color: _getAppointmentTypeColor(appointmentType)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (requester != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        requester['full_name'] ?? 'Müşteri',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          scheduledAt != null
                              ? '${scheduledAt.day}.${scheduledAt.month}.${scheduledAt.year}${timeStr != null ? ' ${timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr}' : ''}'
                              : '-',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                    if (property?['city'] != null || property?['district'] != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${property?['district'] ?? ''}, ${property?['city'] ?? ''}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else if (appointment['location'] != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              appointment['location'],
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(appointment['status']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(appointment['status']),
                      style: TextStyle(
                        color: _getStatusColor(appointment['status']),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 20),
                    onSelected: (value) async {
                      switch (value) {
                        case 'complete':
                          await ref.read(realtorAppointmentsProvider.notifier).completeAppointment(
                            appointment['id'],
                            'Tamamlandı',
                          );
                          break;
                        case 'cancel':
                          await ref.read(realtorAppointmentsProvider.notifier).cancelAppointment(
                            appointment['id'],
                            'Kullanıcı tarafından iptal edildi',
                          );
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (appointment['status'] == 'scheduled') ...[
                        const PopupMenuItem(value: 'complete', child: Text('Tamamlandı')),
                        const PopupMenuItem(value: 'cancel', child: Text('İptal Et', style: TextStyle(color: Colors.red))),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAppointmentTypeColor(String type) {
    switch (type) {
      case 'showing':
        return const Color(0xFF3B82F6);
      case 'meeting':
        return const Color(0xFF8B5CF6);
      case 'phone_call':
        return const Color(0xFF10B981);
      case 'video_call':
        return const Color(0xFF06B6D4);
      case 'signing':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getAppointmentTypeIcon(String type) {
    switch (type) {
      case 'showing':
        return Icons.home;
      case 'meeting':
        return Icons.groups;
      case 'phone_call':
        return Icons.phone;
      case 'video_call':
        return Icons.videocam;
      case 'signing':
        return Icons.draw;
      default:
        return Icons.calendar_today;
    }
  }

  // ==================== PERFORMANS SAYFASI ====================

  // Dönem günlerine çevir
  int _getSelectedDays() {
    switch (_selectedTimePeriod) {
      case 0:
        return 7;
      case 1:
        return 30;
      case 2:
        return 90;
      default:
        return 30;
    }
  }

  Widget _buildPerformanceContent() {
    final days = _getSelectedDays();
    final performanceStats = ref.watch(propertyPerformanceStatsProvider(days));

    return performanceStats.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Veriler yüklenirken hata oluştu: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(propertyPerformanceStatsProvider(days)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final propertyStatsList = (data['properties'] as List<Map<String, dynamic>>?) ?? [];
        final totals = (data['totals'] as Map<String, dynamic>?) ?? {};
        final previousTotals = (data['previousTotals'] as Map<String, dynamic>?) ?? {};

        // Toplam istatistikler
        final totalViews = (totals['views'] as int?) ?? 0;
        final totalFavorites = (totals['favorites'] as int?) ?? 0;
        final totalAppointments = (totals['appointments'] as int?) ?? 0;
        final prevTotalViews = (previousTotals['views'] as int?) ?? 0;
        final prevTotalFavorites = (previousTotals['favorites'] as int?) ?? 0;
        final prevTotalAppointments = (previousTotals['appointments'] as int?) ?? 0;

        // Değişim oranları hesapla
        final viewsChange = prevTotalViews > 0 ? ((totalViews - prevTotalViews) / prevTotalViews * 100) : 0.0;
        final favoritesChange = prevTotalFavorites > 0 ? ((totalFavorites - prevTotalFavorites) / prevTotalFavorites * 100) : 0.0;
        final appointmentsChange = prevTotalAppointments > 0 ? ((totalAppointments - prevTotalAppointments) / prevTotalAppointments * 100) : 0.0;
        final conversionRate = totalViews > 0 ? (totalAppointments / totalViews * 100) : 0.0;
        final prevConversionRate = prevTotalViews > 0 ? (prevTotalAppointments / prevTotalViews * 100) : 0.0;
        final conversionChange = prevConversionRate > 0 ? ((conversionRate - prevConversionRate) / prevConversionRate * 100) : 0.0;

        // En iyi 5 ve düşük performanslı ilanlar
        final topPropertyStats = propertyStatsList.take(5).toList();
        final lowPerformingStats = propertyStatsList.where((p) => (p['views'] as int? ?? 0) < 10).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zaman Filtresi
              _buildTimeFilterChips(),
              const SizedBox(height: 24),

              // Özet Kartları
              _buildSectionTitle('Performans Özeti'),
              const SizedBox(height: 16),
              _buildPerformanceSummaryCards(
                totalViews: totalViews,
                totalFavorites: totalFavorites,
                totalAppointments: totalAppointments,
                conversionRate: conversionRate,
                viewsChange: viewsChange,
                favoritesChange: favoritesChange,
                appointmentsChange: appointmentsChange,
                conversionChange: conversionChange,
              ),

              const SizedBox(height: 32),

              // İlan Bazlı Performans Tablosu
              _buildSectionTitle('İlan Bazlı Performans'),
              const SizedBox(height: 16),
              _buildPropertyPerformanceTableFromStats(propertyStatsList),

              const SizedBox(height: 32),

              // En İyi 5 İlan
              if (topPropertyStats.isNotEmpty) ...[
                _buildSectionTitle('🏆 En İyi Performans Gösteren İlanlar'),
                const SizedBox(height: 16),
                _buildTopPropertiesSectionFromStats(topPropertyStats),
                const SizedBox(height: 32),
              ],

              // Düşük Performanslı İlanlar
              if (lowPerformingStats.isNotEmpty) ...[
                _buildSectionTitle('⚠️ Dikkat Gerektiren İlanlar'),
                const SizedBox(height: 16),
                _buildLowPerformingPropertiesSectionFromStats(lowPerformingStats),
                const SizedBox(height: 32),
              ],

              // Grafik Alanı
              if (propertyStatsList.isNotEmpty) ...[
                _buildSectionTitle('📈 Görüntülenme Trendi'),
                const SizedBox(height: 16),
                _buildViewsGraphSectionFromStats(propertyStatsList),
                const SizedBox(height: 32),
              ],

              // Aktif Promosyonlar Bölümü
              _buildSectionTitle('🌟 Aktif Promosyonlar'),
              const SizedBox(height: 16),
              _buildActivePromotionsSection(),
            ],
          ),
        );
      },
    );
  }

  // Zaman Filtresi Chips
  Widget _buildTimeFilterChips() {
    final periods = ['7 Gün', '30 Gün', '3 Ay'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          const Text(
            'Dönem:',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          ...List.generate(periods.length, (index) {
            final isSelected = _selectedTimePeriod == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(periods[index]),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedTimePeriod = index);
                  }
                },
                selectedColor: const Color(0xFF3B82F6),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
              ),
            );
          }),
        ],
      ),
    );
  }

  // Özet Kartları
  Widget _buildPerformanceSummaryCards({
    required int totalViews,
    required int totalFavorites,
    required int totalAppointments,
    required double conversionRate,
    required double viewsChange,
    required double favoritesChange,
    required double appointmentsChange,
    required double conversionChange,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildStatCardWithChange(
              'Toplam Görüntülenme',
              '$totalViews',
              Icons.visibility_rounded,
              const Color(0xFF3B82F6),
              viewsChange,
            ),
            _buildStatCardWithChange(
              'Favorilere Eklenme',
              '$totalFavorites',
              Icons.favorite_rounded,
              const Color(0xFFEF4444),
              favoritesChange,
            ),
            _buildStatCardWithChange(
              'Randevu Talebi',
              '$totalAppointments',
              Icons.calendar_month_rounded,
              const Color(0xFF8B5CF6),
              appointmentsChange,
            ),
            _buildStatCardWithChange(
              'Dönüşüm Oranı',
              '%${conversionRate.toStringAsFixed(1)}',
              Icons.trending_up_rounded,
              const Color(0xFF10B981),
              conversionChange,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCardWithChange(String title, String value, IconData icon, Color color, double change) {
    final isPositive = change >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 14,
                    ),
                    Text(
                      '${change.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // İlan Bazlı Performans Tablosu (Stats verilerinden)
  Widget _buildPropertyPerformanceTableFromStats(List<Map<String, dynamic>> propertyStatsList) {
    if (propertyStatsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Henüz aktif ilanınız bulunmuyor',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Tablo Başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('İlan', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                const Expanded(child: Text('Görüntülenme', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                const Expanded(child: Text('Favori', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                const Expanded(child: Text('Randevu', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                const Expanded(child: Text('Dönüşüm', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                const SizedBox(width: 80, child: Text('Trend', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                const SizedBox(width: 90, child: Text('İşlem', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Tablo Satırları
          ...propertyStatsList.take(10).map((propStats) {
            final views = propStats['views'] as int? ?? 0;
            final favorites = propStats['favorites'] as int? ?? 0;
            final appointments = propStats['appointments'] as int? ?? 0;
            final conversion = views > 0 ? (appointments / views * 100) : 0.0;
            final prevViews = propStats['previousViews'] as int? ?? 0;
            final trend = prevViews > 0 ? ((views - prevViews) / prevViews * 100) : 0.0;

            return _buildPropertyTableRowFromStats(propStats, views, favorites, appointments, conversion, trend);
          }),
        ],
      ),
    );
  }

  Widget _buildPropertyTableRowFromStats(Map<String, dynamic> propStats, int views, int favorites, int appointments, double conversion, double trend) {
    final propertyId = propStats['id'] as String? ?? '';
    final images = (propStats['images'] as List?)?.cast<String>() ?? [];
    final title = propStats['title'] as String? ?? '';
    final district = propStats['district'] as String? ?? '';
    final city = propStats['city'] as String? ?? '';
    final isPositiveTrend = trend >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // İlan Bilgisi
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$district, $city',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Görüntülenme
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility, size: 14, color: Color(0xFF3B82F6)),
                const SizedBox(width: 4),
                Text('$views', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Favori
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Text('$favorites', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Randevu
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 4),
                Text('$appointments', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Dönüşüm
          Expanded(
            child: Text(
              '%${conversion.toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          // Mini Trend
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositiveTrend ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${trend.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Öne Çıkar butonu
          SizedBox(
            width: 90,
            child: Center(
              child: TextButton(
                onPressed: () => _showPromotionModal(propertyId, title),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text(
                  'Öne Çıkar',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // En İyi 5 İlan Bölümü
  Widget _buildTopPropertiesSection(List<Property> topProperties, Map<String, Map<String, int>> propertyStats) {
    if (topProperties.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF3B82F6).withValues(alpha: 0.05), const Color(0xFF8B5CF6).withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: topProperties.asMap().entries.map((entry) {
          final index = entry.key;
          final property = entry.value;
          final stats = propertyStats[property.id] ?? {};
          final views = stats['views'] ?? 0;
          final favorites = stats['favorites'] ?? 0;
          final appointments = stats['appointments'] ?? 0;

          return Container(
            margin: EdgeInsets.only(bottom: index < topProperties.length - 1 ? 12 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Sıralama rozeti
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: index == 0
                          ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                          : index == 1
                              ? [const Color(0xFFC0C0C0), const Color(0xFF808080)]
                              : index == 2
                                  ? [const Color(0xFFCD7F32), const Color(0xFF8B4513)]
                                  : [const Color(0xFF3B82F6), const Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Resim
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: property.images.isNotEmpty
                      ? Image.network(
                          property.images.first,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                        ),
                ),
                const SizedBox(width: 12),
                // Başlık
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${property.location.district}, ${property.location.city}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // İstatistikler
                Row(
                  children: [
                    _buildMiniStat(Icons.visibility, '$views', const Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    _buildMiniStat(Icons.favorite, '$favorites', const Color(0xFFEF4444)),
                    const SizedBox(width: 12),
                    _buildMiniStat(Icons.calendar_today, '$appointments', const Color(0xFF8B5CF6)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 12)),
      ],
    );
  }

  // En İyi 5 İlan Bölümü (Stats verilerinden)
  Widget _buildTopPropertiesSectionFromStats(List<Map<String, dynamic>> topPropertyStats) {
    if (topPropertyStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF3B82F6).withValues(alpha: 0.05), const Color(0xFF8B5CF6).withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: topPropertyStats.asMap().entries.map((entry) {
          final index = entry.key;
          final propStats = entry.value;
          final propertyId = propStats['id'] as String? ?? '';
          final images = (propStats['images'] as List?)?.cast<String>() ?? [];
          final title = propStats['title'] as String? ?? '';
          final district = propStats['district'] as String? ?? '';
          final city = propStats['city'] as String? ?? '';
          final views = propStats['views'] as int? ?? 0;
          final favorites = propStats['favorites'] as int? ?? 0;
          final appointments = propStats['appointments'] as int? ?? 0;

          return Container(
            margin: EdgeInsets.only(bottom: index < topPropertyStats.length - 1 ? 12 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Sıralama rozeti
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: index == 0
                          ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                          : index == 1
                              ? [const Color(0xFFC0C0C0), const Color(0xFF808080)]
                              : index == 2
                                  ? [const Color(0xFFCD7F32), const Color(0xFF8B4513)]
                                  : [const Color(0xFF3B82F6), const Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Resim
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                        ),
                ),
                const SizedBox(width: 12),
                // Başlık
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$district, $city',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // İstatistikler ve Öne Çıkar butonu
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMiniStat(Icons.visibility, '$views', const Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        _buildMiniStat(Icons.favorite, '$favorites', const Color(0xFFEF4444)),
                        const SizedBox(width: 12),
                        _buildMiniStat(Icons.calendar_today, '$appointments', const Color(0xFF8B5CF6)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _showPromotionModal(propertyId, title),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: const Color(0xFFF59E0B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text(
                        'Öne Çıkar',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Düşük Performanslı İlanlar (Stats verilerinden)
  Widget _buildLowPerformingPropertiesSectionFromStats(List<Map<String, dynamic>> lowPerformingStats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Düşük Performanslı İlanlar',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                  Text(
                    'Bu ilanlar son dönemde az ilgi gördü',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...lowPerformingStats.take(3).map((propStats) {
            final propertyId = propStats['id'] as String? ?? '';
            final images = (propStats['images'] as List?)?.cast<String>() ?? [];
            final title = propStats['title'] as String? ?? '';
            final views = propStats['views'] as int? ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: images.isNotEmpty
                        ? Image.network(
                            images.first,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 40,
                              height: 40,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.home, size: 20, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.home, size: 20, color: Color(0xFF94A3B8)),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Sadece $views görüntülenme',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showPromotionModal(propertyId, title),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text(
                      'Öne Çıkar',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Grafik Alanı (Stats verilerinden)
  Widget _buildViewsGraphSectionFromStats(List<Map<String, dynamic>> propertyStatsList) {
    // Seçili ilan yoksa ilk ilanı seç
    final selectedId = _selectedPropertyForGraph ?? (propertyStatsList.isNotEmpty ? propertyStatsList.first['id'] as String? : null);

    if (propertyStatsList.isEmpty || selectedId == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Grafik için ilan bulunamadı',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final selectedPropStats = propertyStatsList.firstWhere(
      (p) => p['id'] == selectedId,
      orElse: () => propertyStatsList.first,
    );

    final images = (selectedPropStats['images'] as List?)?.cast<String>() ?? [];
    final title = selectedPropStats['title'] as String? ?? '';
    final district = selectedPropStats['district'] as String? ?? '';
    final city = selectedPropStats['city'] as String? ?? '';
    final dailyViews = (selectedPropStats['dailyViews'] as List?)?.cast<int>() ?? List.filled(7, 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İlan Seçici
          Row(
            children: [
              const Text('İlan:', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: propertyStatsList.take(10).map((propStats) {
                      return DropdownMenuItem<String>(
                        value: propStats['id'] as String?,
                        child: Text(
                          propStats['title'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPropertyForGraph = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Seçili İlan Bilgisi
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: images.isNotEmpty
                    ? Image.network(
                        images.first,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$district, $city',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Mini Grafik (Bar Chart)
          const Text(
            'Son 7 Günlük Görüntülenme',
            style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = dailyViews.length > index ? dailyViews[index] : 0;
                final maxValue = dailyViews.isNotEmpty ? dailyViews.reduce((a, b) => a > b ? a : b) : 1;
                final heightPercent = maxValue > 0 ? value / maxValue : 0.0;
                final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 80 * heightPercent,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[index],
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Düşük Performanslı İlanlar (Eski - Property listesi ile)
  Widget _buildLowPerformingPropertiesSection(List<Property> lowPerformingProperties, Map<String, Map<String, int>> propertyStats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Düşük Performanslı İlanlar',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                  Text(
                    'Bu ilanlar son dönemde az ilgi gördü',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...lowPerformingProperties.take(3).map((property) {
            final stats = propertyStats[property.id] ?? {};
            final views = stats['views'] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: property.images.isNotEmpty
                        ? Image.network(
                            property.images.first,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 40,
                              height: 40,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.home, size: 20, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.home, size: 20, color: Color(0xFF94A3B8)),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Sadece $views görüntülenme',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showPromotionModal(property.id, property.title),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text(
                      'Öne Çıkar',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Grafik Alanı
  Widget _buildViewsGraphSection(List<Property> properties) {
    // Seçili ilan yoksa ilk ilanı seç
    final selectedId = _selectedPropertyForGraph ?? (properties.isNotEmpty ? properties.first.id : null);

    if (properties.isEmpty || selectedId == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Grafik için ilan bulunamadı',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final selectedProperty = properties.firstWhere(
      (p) => p.id == selectedId,
      orElse: () => properties.first,
    );

    // Simüle edilmiş haftalık veri
    final weeklyData = List.generate(7, (index) {
      final random = (selectedId.hashCode + index).hashCode;
      return (random.abs() % 50) + 10;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İlan Seçici
          Row(
            children: [
              const Text('İlan:', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: properties.take(10).map((property) {
                      return DropdownMenuItem<String>(
                        value: property.id,
                        child: Text(
                          property.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPropertyForGraph = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Seçili İlan Bilgisi
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: selectedProperty.images.isNotEmpty
                    ? Image.network(
                        selectedProperty.images.first,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedProperty.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${selectedProperty.location.district}, ${selectedProperty.location.city}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Mini Grafik (Bar Chart simülasyonu)
          const Text(
            'Son 7 Günlük Görüntülenme',
            style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = weeklyData[index];
                final maxValue = weeklyData.reduce((a, b) => a > b ? a : b);
                final heightPercent = maxValue > 0 ? value / maxValue : 0.0;
                final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 80 * heightPercent,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[index],
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Aktif Promosyonlar Bölümü
  Widget _buildActivePromotionsSection() {
    final activePromotions = ref.watch(activePromotionsProvider);

    return activePromotions.when(
      data: (promotions) {
        if (promotions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 48,
                  color: const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aktif promosyonunuz bulunmuyor',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'İlanlarınızı öne çıkararak daha fazla görüntülenme alabilirsiniz',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: promotions.map((promo) {
            final propertyTitle = promo['property_title'] as String? ?? 'İlan';
            final promotionType = promo['promotion_type'] as String? ?? 'featured';
            final startDate = promo['start_date'] != null
                ? DateTime.parse(promo['start_date'])
                : DateTime.now();
            final endDate = promo['end_date'] != null
                ? DateTime.parse(promo['end_date'])
                : DateTime.now();
            final now = DateTime.now();
            final remainingDays = endDate.difference(now).inDays;
            final remainingHours = endDate.difference(now).inHours % 24;
            final totalDays = endDate.difference(startDate).inDays;
            final elapsedDays = now.difference(startDate).inDays;
            final progress = totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 1.0) : 0.0;

            final isPremium = promotionType == 'premium';
            final propertyImages = (promo['property_images'] as List?)?.cast<String>() ?? [];
            final viewsBefore = promo['views_before'] as int? ?? 0;
            final viewsDuring = promo['views_during'] as int? ?? 0;
            final viewsIncrease = viewsBefore > 0
                ? ((viewsDuring - viewsBefore) / viewsBefore * 100).toStringAsFixed(0)
                : '0';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPremium
                      ? [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)]
                      : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPremium ? const Color(0xFFFCD34D) : const Color(0xFF7DD3FC),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isPremium ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9)).withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Üst kısım - İlan bilgisi ve tip
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // İlan resmi
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: propertyImages.isNotEmpty
                              ? Image.network(
                                  propertyImages.first,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 64,
                                    height: 64,
                                    color: const Color(0xFFE2E8F0),
                                    child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                                  ),
                                )
                              : Container(
                                  width: 64,
                                  height: 64,
                                  color: const Color(0xFFE2E8F0),
                                  child: const Icon(Icons.home, color: Color(0xFF94A3B8)),
                                ),
                        ),
                        const SizedBox(width: 12),
                        // İlan bilgileri
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isPremium
                                            ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                                            : [const Color(0xFF3B82F6), const Color(0xFF0EA5E9)],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isPremium ? Icons.workspace_premium : Icons.star,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isPremium ? 'Premium' : 'Öne Çıkan',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                propertyTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Kalan süre
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                remainingDays > 0 ? '$remainingDays' : '$remainingHours',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: remainingDays <= 2 ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                remainingDays > 0 ? 'gün kaldı' : 'saat kaldı',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Promosyon süresi',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}% tamamlandı',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isPremium ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // İstatistikler
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPromoStatItem(
                          'Promosyon Öncesi',
                          '$viewsBefore görüntülenme',
                          Icons.visibility_outlined,
                          const Color(0xFF64748B),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE2E8F0),
                        ),
                        _buildPromoStatItem(
                          'Promosyon Süresince',
                          '$viewsDuring görüntülenme',
                          Icons.trending_up,
                          const Color(0xFF10B981),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE2E8F0),
                        ),
                        _buildPromoStatItem(
                          'Artış',
                          '%$viewsIncrease',
                          Icons.arrow_upward,
                          int.parse(viewsIncrease) > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          'Promosyonlar yüklenirken hata: $e',
          style: const TextStyle(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }

  Widget _buildPromoStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  Widget _buildProfileContent() {
    final realtorProfile = ref.watch(realtorProfileProvider);
    final profile = realtorProfile.valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?['company_name'] ?? 'Emlakçı',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?['email'] ?? '',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?['city'] ?? '',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Profile Details
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profil Bilgileri',
                  style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildProfileItem('Telefon', profile?['phone'] ?? '-'),
                _buildProfileItem('Lisans No', profile?['license_number'] ?? '-'),
                _buildProfileItem('Şehir', profile?['city'] ?? '-'),
                _buildProfileItem('Durum', _getStatusText(profile?['status'])),
                if (profile?['description'] != null && profile!['description'].toString().isNotEmpty)
                  _buildProfileItem('Hakkımda', profile['description']),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statistics Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'İstatistikler',
                  style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _buildProfileStatItem(
                    Icons.home_work,
                    '${profile?['total_listings'] ?? 0}',
                    'Toplam İlan',
                    const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Onaylı';
      case 'pending':
        return 'Onay Bekliyor';
      case 'rejected':
        return 'Reddedildi';
      case 'suspended':
        return 'Askıya Alındı';
      default:
        return status ?? '-';
    }
  }

  Widget _buildProfileStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hesap Ayarları
          _buildSettingsSection(
            'Hesap Ayarları',
            [
              _buildSettingsTile(
                Icons.lock_outline,
                'Şifre Değiştir',
                'Hesap şifrenizi değiştirin',
                _showChangePasswordDialog,
              ),
              _buildSettingsTile(
                Icons.email_outlined,
                'E-posta Ayarları',
                'Bildirim e-postalarını yönetin',
                () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Bildirim Ayarları
          _buildSettingsSection(
            'Bildirimler',
            [
              _buildSettingsSwitch(
                Icons.notifications_outlined,
                'Push Bildirimleri',
                'Yeni mesaj ve randevu bildirimleri',
                true,
                (value) {},
              ),
              _buildSettingsSwitch(
                Icons.email_outlined,
                'E-posta Bildirimleri',
                'Haftalık özet ve güncellemeler',
                true,
                (value) {},
              ),
              _buildSettingsSwitch(
                Icons.sms_outlined,
                'SMS Bildirimleri',
                'Önemli bildirimler için SMS',
                false,
                (value) {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Uygulama Ayarları
          _buildSettingsSection(
            'Uygulama',
            [
              _buildSettingsTile(
                Icons.language,
                'Dil',
                'Türkçe',
                () {},
              ),
              _buildSettingsTile(
                Icons.dark_mode_outlined,
                'Tema',
                'Sistem ayarına göre',
                () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Destek
          _buildSettingsSection(
            'Destek',
            [
              _buildSettingsTile(
                Icons.help_outline,
                'Yardım Merkezi',
                'Sık sorulan sorular ve rehberler',
                () {},
              ),
              _buildSettingsTile(
                Icons.chat_outlined,
                'Destek Talebi',
                'Bizimle iletişime geçin',
                () {},
              ),
              _buildSettingsTile(
                Icons.info_outline,
                'Hakkında',
                'Uygulama bilgileri ve sürüm',
                _showAboutDialog,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Çıkış
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              onTap: _handleLogout,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Çıkış Yap',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSwitch(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Şifre Değiştir'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: _dialogInputDecoration('Mevcut Şifre', Icons.lock_outline),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: _dialogInputDecoration('Yeni Şifre', Icons.lock),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: _dialogInputDecoration('Yeni Şifre (Tekrar)', Icons.lock),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Şifreler eşleşmiyor')),
                );
                return;
              }
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Şifre en az 6 karakter olmalıdır')),
                );
                return;
              }
              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(password: newPasswordController.text),
                );
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Şifre başarıyla değiştirildi'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Değiştir'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.real_estate_agent, color: Color(0xFF3B82F6)),
            SizedBox(width: 12),
            Text('Emlakçı Panel'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versiyon: 1.0.0'),
            SizedBox(height: 8),
            Text('Emlakçılar için profesyonel ilan yönetim paneli.'),
            SizedBox(height: 16),
            Text(
              '2024 Tüm hakları saklıdır.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, String buttonText, VoidCallback onPressed) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Color(0xFF64748B), fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== NAVIGATION ====================
  void _openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatListScreen()),
    );
  }

  // ==================== DIALOGS ====================

  /// Randevu detaylarını göster (SuperCyp'ten gelen randevular için)
  void _showAppointmentDetailDialog(Map<String, dynamic> appointment) {
    final property = appointment['properties'] as Map<String, dynamic>?;
    final requester = appointment['requester'] as Map<String, dynamic>?;
    final status = appointment['status'] as String? ?? 'pending';
    final note = appointment['note'] as String?;

    // Tarih ve saat bilgisi
    String dateTimeStr = '-';
    if (appointment['appointment_date'] != null) {
      final date = DateTime.parse(appointment['appointment_date'] as String);
      final time = appointment['appointment_time'] as String?;
      dateTimeStr = '${date.day}.${date.month}.${date.year}';
      if (time != null && time.length >= 5) {
        dateTimeStr += ' ${time.substring(0, 5)}';
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              status == 'pending' ? Icons.pending_actions :
              status == 'confirmed' ? Icons.check_circle :
              status == 'completed' ? Icons.task_alt : Icons.cancel,
              color: _getStatusColor(status),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Randevu Talebi',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Durum
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // İlan Bilgisi
                if (property != null) ...[
                  const Text('İlan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    property['title'] ?? '-',
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (property['city'] != null || property['district'] != null)
                    Text(
                      '${property['district'] ?? ''}, ${property['city'] ?? ''}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  const SizedBox(height: 16),
                ],

                // Müşteri Bilgisi
                if (requester != null) ...[
                  const Text('Müşteri', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        backgroundImage: requester['avatar_url'] != null
                            ? NetworkImage(requester['avatar_url'])
                            : null,
                        child: requester['avatar_url'] == null
                            ? Text(
                                (requester['full_name'] as String?)?.isNotEmpty == true
                                    ? (requester['full_name'] as String)[0].toUpperCase()
                                    : 'M',
                                style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              requester['full_name'] ?? 'Müşteri',
                              style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                            ),
                            if (requester['phone'] != null)
                              Text(
                                requester['phone'],
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Tarih ve Saat
                const Text('Tarih ve Saat', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text(
                      dateTimeStr,
                      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

                // Not
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Müşteri Notu', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      note,
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          // Kapat butonu
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),

          // Beklemede ise onay/iptal butonları
          if (status == 'pending') ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _cancelAppointmentWithConfirm(appointment['id'] as String);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reddet'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _confirmAppointment(appointment['id'] as String);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Onayla'),
            ),
          ],

          // Onaylanmış ise iptal butonu
          if (status == 'confirmed') ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _cancelAppointmentWithConfirm(appointment['id'] as String);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('İptal Et'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _completeAppointment(appointment['id'] as String);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Tamamlandı'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAppointment(String appointmentId) async {
    final service = ref.read(realtorServiceProvider);
    final success = await service.confirmAppointment(appointmentId, null);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu onaylandı'), backgroundColor: Color(0xFF10B981)),
      );
      ref.read(realtorAppointmentsProvider.notifier).loadAppointments();
    }
  }

  Future<void> _cancelAppointmentWithConfirm(String appointmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Randevuyu İptal Et'),
        content: const Text('Bu randevuyu iptal etmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(realtorAppointmentsProvider.notifier);
      await notifier.cancelAppointment(appointmentId, 'Emlakçı tarafından iptal edildi');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Randevu iptal edildi'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _completeAppointment(String appointmentId) async {
    final notifier = ref.read(realtorAppointmentsProvider.notifier);
    await notifier.completeAppointment(appointmentId, null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu tamamlandı olarak işaretlendi'), backgroundColor: Color(0xFF10B981)),
      );
    }
  }

  void _showAddAppointmentDialog([Map<String, dynamic>? existingAppointment]) {
    final titleController = TextEditingController(text: existingAppointment?['title'] ?? '');
    final descriptionController = TextEditingController(text: existingAppointment?['description'] ?? '');
    final locationController = TextEditingController(text: existingAppointment?['location'] ?? '');

    DateTime selectedDate = existingAppointment?['scheduled_at'] != null
        ? DateTime.parse(existingAppointment!['scheduled_at'])
        : DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    String selectedType = existingAppointment?['appointment_type'] ?? 'showing';
    int duration = existingAppointment?['duration_minutes'] ?? 60;

    final isEditing = existingAppointment != null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Randevu Düzenle' : 'Yeni Randevu Ekle'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  TextField(
                    controller: titleController,
                    decoration: _dialogInputDecoration('Randevu Başlığı *', Icons.title),
                  ),

                  const SizedBox(height: 16),

                  // Randevu Türü
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: _dialogInputDecoration('Randevu Türü', Icons.category),
                    items: const [
                      DropdownMenuItem(value: 'showing', child: Text('Ev Gösterimi')),
                      DropdownMenuItem(value: 'meeting', child: Text('Toplantı')),
                      DropdownMenuItem(value: 'phone_call', child: Text('Telefon Görüşmesi')),
                      DropdownMenuItem(value: 'video_call', child: Text('Video Görüşme')),
                      DropdownMenuItem(value: 'signing', child: Text('Sözleşme İmzalama')),
                      DropdownMenuItem(value: 'other', child: Text('Diğer')),
                    ],
                    onChanged: (value) => setDialogState(() => selectedType = value ?? 'showing'),
                  ),

                  const SizedBox(height: 16),

                  // Tarih ve Saat
                  const Text('Tarih ve Saat', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = DateTime(
                                date.year, date.month, date.day,
                                selectedTime.hour, selectedTime.minute,
                              ));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFF64748B), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                                  style: const TextStyle(color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setDialogState(() {
                                selectedTime = time;
                                selectedDate = DateTime(
                                  selectedDate.year, selectedDate.month, selectedDate.day,
                                  time.hour, time.minute,
                                );
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: Color(0xFF64748B), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Süre
                  DropdownButtonFormField<int>(
                    value: duration,
                    decoration: _dialogInputDecoration('Süre', Icons.timer),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 dakika')),
                      DropdownMenuItem(value: 30, child: Text('30 dakika')),
                      DropdownMenuItem(value: 45, child: Text('45 dakika')),
                      DropdownMenuItem(value: 60, child: Text('1 saat')),
                      DropdownMenuItem(value: 90, child: Text('1.5 saat')),
                      DropdownMenuItem(value: 120, child: Text('2 saat')),
                    ],
                    onChanged: (value) => setDialogState(() => duration = value ?? 60),
                  ),

                  const SizedBox(height: 16),

                  // Konum
                  TextField(
                    controller: locationController,
                    decoration: _dialogInputDecoration('Konum / Adres', Icons.location_on),
                  ),

                  const SizedBox(height: 16),

                  // Açıklama
                  TextField(
                    controller: descriptionController,
                    decoration: _dialogInputDecoration('Açıklama / Notlar', Icons.note),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            if (isEditing) ...[
              TextButton(
                onPressed: () async {
                  await ref.read(realtorAppointmentsProvider.notifier).cancelAppointment(
                    existingAppointment['id'],
                    'Kullanıcı tarafından iptal edildi',
                  );
                  if (mounted) Navigator.pop(dialogContext);
                },
                child: const Text('İptal Et', style: TextStyle(color: Colors.red)),
              ),
            ],
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Başlık zorunludur')),
                  );
                  return;
                }

                final scheduledAt = DateTime(
                  selectedDate.year, selectedDate.month, selectedDate.day,
                  selectedTime.hour, selectedTime.minute,
                );

                if (isEditing) {
                  // Randevu güncelleme henüz desteklenmiyor - yeni ekle
                  await ref.read(realtorAppointmentsProvider.notifier).addAppointment(
                    title: titleController.text,
                    scheduledAt: scheduledAt,
                    description: descriptionController.text.isEmpty ? null : descriptionController.text,
                    appointmentType: selectedType,
                    durationMinutes: duration,
                    location: locationController.text.isEmpty ? null : locationController.text,
                  );
                } else {
                  await ref.read(realtorAppointmentsProvider.notifier).addAppointment(
                    title: titleController.text,
                    scheduledAt: scheduledAt,
                    description: descriptionController.text.isEmpty ? null : descriptionController.text,
                    appointmentType: selectedType,
                    durationMinutes: duration,
                    location: locationController.text.isEmpty ? null : locationController.text,
                  );
                }
                if (mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              child: Text(isEditing ? 'Güncelle' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  // ==================== ÖNE ÇIKARMA MODAL ====================

  Future<void> _showPromotionModal(String propertyId, String propertyTitle) async {
    final realtorService = ref.read(realtorServiceProvider);

    // Fiyatları ve mevcut promosyonu yükle
    final prices = await realtorService.getPromotionPrices();
    final activePromotion = await realtorService.getActivePromotion(propertyId);

    if (!mounted) return;

    // Featured ve Premium fiyatlarını ayır
    final featuredPrices = prices.where((p) => p['promotion_type'] == 'featured').toList();
    final premiumPrices = prices.where((p) => p['promotion_type'] == 'premium').toList();

    String selectedType = 'featured';
    int selectedDuration = 7;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Seçilen fiyatı bul
          final selectedPrices = selectedType == 'featured' ? featuredPrices : premiumPrices;
          final selectedPrice = selectedPrices.firstWhere(
            (p) => p['duration_days'] == selectedDuration,
            orElse: () => selectedPrices.isNotEmpty ? selectedPrices.first : {'price': 0},
          );
          final price = (selectedPrice['price'] as num?)?.toDouble() ?? 0;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'İlanı Öne Çıkar',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              propertyTitle,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  // Aktif promosyon varsa uyarı göster
                  if (activePromotion != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF22C55E)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aktif ${activePromotion['promotion_type'] == 'premium' ? 'Premium' : 'Öne Çıkarma'} Promosyonu',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                                ),
                                Text(
                                  'Bitiş: ${_formatDate(activePromotion['expires_at'])}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Promosyon Tipi Seçimi
                  const Text(
                    'Promosyon Tipi',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPromotionTypeCard(
                          title: 'Öne Çıkan',
                          description: 'Ana sayfada carousel\'da gösterilir',
                          icon: Icons.star_rounded,
                          color: const Color(0xFF3B82F6),
                          isSelected: selectedType == 'featured',
                          onTap: () => setDialogState(() => selectedType = 'featured'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPromotionTypeCard(
                          title: 'Premium',
                          description: 'Öne çıkan + altın rozet + üst sıra',
                          icon: Icons.workspace_premium_rounded,
                          color: const Color(0xFFF59E0B),
                          isSelected: selectedType == 'premium',
                          onTap: () => setDialogState(() => selectedType = 'premium'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Süre Seçimi
                  const Text(
                    'Süre',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDurationCard(
                          days: 7,
                          price: selectedPrices.firstWhere((p) => p['duration_days'] == 7, orElse: () => {'price': 0})['price'],
                          isSelected: selectedDuration == 7,
                          onTap: () => setDialogState(() => selectedDuration = 7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDurationCard(
                          days: 30,
                          price: selectedPrices.firstWhere((p) => p['duration_days'] == 30, orElse: () => {'price': 0})['price'],
                          isSelected: selectedDuration == 30,
                          isPopular: true,
                          onTap: () => setDialogState(() => selectedDuration = 30),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Avantajlar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bu Pakette Neler Var?',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        _buildBenefitRow(Icons.visibility, 'Ana sayfada öne çıkan bölümde gösterilir'),
                        if (selectedType == 'premium') ...[
                          _buildBenefitRow(Icons.workspace_premium, 'Altın Premium rozeti'),
                          _buildBenefitRow(Icons.arrow_upward, 'Arama sonuçlarında her zaman üstte'),
                          _buildBenefitRow(Icons.star, 'Detay sayfasında sponsor etiketi'),
                        ],
                        _buildBenefitRow(Icons.trending_up, 'Ortalama %${selectedType == 'premium' ? '300' : '150'} daha fazla görüntülenme'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Toplam ve Ödeme Butonu
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: selectedType == 'premium'
                            ? [const Color(0xFFF59E0B), const Color(0xFFEF4444)]
                            : [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Toplam',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                '₺${price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$selectedDuration gün',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  setDialogState(() => isLoading = true);

                                  final result = await realtorService.createPromotion(
                                    propertyId: propertyId,
                                    promotionType: selectedType,
                                    durationDays: selectedDuration,
                                    amountPaid: price,
                                    paymentMethod: 'demo', // Gerçek ödeme entegrasyonu eklenecek
                                  );

                                  if (!context.mounted) return;

                                  if (result != null) {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text('${selectedType == 'premium' ? 'Premium' : 'Öne Çıkarma'} promosyonu başarıyla aktif edildi!'),
                                        backgroundColor: const Color(0xFF22C55E),
                                      ),
                                    );
                                    // Performans sayfasını yenile
                                    ref.invalidate(propertyPerformanceStatsProvider);
                                  } else {
                                    setDialogState(() => isLoading = false);
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Promosyon oluşturulamadı. Lütfen tekrar deneyin.'),
                                        backgroundColor: Color(0xFFEF4444),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: selectedType == 'premium' ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.flash_on_rounded),
                                    SizedBox(width: 8),
                                    Text('Şimdi Başlat', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromotionTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : const Color(0xFF64748B), size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? color : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard({
    required int days,
    required dynamic price,
    required bool isSelected,
    bool isPopular = false,
    required VoidCallback onTap,
  }) {
    final priceValue = (price as num?)?.toDouble() ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Text(
                  '$days Gün',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₺${priceValue.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                  ),
                ),
                if (days == 30) ...[
                  const SizedBox(height: 4),
                  Text(
                    '₺${(priceValue / 30).toStringAsFixed(2)}/gün',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
            if (isPopular)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Popüler',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF22C55E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
