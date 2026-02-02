import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yardım & Destek'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Section
            Text(
              'İletişim',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildContactItem(
                    icon: Icons.phone,
                    iconColor: AppColors.success,
                    title: 'Telefon Desteği',
                    subtitle: '0850 XXX XX XX',
                    onTap: () => _launchPhone('08501234567'),
                  ),
                  const Divider(height: 1),
                  _buildContactItem(
                    icon: Icons.email,
                    iconColor: AppColors.info,
                    title: 'E-posta',
                    subtitle: 'kurye@destek.com',
                    onTap: () => _launchEmail('kurye@destek.com'),
                  ),
                  const Divider(height: 1),
                  _buildContactItem(
                    icon: Icons.chat,
                    iconColor: AppColors.primary,
                    title: 'Canlı Destek',
                    subtitle: '7/24 aktif',
                    onTap: () {
                      // TODO: Open live chat
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // FAQ Section
            Text(
              'Sık Sorulan Sorular',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            _buildFaqItem(
              context,
              question: 'Siparişi nasıl kabul ederim?',
              answer: 'Ana sayfada "Online" durumuna geçtiğinizde size yakın siparişler gelmeye başlar. Gelen siparişi inceleyip "Kabul Et" butonuna basarak siparişi alabilirsiniz.',
            ),
            _buildFaqItem(
              context,
              question: 'Ödemeler ne zaman yapılır?',
              answer: 'Haftalık kazançlarınız her Pazartesi günü tanımladığınız banka hesabına aktarılır. Minimum ödeme tutarı 100 TL\'dir.',
            ),
            _buildFaqItem(
              context,
              question: 'Araç değişikliği nasıl yapılır?',
              answer: 'Profil > Araç Bilgileri bölümünden araç tipinizi ve plakanızı güncelleyebilirsiniz. Değişiklik onay sürecine tabi olabilir.',
            ),
            _buildFaqItem(
              context,
              question: 'Sipariş iptal edilirse ne olur?',
              answer: 'Müşteri veya işletme tarafından iptal edilen siparişler için herhangi bir ücret kesintisi yapılmaz. İptal nedeniyle oluşan masraflar tarafınıza yansıtılmaz.',
            ),

            const SizedBox(height: 32),

            // Legal Section
            Text(
              'Yasal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildLegalItem(
                    context,
                    title: 'Kullanım Koşulları',
                    onTap: () => _launchUrl('https://example.com/terms'),
                  ),
                  const Divider(height: 1),
                  _buildLegalItem(
                    context,
                    title: 'Gizlilik Politikası',
                    onTap: () => _launchUrl('https://example.com/privacy'),
                  ),
                  const Divider(height: 1),
                  _buildLegalItem(
                    context,
                    title: 'KVKK Aydınlatma Metni',
                    onTap: () => _launchUrl('https://example.com/kvkk'),
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

  Widget _buildContactItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  Widget _buildFaqItem(BuildContext context, {required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        children: [
          Text(
            answer,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalItem(BuildContext context, {required String title, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title),
      trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}
