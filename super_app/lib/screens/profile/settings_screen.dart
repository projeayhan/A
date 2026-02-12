import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/notification_preferences_provider.dart';
import '../../core/providers/privacy_settings_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_dialogs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeletingAccount = false;
  bool _isExportingData = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Ayarlar',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Account Section
            _buildSectionHeader('Hesap', Icons.person_outline, const Color(0xFF3B82F6), isDark),
            _buildSettingsCard(isDark, [
              _buildNavigationItem(
                icon: Icons.person_outline,
                title: 'Kişisel Bilgiler',
                subtitle: 'Ad, soyad, e-posta, telefon',
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                onTap: () => context.push('/settings/personal-info'),
              ),
              _buildNavigationItem(
                icon: Icons.lock_outline,
                title: 'Şifre ve Güvenlik',
                subtitle: 'Şifre değiştir, 2FA ayarları',
                color: const Color(0xFFEF4444),
                isDark: isDark,
                onTap: () => context.push('/settings/security'),
              ),
              _buildNavigationItem(
                icon: Icons.location_on_outlined,
                title: 'Adreslerim',
                subtitle: 'Kayıtlı teslimat adresleri',
                color: const Color(0xFF10B981),
                isDark: isDark,
                onTap: () => context.push('/settings/addresses'),
              ),
              _buildNavigationItem(
                icon: Icons.credit_card_outlined,
                title: 'Ödeme Yöntemlerim',
                subtitle: 'Kartlar ve ödeme seçenekleri',
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                onTap: () => context.push('/settings/payment-methods'),
              ),
              _buildNavigationItem(
                icon: Icons.emergency_outlined,
                title: 'Acil Durum Kişileri',
                subtitle: 'SOS mesajı gönderilecek kişiler',
                color: const Color(0xFFEF4444),
                isDark: isDark,
                onTap: () => context.push('/settings/emergency-contacts'),
              ),
            ]),

            const SizedBox(height: 24),

            // Notifications Section
            _buildSectionHeader('Bildirimler', Icons.notifications_outlined, const Color(0xFFF59E0B), isDark),
            Consumer(
              builder: (context, ref, _) {
                final notifPrefs = ref.watch(notificationPreferencesProvider);
                final notifNotifier = ref.read(notificationPreferencesProvider.notifier);
                return _buildSettingsCard(isDark, [
                  _buildSwitchItem(
                    icon: Icons.notifications_active_outlined,
                    title: 'Push Bildirimleri',
                    subtitle: 'Anlık bildirimler al',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    value: notifPrefs.pushEnabled,
                    onChanged: (v) => notifNotifier.setPushEnabled(v),
                  ),
                  _buildSwitchItem(
                    icon: Icons.email_outlined,
                    title: 'E-posta Bildirimleri',
                    subtitle: 'Güncellemeleri e-posta ile al',
                    color: const Color(0xFF6366F1),
                    isDark: isDark,
                    value: notifPrefs.emailEnabled,
                    onChanged: (v) => notifNotifier.setEmailEnabled(v),
                  ),
                  _buildSwitchItem(
                    icon: Icons.sms_outlined,
                    title: 'SMS Bildirimleri',
                    subtitle: 'Önemli uyarıları SMS ile al',
                    color: const Color(0xFF14B8A6),
                    isDark: isDark,
                    value: notifPrefs.smsEnabled,
                    onChanged: (v) => notifNotifier.setSmsEnabled(v),
                  ),
                  _buildDivider(isDark),
                  _buildSwitchItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Sipariş Güncellemeleri',
                    subtitle: 'Sipariş durumu değişiklikleri',
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                    value: notifPrefs.orderUpdates,
                    onChanged: (v) => notifNotifier.setOrderUpdates(v),
                  ),
                  _buildSwitchItem(
                    icon: Icons.campaign_outlined,
                    title: 'Kampanyalar',
                    subtitle: 'Özel fırsatlardan haberdar ol',
                    color: const Color(0xFFEC4899),
                    isDark: isDark,
                    value: notifPrefs.campaigns,
                    onChanged: (v) => notifNotifier.setCampaigns(v),
                  ),
                  _buildSwitchItem(
                    icon: Icons.new_releases_outlined,
                    title: 'Yeni Özellikler',
                    subtitle: 'Uygulama yeniliklerini öğren',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    value: notifPrefs.newFeatures,
                    onChanged: (v) => notifNotifier.setNewFeatures(v),
                  ),
                ]);
              },
            ),

            const SizedBox(height: 24),

            // Privacy Section
            _buildSectionHeader('Gizlilik', Icons.shield_outlined, const Color(0xFF10B981), isDark),
            _buildSettingsCard(isDark, [
              _buildSwitchItem(
                icon: Icons.location_on_outlined,
                title: 'Konum Servisleri',
                subtitle: 'Yakındaki işletmeleri bul',
                color: const Color(0xFF10B981),
                isDark: isDark,
                value: ref.watch(privacySettingsProvider).locationServices,
                onChanged: (v) => ref.read(privacySettingsProvider.notifier).setLocationServices(v),
              ),
              _buildSwitchItem(
                icon: Icons.analytics_outlined,
                title: 'Analitik Veriler',
                subtitle: 'Uygulama iyileştirmelerine katkı',
                color: const Color(0xFF6366F1),
                isDark: isDark,
                value: ref.watch(privacySettingsProvider).analytics,
                onChanged: (v) => ref.read(privacySettingsProvider.notifier).setAnalytics(v),
              ),
              _buildSwitchItem(
                icon: Icons.ads_click_outlined,
                title: 'Kişiselleştirilmiş Reklamlar',
                subtitle: 'İlgi alanlarına göre reklamlar',
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                value: ref.watch(privacySettingsProvider).personalizedAds,
                onChanged: (v) => ref.read(privacySettingsProvider.notifier).setPersonalizedAds(v),
              ),
              _buildDivider(isDark),
              _buildNavigationItem(
                icon: Icons.history,
                title: 'Veri İndirme',
                subtitle: 'Verilerinin bir kopyasını al',
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                onTap: () => _showDataDownloadDialog(),
              ),
              _buildNavigationItem(
                icon: Icons.delete_outline,
                title: 'Hesabı Sil',
                subtitle: 'Hesabını kalıcı olarak kaldır',
                color: const Color(0xFFEF4444),
                isDark: isDark,
                onTap: () => _showDeleteAccountDialog(),
              ),
            ]),

            const SizedBox(height: 24),

            // App Preferences Section
            _buildSectionHeader('Uygulama Tercihleri', Icons.tune_outlined, const Color(0xFF8B5CF6), isDark),
            _buildSettingsCard(isDark, [
              _buildSwitchItem(
                icon: Icons.dark_mode_outlined,
                title: 'Karanlık Mod',
                subtitle: 'Göz yorgunluğunu azalt',
                color: const Color(0xFF6366F1),
                isDark: isDark,
                value: ref.watch(settingsProvider).themeMode == ThemeMode.dark,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setThemeMode(
                    v ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
              _buildSwitchItem(
                icon: Icons.fingerprint,
                title: 'Biyometrik Giriş',
                subtitle: 'Parmak izi veya yüz tanıma',
                color: const Color(0xFF10B981),
                isDark: isDark,
                value: ref.watch(settingsProvider).biometricLogin,
                onChanged: (v) => _toggleBiometric(v),
              ),
              _buildSwitchItem(
                icon: Icons.system_update_outlined,
                title: 'Otomatik Güncelleme',
                subtitle: 'Uygulamayı otomatik güncelle',
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                value: ref.watch(settingsProvider).autoUpdate,
                onChanged: (v) => ref.read(settingsProvider.notifier).setAutoUpdate(v),
              ),
              _buildDivider(isDark),
              _buildSelectionItem(
                icon: Icons.language_outlined,
                title: 'Dil',
                value: getLanguageName(ref.watch(settingsProvider).locale),
                color: const Color(0xFF06B6D4),
                isDark: isDark,
                onTap: () => _showLanguageSelector(),
              ),
            ]),

            const SizedBox(height: 24),

            // Support Section
            _buildSectionHeader('Destek ve Bilgi', Icons.help_outline, const Color(0xFFEC4899), isDark),
            _buildSettingsCard(isDark, [
              _buildNavigationItem(
                icon: Icons.help_center_outlined,
                title: 'Yardım Merkezi',
                subtitle: 'Sıkça sorulan sorular',
                color: const Color(0xFFEC4899),
                isDark: isDark,
                onTap: () => context.push('/help-center'),
              ),
              _buildNavigationItem(
                icon: Icons.chat_bubble_outline,
                title: 'Canlı Destek',
                subtitle: '7/24 müşteri hizmetleri',
                color: const Color(0xFF14B8A6),
                isDark: isDark,
                onTap: () => _showLiveChatDialog(),
              ),
              _buildNavigationItem(
                icon: Icons.bug_report_outlined,
                title: 'Hata Bildir',
                subtitle: 'Sorunları bize iletin',
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                onTap: () => _showBugReportDialog(),
              ),
              _buildDivider(isDark),
              _buildNavigationItem(
                icon: Icons.description_outlined,
                title: 'Kullanım Koşulları',
                subtitle: 'Hizmet şartları',
                color: const Color(0xFF64748B),
                isDark: isDark,
                onTap: () => _openUrl('https://supercyp.com/terms'),
              ),
              _buildNavigationItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Gizlilik Politikası',
                subtitle: 'Veri koruma politikamız',
                color: const Color(0xFF64748B),
                isDark: isDark,
                onTap: () => _openUrl('https://supercyp.com/privacy'),
              ),
              _buildNavigationItem(
                icon: Icons.info_outline,
                title: 'Hakkında',
                subtitle: 'Versiyon 1.0.0+1',
                color: const Color(0xFF64748B),
                isDark: isDark,
                onTap: () => _showAboutDialog(),
              ),
            ]),

            const SizedBox(height: 24),

            // Logout Button
            _buildLogoutButton(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary,
              activeThumbColor: Colors.white,
              inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
              inactiveThumbColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 72,
      color: isDark ? Colors.grey[800] : Colors.grey[100],
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => _showLogoutDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
          ),
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

  // Biometric toggle
  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        if (!mounted) return;
        await AppDialogs.showWarning(context, 'Bu cihaz biyometrik kimlik doğrulamayı desteklemiyor.');
        return;
      }
      try {
        final authenticated = await auth.authenticate(
          localizedReason: 'Biyometrik girişi etkinleştirmek için doğrulama yapın',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!authenticated) return;
      } catch (e) {
        if (!mounted) return;
        await AppDialogs.showWarning(context, 'Biyometrik doğrulama başarısız: $e');
        return;
      }
    }
    ref.read(settingsProvider.notifier).setBiometricLogin(enable);
  }

  // Dialog methods
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
                leading: Radio<String>(
                  value: locale.languageCode,
                  groupValue: currentLocale.languageCode,
                  onChanged: (v) {
                    ref.read(settingsProvider.notifier).setLocale(locale);
                    Navigator.pop(context);
                  },
                  activeColor: AppColors.primary,
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Çıkış Yap'),
          ],
        ),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Hesabı Sil'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu işlem geri alınamaz!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 12),
            Text('Hesabınızı sildiğinizde:'),
            SizedBox(height: 8),
            Text('• Tüm verileriniz silinecek'),
            Text('• Sipariş geçmişiniz kaybolacak'),
            Text('• Kazanılan puanlar geçersiz olacak'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Vazgeç', style: TextStyle(color: Colors.grey[600])),
          ),
          StatefulBuilder(
            builder: (context, setDialogState) {
              return ElevatedButton(
                onPressed: _isDeletingAccount ? null : () async {
                  setDialogState(() => _isDeletingAccount = true);
                  setState(() {});
                  try {
                    await SupabaseService.client.rpc('delete_user_account');
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    await ref.read(authProvider.notifier).signOut();
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    await AppDialogs.showWarning(context, 'Hesap silinemedi: $e');
                  } finally {
                    _isDeletingAccount = false;
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isDeletingAccount
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Hesabı Sil', style: TextStyle(color: Colors.white)),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDataDownloadDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.download, color: Color(0xFF3B82F6)),
            SizedBox(width: 12),
            Text('Veri İndirme'),
          ],
        ),
        content: const Text(
          'Hesabınıza ait tüm verileriniz JSON formatında dışa aktarılacak ve paylaşabileceksiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('İptal', style: TextStyle(color: Colors.grey[600])),
          ),
          StatefulBuilder(
            builder: (context, setDialogState) {
              return ElevatedButton(
                onPressed: _isExportingData ? null : () async {
                  setDialogState(() => _isExportingData = true);
                  setState(() {});
                  try {
                    final data = await SupabaseService.client.rpc('export_user_data');
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
                    await SharePlus.instance.share(
                      ShareParams(text: jsonStr, subject: 'SuperCyp - Verilerim'),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    await AppDialogs.showWarning(context, 'Veri dışa aktarılamadı: $e');
                  } finally {
                    _isExportingData = false;
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isExportingData
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Dışa Aktar', style: TextStyle(color: Colors.white)),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showLiveChatDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Color(0xFF14B8A6)),
            SizedBox(width: 12),
            Text('Canlı Destek'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI asistanımız size 7/24 yardımcı olabilir.'),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text('Anında yanıt alın'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Vazgeç', style: TextStyle(color: Colors.grey[600])),
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
            child: const Text('Sohbet Başlat', style: TextStyle(color: Colors.white)),
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
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Color(0xFFF59E0B)),
              SizedBox(width: 12),
              Text('Hata Bildir'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Karşılaştığınız sorunu detaylı bir şekilde açıklayın.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Sorunu açıklayın...',
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
              child: Text('İptal', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isSending ? null : () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  await AppDialogs.showWarning(dialogContext, 'Lütfen sorunu açıklayın.');
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
                  await AppDialogs.showSuccess(this.context, 'Hata raporu gönderildi. Teşekkür ederiz!');
                } catch (e) {
                  setDialogState(() => isSending = false);
                  if (!mounted) return;
                  await AppDialogs.showWarning(dialogContext, 'Gönderilemedi: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gönder', style: TextStyle(color: Colors.white)),
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
            const Text(
              'SuperCyp',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Versiyon 1.0.0+1',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tüm ihtiyaçlarınız için tek uygulama.\nYemek, market, kurye, taksi ve daha fazlası.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2025 SuperCyp. Tüm hakları saklıdır.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _openUrl('https://supercyp.com/terms'),
                  icon: Icon(Icons.description_outlined, size: 16, color: Colors.grey[500]),
                  label: Text('Koşullar', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ),
                Text('·', style: TextStyle(color: Colors.grey[400])),
                TextButton.icon(
                  onPressed: () => _openUrl('https://supercyp.com/privacy'),
                  icon: Icon(Icons.privacy_tip_outlined, size: 16, color: Colors.grey[500]),
                  label: Text('Gizlilik', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
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
      await AppDialogs.showWarning(context, 'Bağlantı açılamadı.');
    }
  }
}
