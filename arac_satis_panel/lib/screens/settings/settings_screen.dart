import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/car_models.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hesap
          _buildSectionTitle('Hesap', isDark),
          const SizedBox(height: 12),
          _buildCard(isDark, [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CarSalesColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.email_outlined,
                    color: CarSalesColors.primary, size: 20),
              ),
              title: Text(
                'E-posta',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                currentUser?.email ?? 'Bilinmiyor',
                style: TextStyle(
                  color: CarSalesColors.textSecondary(isDark),
                  fontSize: 13,
                ),
              ),
            ),
            Divider(color: CarSalesColors.border(isDark), height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CarSalesColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    color: CarSalesColors.secondary, size: 20),
              ),
              title: Text(
                'Sifre Degistir',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 14,
                ),
              ),
              trailing: Icon(Icons.chevron_right,
                  color: CarSalesColors.textTertiary(isDark)),
              onTap: () => _showPasswordChangeDialog(context, isDark),
            ),
          ]),
          const SizedBox(height: 24),

          // Gorunum
          _buildSectionTitle('Gorunum', isDark),
          const SizedBox(height: 12),
          _buildCard(isDark, [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.amber : Colors.indigo)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: isDark ? Colors.amber : Colors.indigo,
                  size: 20,
                ),
              ),
              title: Text(
                'Karanlik Tema',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                themeMode == ThemeMode.dark ? 'Acik' : 'Kapali',
                style: TextStyle(
                  color: CarSalesColors.textSecondary(isDark),
                  fontSize: 13,
                ),
              ),
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) {
                  ref.read(themeProvider.notifier).toggle();
                },
                activeColor: CarSalesColors.primary,
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Bildirimler
          _buildSectionTitle('Bildirimler', isDark),
          const SizedBox(height: 12),
          _buildCard(isDark, [
            _NotificationToggle(
              isDark: isDark,
              icon: Icons.email_outlined,
              title: 'E-posta Bildirimleri',
              subtitle: 'Yeni talepler ve guncellemeler',
              prefKey: 'notif_email',
            ),
            Divider(color: CarSalesColors.border(isDark), height: 1),
            _NotificationToggle(
              isDark: isDark,
              icon: Icons.sms_outlined,
              title: 'SMS Bildirimleri',
              subtitle: 'Onemli bildirimler',
              prefKey: 'notif_sms',
            ),
          ]),
          const SizedBox(height: 24),

          // Destek
          _buildSectionTitle('Destek', isDark),
          const SizedBox(height: 12),
          _buildCard(isDark, [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CarSalesColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.help_outline,
                    color: CarSalesColors.success, size: 20),
              ),
              title: Text(
                'Yardim Merkezi',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 14,
                ),
              ),
              trailing: Icon(Icons.open_in_new,
                  size: 18, color: CarSalesColors.textTertiary(isDark)),
              onTap: () => _launchUrl('https://supercyp.com/yardim'),
            ),
            Divider(color: CarSalesColors.border(isDark), height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CarSalesColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.support_agent,
                    color: CarSalesColors.primary, size: 20),
              ),
              title: Text(
                'Bize Ulasin',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 14,
                ),
              ),
              trailing: Icon(Icons.open_in_new,
                  size: 18, color: CarSalesColors.textTertiary(isDark)),
              onTap: () => _launchUrl('mailto:destek@supercyp.com'),
            ),
            Divider(color: CarSalesColors.border(isDark), height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CarSalesColors.textTertiary(isDark)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline,
                    color: CarSalesColors.textTertiary(isDark), size: 20),
              ),
              title: Text(
                'Versiyon',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '1.0.0',
                style: TextStyle(
                  color: CarSalesColors.textSecondary(isDark),
                  fontSize: 13,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: CarSalesColors.textPrimary(isDark),
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showPasswordChangeDialog(BuildContext context, bool isDark) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: CarSalesColors.card(isDark),
          title: Text(
            'Sifre Degistir',
            style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  style:
                      TextStyle(color: CarSalesColors.textPrimary(isDark)),
                  decoration: InputDecoration(
                    labelText: 'Mevcut Sifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mevcut sifrenizi girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  style:
                      TextStyle(color: CarSalesColors.textPrimary(isDark)),
                  decoration: InputDecoration(
                    labelText: 'Yeni Sifre',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Sifre en az 6 karakter olmali';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  style:
                      TextStyle(color: CarSalesColors.textPrimary(isDark)),
                  decoration: InputDecoration(
                    labelText: 'Yeni Sifre (Tekrar)',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return 'Sifreler eslesmiyor';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isLoading = true);

                      try {
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(
                            password: newPasswordController.text,
                          ),
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Sifreniz basariyla guncellendi!'),
                              backgroundColor: CarSalesColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: CarSalesColors.accent,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guncelle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggle extends StatefulWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String prefKey;

  const _NotificationToggle({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prefKey,
  });

  @override
  State<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<_NotificationToggle> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: CarSalesColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(widget.icon, color: CarSalesColors.primary, size: 20),
      ),
      title: Text(
        widget.title,
        style: TextStyle(
          color: CarSalesColors.textPrimary(widget.isDark),
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        widget.subtitle,
        style: TextStyle(
          color: CarSalesColors.textSecondary(widget.isDark),
          fontSize: 13,
        ),
      ),
      trailing: Switch(
        value: _enabled,
        onChanged: (value) {
          setState(() => _enabled = value);
        },
        activeColor: CarSalesColors.primary,
      ),
    );
  }
}
