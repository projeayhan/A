import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/user_provider.dart' as up;
import '../../core/providers/notification_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_dialogs.dart';
import '../../l10n/app_localizations.dart';

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
    final profileAsync = ref.watch(profileDataProvider);
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

              // Menu Sections
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Account Section
                    _buildSectionTitle(S.of(context)!.account, isDark),
                    _buildMenuCard(isDark, [
                      _buildMenuItemData(
                        icon: Icons.person_outline,
                        title: S.of(context)!.personalInfo,
                        subtitle: S.of(context)!.personalInfoSubtitle,
                        color: const Color(0xFF3B82F6),
                        onTap: () => context.push('/settings/personal-info'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.location_on_outlined,
                        title: S.of(context)!.myAddresses,
                        subtitle:
                            S.of(context)!.registeredAddressCount(statsAsync.valueOrNull?['addressCount'] ?? addressesAsync.valueOrNull?.length ?? 0),
                        color: const Color(0xFF10B981),
                        onTap: () => context.push('/settings/addresses'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.credit_card_outlined,
                        title: S.of(context)!.myPaymentMethods,
                        subtitle:
                            S.of(context)!.registeredCardCount(statsAsync.valueOrNull?['cardCount'] ?? cardsAsync.valueOrNull?.length ?? 0),
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.push('/settings/payment-methods'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.emergency_outlined,
                        title: S.of(context)!.emergencyContacts,
                        subtitle: S.of(context)!.emergencyContactsSubtitle,
                        color: const Color(0xFFEF4444),
                        onTap: () => context.push('/settings/emergency-contacts'),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Preferences Section
                    _buildSectionTitle(S.of(context)!.preferences, isDark),
                    _buildMenuCard(isDark, [
                      _buildMenuItemWithBadge(
                        icon: Icons.notifications_outlined,
                        title: S.of(context)!.notifications,
                        color: const Color(0xFFF59E0B),
                        badgeCount: ref.watch(unreadNotificationCountProvider),
                        onTap: () => context.push('/notifications'),
                        isDark: isDark,
                      ),
                      _buildToggleItemData(
                        icon: Icons.dark_mode_outlined,
                        title: S.of(context)!.darkMode,
                        subtitle: S.of(context)!.themePreference,
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
                        title: S.of(context)!.language,
                        subtitle: getLanguageName(ref.watch(settingsProvider).locale),
                        color: const Color(0xFF06B6D4),
                        onTap: () => _showLanguageSelector(),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Support Section
                    _buildSectionTitle(S.of(context)!.supportAndInfo, isDark),
                    _buildMenuCard(isDark, [
                      _buildMenuItemData(
                        icon: Icons.help_center_outlined,
                        title: S.of(context)!.helpCenter,
                        subtitle: S.of(context)!.helpCenterSubtitle,
                        color: const Color(0xFFEC4899),
                        onTap: () => context.push('/help-center'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.chat_bubble_outline,
                        title: S.of(context)!.liveSupport,
                        subtitle: S.of(context)!.liveSupportSubtitle,
                        color: const Color(0xFF14B8A6),
                        onTap: () => _showLiveChatDialog(),
                      ),
                      _buildMenuItemData(
                        icon: Icons.bug_report_outlined,
                        title: S.of(context)!.reportBug,
                        subtitle: S.of(context)!.reportBugSubtitle,
                        color: const Color(0xFFF59E0B),
                        onTap: () => _showBugReportDialog(),
                      ),
                      _buildMenuItemData(
                        icon: Icons.description_outlined,
                        title: S.of(context)!.termsOfService,
                        subtitle: S.of(context)!.termsOfServiceSubtitle,
                        color: const Color(0xFF64748B),
                        onTap: () => _openUrl('https://supercyp.com/terms'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.privacy_tip_outlined,
                        title: S.of(context)!.privacyPolicy,
                        subtitle: S.of(context)!.privacyPolicySubtitle,
                        color: const Color(0xFF64748B),
                        onTap: () => _openUrl('https://supercyp.com/privacy'),
                      ),
                      _buildMenuItemData(
                        icon: Icons.info_outline,
                        title: S.of(context)!.about,
                        subtitle: S.of(context)!.versionInfo('1.0.0+1'),
                        color: const Color(0xFF64748B),
                        onTap: () => _showAboutDialog(),
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
                      : (user?.userMetadata?['full_name'] ?? S.of(context)!.userFallback),
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
        label = S.of(context)!.goldMember;
        break;
      case 'platinum':
        startColor = const Color(0xFF6366F1);
        endColor = const Color(0xFF8B5CF6);
        label = S.of(context)!.platinumMember;
        break;
      case 'premium':
        startColor = const Color(0xFFEC4899);
        endColor = const Color(0xFFF472B6);
        label = S.of(context)!.premiumMember;
        break;
      default:
        startColor = const Color(0xFF64748B);
        endColor = const Color(0xFF94A3B8);
        label = S.of(context)!.standardMember;
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
        badgeCount > 0 ? S.of(context)!.unreadNotifications : S.of(context)!.allNotificationsRead,
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
              S.of(context)!.selectLanguage,
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
            title: Row(
              children: [
                const Icon(Icons.logout, color: Colors.red),
                const SizedBox(width: 12),
                Text(S.of(context)!.signOut),
              ],
            ),
            content: Text(
              S.of(context)!.signOutConfirm,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context)!.cancel, style: TextStyle(color: Colors.grey[600])),
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
                child: Text(
                  S.of(context)!.signOut,
                  style: const TextStyle(color: Colors.white),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Text(
              S.of(context)!.signOut,
              style: const TextStyle(
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

  void _showLiveChatDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.support_agent, color: Color(0xFF14B8A6)),
            const SizedBox(width: 12),
            Text(S.of(context)!.liveSupport),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.of(context)!.liveSupportDialogMessage),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.smart_toy_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(S.of(context)!.getInstantAnswers),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(context)!.cancel, style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/support/ai-chat');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(S.of(context)!.startChat, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog() {
    final controller = TextEditingController();
    bool isSending = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.bug_report, color: Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              Text(S.of(context)!.reportBug),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.of(context)!.reportBugDialogMessage),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: S.of(context)!.describeProblem,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(S.of(context)!.cancel, style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isSending ? null : () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  await AppDialogs.showWarning(dialogContext, S.of(context)!.pleaseDescribeProblem);
                  return;
                }
                setDialogState(() => isSending = true);
                try {
                  await SupabaseService.client.from('bug_reports').insert({
                    'user_id': SupabaseService.currentUser!.id,
                    'description': text,
                  });
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  await AppDialogs.showSuccess(this.context, S.of(this.context)!.bugReportSent);
                } catch (e) {
                  setDialogState(() => isSending = false);
                  if (!mounted) return;
                  await AppDialogs.showWarning(dialogContext, '${S.of(context)!.couldNotSend} $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(S.of(context)!.send, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.apps, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.appName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              S.of(context)!.versionInfo('1.0.0+1'),
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.allNeedsInOneApp,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.copyright,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _openUrl('https://supercyp.com/terms'),
                  icon: Icon(Icons.description_outlined, size: 16, color: Colors.grey[500]),
                  label: Text(S.of(context)!.terms, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ),
                Text('·', style: TextStyle(color: Colors.grey[400])),
                TextButton.icon(
                  onPressed: () => _openUrl('https://supercyp.com/privacy'),
                  icon: Icon(Icons.privacy_tip_outlined, size: 16, color: Colors.grey[500]),
                  label: Text(S.of(context)!.privacy, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context)!.ok),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      // TODO: localize this string
      await AppDialogs.showWarning(context, 'Bağlantı açılamadı.');
    }
  }
}
