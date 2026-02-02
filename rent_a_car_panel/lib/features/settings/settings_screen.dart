import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Company info provider
final companyInfoProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return null;

  final response = await client
      .from('rental_companies')
      .select('*')
      .eq('id', companyId)
      .maybeSingle();

  return response;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyInfoProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ayarlar',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column - Company info
                Expanded(
                  flex: 2,
                  child: companyAsync.when(
                    data: (company) {
                      if (company == null) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Şirket bilgisi bulunamadı'),
                          ),
                        );
                      }

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: company['logo_url'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Image.network(
                                              company['logo_url'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.business,
                                                size: 40,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.business,
                                            size: 40,
                                            color: AppColors.textMuted,
                                          ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          company['company_name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 18,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${(company['rating'] ?? 0).toStringAsFixed(1)} puan',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            _buildStatusChip(company['is_approved'] == true),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _showEditCompanyDialog(context, ref, company),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Düzenle'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 24),

                              // Company details
                              _buildInfoSection('İletişim Bilgileri', [
                                _buildInfoRow(Icons.email, 'E-posta', company['email'] ?? '-'),
                                _buildInfoRow(Icons.phone, 'Telefon', company['phone'] ?? '-'),
                                _buildInfoRow(Icons.location_on, 'Adres', company['address'] ?? '-'),
                                _buildInfoRow(Icons.location_city, 'Şehir', company['city'] ?? '-'),
                              ]),
                              const SizedBox(height: 24),

                              _buildInfoSection('Vergi Bilgileri', [
                                _buildInfoRow(Icons.badge, 'Vergi No', company['tax_number'] ?? '-'),
                                _buildInfoRow(Icons.account_balance, 'Vergi Dairesi', company['tax_office'] ?? '-'),
                              ]),
                              const SizedBox(height: 24),

                              _buildInfoSection('Komisyon Bilgileri', [
                                _buildInfoRow(
                                  Icons.percent,
                                  'Platform Komisyonu',
                                  '%${(company['commission_rate'] ?? 15).toStringAsFixed(1)}',
                                ),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Hata: $e')),
                  ),
                ),
                const SizedBox(width: 24),

                // Right column - Account & Actions
                Expanded(
                  child: Column(
                    children: [
                      // Account info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hesap Bilgileri',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                Icons.email,
                                'E-posta',
                                user?.email ?? '-',
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.calendar_today,
                                'Kayıt Tarihi',
                                user?.createdAt != null
                                    ? user!.createdAt.substring(0, 10)
                                    : '-',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick actions
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hızlı İşlemler',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildActionTile(
                                icon: Icons.lock_outline,
                                title: 'Şifre Değiştir',
                                onTap: () => _showChangePasswordDialog(context),
                              ),
                              const Divider(),
                              _buildActionTile(
                                icon: Icons.help_outline,
                                title: 'Yardım & Destek',
                                onTap: () {},
                              ),
                              const Divider(),
                              _buildActionTile(
                                icon: Icons.description_outlined,
                                title: 'Kullanım Koşulları',
                                onTap: () {},
                              ),
                              const Divider(),
                              _buildActionTile(
                                icon: Icons.logout,
                                title: 'Çıkış Yap',
                                color: AppColors.error,
                                onTap: () => _logout(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isApproved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isApproved ? 'Onaylı' : 'Onay Bekliyor',
        style: TextStyle(
          color: isApproved ? AppColors.success : AppColors.warning,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(
        title,
        style: TextStyle(color: color),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: color ?? AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }

  Future<void> _showEditCompanyDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> company,
  ) async {
    final nameController = TextEditingController(text: company['company_name'] ?? '');
    final phoneController = TextEditingController(text: company['phone'] ?? '');
    final emailController = TextEditingController(text: company['email'] ?? '');
    final addressController = TextEditingController(text: company['address'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şirket Bilgilerini Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Şirket Adı'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Adres'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final client = ref.read(supabaseClientProvider);
        await client
            .from('rental_companies')
            .update({
              'company_name': nameController.text.trim(),
              'phone': phoneController.text.trim(),
              'email': emailController.text.trim(),
              'address': addressController.text.trim(),
            })
            .eq('id', company['id']);

        ref.invalidate(companyInfoProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bilgiler güncellendi')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifre Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mevcut Şifre'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni Şifre'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni Şifre (Tekrar)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Değiştir'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (newController.text != confirmController.text) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Şifreler eşleşmiyor'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newController.text),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Şifre değiştirildi')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}
