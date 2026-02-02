import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _packageInfo = packageInfo);
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hakkında'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // App Logo & Info
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.delivery_dining,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Kurye App',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Profesyonel Kurye Platformu',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'v${_packageInfo?.version ?? '1.0.0'} (${_packageInfo?.buildNumber ?? '1'})',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Features
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildFeatureItem(
                    icon: Icons.flash_on,
                    title: 'Hızlı Sipariş Yönetimi',
                    subtitle: 'Siparişleri anında görün ve kabul edin',
                    color: AppColors.warning,
                  ),
                  const Divider(height: 1),
                  _buildFeatureItem(
                    icon: Icons.map_outlined,
                    title: 'Akıllı Navigasyon',
                    subtitle: 'En kısa rotaları otomatik hesaplayın',
                    color: AppColors.info,
                  ),
                  const Divider(height: 1),
                  _buildFeatureItem(
                    icon: Icons.account_balance_wallet,
                    title: 'Kolay Kazanç Takibi',
                    subtitle: 'Günlük, haftalık ve aylık kazançlarınız',
                    color: AppColors.success,
                  ),
                  const Divider(height: 1),
                  _buildFeatureItem(
                    icon: Icons.notifications_active,
                    title: 'Anlık Bildirimler',
                    subtitle: 'Yeni siparişleri kaçırmayın',
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Legal Links
            Text(
              'Yasal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildLinkItem(
                    title: 'Kullanım Koşulları',
                    onTap: () => _launchUrl('https://example.com/terms'),
                  ),
                  const Divider(height: 1),
                  _buildLinkItem(
                    title: 'Gizlilik Politikası',
                    onTap: () => _launchUrl('https://example.com/privacy'),
                  ),
                  const Divider(height: 1),
                  _buildLinkItem(
                    title: 'KVKK Aydınlatma Metni',
                    onTap: () => _launchUrl('https://example.com/kvkk'),
                  ),
                  const Divider(height: 1),
                  _buildLinkItem(
                    title: 'Açık Kaynak Lisansları',
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Kurye App',
                        applicationVersion: _packageInfo?.version ?? '1.0.0',
                        applicationIcon: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Social Links
            Text(
              'Bizi Takip Edin',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(
                  icon: Icons.language,
                  label: 'Web',
                  onTap: () => _launchUrl('https://example.com'),
                ),
                const SizedBox(width: 16),
                _buildSocialButton(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  onTap: () => _launchUrl('https://facebook.com'),
                ),
                const SizedBox(width: 16),
                _buildSocialButton(
                  icon: Icons.camera_alt,
                  label: 'Instagram',
                  onTap: () => _launchUrl('https://instagram.com'),
                ),
                const SizedBox(width: 16),
                _buildSocialButton(
                  icon: Icons.alternate_email,
                  label: 'Twitter',
                  onTap: () => _launchUrl('https://twitter.com'),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Copyright
            Text(
              '© 2024 Kurye App. Tüm hakları saklıdır.',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Made with ♥ in Turkey',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
