import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

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
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top,
                  size: 60,
                  color: AppColors.warning,
                ),
              ),

              const SizedBox(height: 32),

              // Başlık
              Text(
                'Başvurunuz Alındı',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Açıklama
              Text(
                'Başvurunuz inceleniyor. Onaylandığında e-posta ile bilgilendirileceksiniz.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Bilgi kartı
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.person_outline,
                      'Ad Soyad',
                      authState.courierProfile?['full_name'] ?? '-',
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.two_wheeler,
                      'Araç',
                      authState.courierProfile?['vehicle_type'] ?? '-',
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.confirmation_number_outlined,
                      'Plaka',
                      authState.courierProfile?['vehicle_plate'] ?? '-',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Yenile butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).refreshProfile();
                    final newState = ref.read(authProvider);
                    if (newState.status == AuthStatus.authenticated && context.mounted) {
                      context.go('/');
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Durumu Kontrol Et'),
                ),
              ),

              const SizedBox(height: 16),

              // Çıkış butonu
              TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                child: const Text('Çıkış Yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
