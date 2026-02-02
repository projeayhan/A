import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Başvurunuz İnceleniyor',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Sürücü başvurunuz inceleme aşamasındadır. Onaylandığında size bildirim göndereceğiz.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Status Steps
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildStatusStep(
                      context,
                      icon: Icons.check_circle,
                      title: 'Başvuru Alındı',
                      subtitle: 'Bilgileriniz başarıyla kaydedildi',
                      isCompleted: true,
                      isActive: false,
                    ),
                    _buildDivider(),
                    _buildStatusStep(
                      context,
                      icon: Icons.pending,
                      title: 'İnceleniyor',
                      subtitle: 'Belgeleriniz kontrol ediliyor',
                      isCompleted: false,
                      isActive: true,
                    ),
                    _buildDivider(),
                    _buildStatusStep(
                      context,
                      icon: Icons.verified,
                      title: 'Onay',
                      subtitle: 'Hesabınız aktif edilecek',
                      isCompleted: false,
                      isActive: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Refresh Button
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).refreshProfile();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Durumu Kontrol Et'),
              ),

              const SizedBox(height: 16),

              // Logout Button
              TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                },
                child: Text(
                  'Çıkış Yap',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusStep(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
  }) {
    Color iconColor;
    Color bgColor;

    if (isCompleted) {
      iconColor = AppColors.success;
      bgColor = AppColors.success.withValues(alpha: 0.1);
    } else if (isActive) {
      iconColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.1);
    } else {
      iconColor = AppColors.textHint;
      bgColor = AppColors.divider;
    }

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCompleted || isActive ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 21),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: 2,
        height: 24,
        color: AppColors.border,
      ),
    );
  }
}
