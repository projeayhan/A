import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yardim & Destek'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Quick actions
            _buildSection(
              context,
              title: 'Hizli Islemler',
              icon: Icons.flash_on,
              iconColor: AppColors.warning,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildQuickAction(
                        context,
                        icon: Icons.bug_report_outlined,
                        label: 'Sorun Bildir',
                        color: AppColors.error,
                        onTap: () => _showReportDialog(context, 'Sorun Bildir'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        context,
                        icon: Icons.lightbulb_outline,
                        label: 'Oneri Gonder',
                        color: AppColors.warning,
                        onTap: () => _showReportDialog(context, 'Oneri Gonder'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        context,
                        icon: Icons.phone_outlined,
                        label: 'Bizi Arayin',
                        color: AppColors.success,
                        onTap: () => _launch('tel:08501234567'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Contact options
            _buildSection(
              context,
              title: 'Iletisim',
              icon: Icons.contact_support_outlined,
              iconColor: AppColors.info,
              child: Column(
                children: [
                  _buildContactTile(
                    icon: Icons.phone_outlined,
                    title: 'Telefon',
                    subtitle: '0850 123 45 67',
                    onTap: () => _launch('tel:08501234567'),
                  ),
                  const Divider(height: 1),
                  _buildContactTile(
                    icon: Icons.email_outlined,
                    title: 'E-posta',
                    subtitle: 'destek@supercyp.com',
                    onTap: () => _launch('mailto:destek@supercyp.com'),
                  ),
                  const Divider(height: 1),
                  _buildContactTile(
                    icon: Icons.chat_outlined,
                    title: 'WhatsApp',
                    subtitle: 'Canli Destek',
                    onTap: () => _launch('https://wa.me/905001234567'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FAQ
            _buildSection(
              context,
              title: 'Sikca Sorulan Sorular',
              icon: Icons.help_outline,
              iconColor: AppColors.secondary,
              child: Column(
                children: [
                  _buildFaq(
                    'Kazanclarimi nasil cekim yapabilirim?',
                    'Kazanclariniz her hafta Pazartesi gunu otomatik olarak tanimladiginiz banka hesabina aktarilir. '
                        'Profil > Odeme Bilgileri bolumunden banka hesap bilgilerinizi tanimlayabilirsiniz.',
                  ),
                  _buildFaq(
                    'Komisyon orani nedir?',
                    'Platform komisyon orani %20\'dir. Her tamamlanan yolculuktan bu oran dusulerek kalan tutar '
                        'net kazanciniz olarak hesabiniza aktarilir.',
                  ),
                  _buildFaq(
                    'Arac bilgilerimi nasil guncellerim?',
                    'Profil > Arac Bilgileri bolumune giderek arac markanizi, modelinizi, plakanizi ve '
                        'diger bilgileri guncelleyebilirsiniz.',
                  ),
                  _buildFaq(
                    'Musteriden kotu degerlendirme aldim, ne yapabilirim?',
                    'Haksiz degerlendirmeler icin destek ekibiyle iletisime gecebilirsiniz. '
                        'Ayrica Degerlendirmelerim bolumunden yorumlara yanit verebilirsiniz.',
                  ),
                  _buildFaq(
                    'SOS butonu nasil calisir?',
                    'Acil durumlarda SOS butonuna bastiginizda, onceden tanimladiginiz acil durum kisilerine '
                        'WhatsApp uzerinden konumunuz ve yolculuk bilgileriniz ile mesaj gonderilir.',
                  ),
                  _buildFaq(
                    'Hesabimi nasil silebilirim?',
                    'Hesap silme islemi icin destek ekibimizle iletisime gecmeniz gerekmektedir. '
                        'E-posta veya telefon ile bize ulasabilirsiniz.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App info
            _buildSection(
              context,
              title: 'Uygulama Bilgileri',
              icon: Icons.info_outline,
              iconColor: AppColors.textSecondary,
              child: Column(
                children: [
                  _buildInfoRow(context, 'Versiyon', '1.0.0'),
                  const Divider(height: 1),
                  _buildInfoRow(context, 'Platform', Platform.isAndroid ? 'Android' : 'iOS'),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.description_outlined, color: AppColors.textSecondary, size: 20),
                    title: const Text('Kullanim Kosullari', style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
                    onTap: () => _launch('https://supercyp.com/terms'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.privacy_tip_outlined, color: AppColors.textSecondary, size: 20),
                    title: const Text('Gizlilik Politikasi', style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
                    onTap: () => _launch('https://supercyp.com/privacy'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.secondary, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  Widget _buildFaq(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          answer,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showReportDialog(BuildContext context, String title) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Mesajinizi yazin...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Mesajiniz iletildi. Tesekkurler!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.secondary,
            ),
            child: const Text('Gonder'),
          ),
        ],
      ),
    );
  }
}
