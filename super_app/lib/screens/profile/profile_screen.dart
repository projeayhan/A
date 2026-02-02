import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/user_provider.dart' as up;
import '../../core/providers/notification_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/profile_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profileAsync = ref.watch(userProfileProvider);
    final userProfileState = ref.watch(
      up.userProfileProvider,
    ); // Real, mutable profile state
    final profileData =
        userProfileState ?? profileAsync.valueOrNull; // Prefer mutable state
    final statsAsync = ref.watch(profileStatsProvider);
    final addressesAsync = ref.watch(userAddressesProvider);
    final cardsAsync = ref.watch(userPaymentMethodsProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Custom Header with Profile Info
              _buildProfileHeader(isDark, user, profileData),

              // Stats Cards
              _buildStatsSection(isDark, profileData, statsAsync.valueOrNull),

              // Menu Sections
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Account Section
                    _buildSectionTitle('Hesap', isDark),
                    _buildMenuCard(isDark, [
                      _buildMenuItemData(
                        icon: Icons.person_outline,
                        title: 'Kişisel Bilgiler',
                        subtitle: 'Ad, soyad, telefon',
                        color: const Color(0xFF3B82F6),
                        onTap: () => context.push('/settings/personal-info'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.location_on_outlined,
                        title: 'Adreslerim',
                        subtitle:
                            '${statsAsync.valueOrNull?['addressCount'] ?? addressesAsync.valueOrNull?.length ?? 0} kayıtlı adres',
                        color: const Color(0xFF10B981),
                        onTap: () => context.push('/settings/addresses'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.credit_card_outlined,
                        title: 'Ödeme Yöntemlerim',
                        subtitle:
                            '${statsAsync.valueOrNull?['cardCount'] ?? cardsAsync.valueOrNull?.length ?? 0} kayıtlı kart',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.push('/settings/payment-methods'),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Preferences Section
                    _buildSectionTitle('Tercihler', isDark),
                    _buildMenuCard(isDark, [
                      _buildMenuItemWithBadge(
                        icon: Icons.notifications_outlined,
                        title: 'Bildirimler',
                        color: const Color(0xFFF59E0B),
                        badgeCount: ref.watch(unreadNotificationCountProvider),
                        onTap: () => context.push('/notifications'),
                        isDark: isDark,
                      ),
                      _buildToggleItemData(
                        icon: Icons.dark_mode_outlined,
                        title: 'Karanlık Mod',
                        subtitle: 'Tema tercihi',
                        color: const Color(0xFF6366F1),
                        value: ref.watch(settingsProvider).themeMode == ThemeMode.dark,
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      ),
                      _buildMenuItemData(
                        icon: Icons.language_outlined,
                        title: 'Dil',
                        subtitle: getLanguageName(ref.watch(settingsProvider).locale),
                        color: const Color(0xFF06B6D4),
                        onTap: () => _showLanguageSelector(),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Support Section
                    _buildSectionTitle('Destek', isDark),
                    _buildMenuCard(isDark, [
                      _buildMenuItemData(
                        icon: Icons.help_outline,
                        title: 'Yardım Merkezi',
                        subtitle: 'SSS ve destek',
                        color: const Color(0xFFEC4899),
                        onTap: () {},
                      ),
                      _buildMenuItemData(
                        icon: Icons.chat_bubble_outline,
                        title: 'Canlı Destek',
                        subtitle: '7/24 AI destekli yardım',
                        color: const Color(0xFF14B8A6),
                        onTap: () => context.push('/support/ai-chat'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.info_outline,
                        title: 'Hakkında',
                        subtitle: 'Versiyon 1.0.0',
                        color: const Color(0xFF64748B),
                        onTap: () {},
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Logout Button
                    _buildLogoutButton(ref),

                    SizedBox(height: context.bottomNavPadding),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark, dynamic user, UserProfile? profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          // Avatar with gradient border
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(37),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.8),
                        const Color(0xFF60A5FA),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(35),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName.isNotEmpty == true
                      ? profile!.fullName
                      : (user?.userMetadata?['full_name'] ?? 'Kullanıcı'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.email ?? user?.email ?? 'email@example.com',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                // Membership Badge
                _buildMembershipBadge(profile?.membershipType ?? 'standard'),
              ],
            ),
          ),
          // Settings Button
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                ),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipBadge(String membershipType) {
    Color startColor;
    Color endColor;
    String label;

    switch (membershipType.toLowerCase()) {
      case 'gold':
        startColor = const Color(0xFFF59E0B);
        endColor = const Color(0xFFFBBF24);
        label = 'Gold Üye';
        break;
      case 'platinum':
        startColor = const Color(0xFF6366F1);
        endColor = const Color(0xFF8B5CF6);
        label = 'Platinum Üye';
        break;
      case 'premium':
        startColor = const Color(0xFFEC4899);
        endColor = const Color(0xFFF472B6);
        label = 'Premium Üye';
        break;
      default:
        startColor = const Color(0xFF64748B);
        endColor = const Color(0xFF94A3B8);
        label = 'Standart Üye';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    bool isDark,
    UserProfile? profile,
    Map<String, dynamic>? stats,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.shopping_bag_outlined,
            value: '${stats?['orderCount'] ?? profile?.totalOrders ?? 0}',
            label: 'Sipariş',
            color: const Color(0xFF3B82F6),
            isDark: isDark,
          ),
          _buildStatDivider(isDark),
          _buildStatItem(
            icon: Icons.favorite_outline,
            value: '${profile?.totalFavorites ?? 0}',
            label: 'Favori',
            color: const Color(0xFFEC4899),
            isDark: isDark,
          ),
          _buildStatDivider(isDark),
          _buildStatItem(
            icon: Icons.star_outline,
            value: profile?.averageRating.toStringAsFixed(1) ?? '0.0',
            label: 'Puan',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          _buildStatDivider(isDark),
          _buildStatItem(
            icon: Icons.card_giftcard_outlined,
            value: '${stats?['couponCount'] ?? 0}',
            label: 'Kupon',
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 50,
      color: isDark ? Colors.grey[700] : Colors.grey[200],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildMenuCard(bool isDark, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              item,
              if (index < items.length - 1)
                Divider(
                  height: 1,
                  indent: 68,
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItemData({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
    );
  }

  Widget _buildMenuItemWithBadge({
    required IconData icon,
    required String title,
    required Color color,
    required int badgeCount,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
      ),
      subtitle: Text(
        badgeCount > 0 ? '$badgeCount okunmamış bildirim' : 'Tüm bildirimler okundu',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildToggleItemData({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
        activeThumbColor: Colors.white,
      ),
    );
  }

  void _showLanguageSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLocale = ref.read(settingsProvider).locale;

    final languages = [
      {'name': 'Türkçe', 'locale': const Locale('tr', 'TR')},
      {'name': 'English', 'locale': const Locale('en', 'US')},
      {'name': 'Deutsch', 'locale': const Locale('de', 'DE')},
      {'name': 'Français', 'locale': const Locale('fr', 'FR')},
      {'name': 'Español', 'locale': const Locale('es', 'ES')},
      {'name': 'العربية', 'locale': const Locale('ar', 'SA')},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Dil Seçin',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            ...languages.map((lang) {
              final locale = lang['locale'] as Locale;
              final name = lang['name'] as String;
              final isSelected = currentLocale.languageCode == locale.languageCode;

              return ListTile(
                onTap: () {
                  ref.read(settingsProvider.notifier).setLocale(locale);
                  Navigator.pop(context);
                },
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.logout, color: Colors.red),
                SizedBox(width: 12),
                Text('Çıkış Yap'),
              ],
            ),
            content: const Text(
              'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İptal', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref.read(authProvider.notifier).signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Çıkış Yap',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.red, size: 20),
            SizedBox(width: 10),
            Text(
              'Çıkış Yap',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
