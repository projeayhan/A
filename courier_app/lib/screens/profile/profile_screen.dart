import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/courier_service.dart';
import '../../core/theme/app_theme.dart';

// Profile provider
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return await CourierService.getCourierProfile();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(profileProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            profileAsync.when(
              data: (profile) => _buildProfileHeader(context, authState, profile),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _buildProfileHeader(context, authState, null),
            ),

            const SizedBox(height: 24),

            // Stats
            profileAsync.when(
              data: (profile) => _buildStatsSection(context, profile),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Menu Items
            _buildMenuSection(context, ref),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthState authState, Map<String, dynamic>? profile) {
    final vehicleType = profile?['vehicle_type'] as String?;
    String vehicleText = '';
    IconData vehicleIcon = Icons.directions_bike;

    switch (vehicleType) {
      case 'bicycle':
        vehicleText = 'Bisiklet';
        vehicleIcon = Icons.pedal_bike;
        break;
      case 'motorcycle':
        vehicleText = 'Motosiklet';
        vehicleIcon = Icons.two_wheeler;
        break;
      case 'car':
        vehicleText = 'Araba';
        vehicleIcon = Icons.directions_car;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                authState.courierName.isNotEmpty
                    ? authState.courierName[0].toUpperCase()
                    : 'K',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            authState.courierName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            authState.courierEmail,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          if (vehicleType != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(vehicleIcon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    vehicleText,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (profile?['vehicle_plate'] != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${profile!['vehicle_plate']}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, Map<String, dynamic>? profile) {
    if (profile == null) return const SizedBox.shrink();

    final totalDeliveries = profile['total_deliveries'] as int? ?? 0;
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0;
    final totalEarnings = (profile['total_earnings'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context,
              Icons.delivery_dining,
              totalDeliveries.toString(),
              'Teslimat',
              AppColors.primary,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppColors.border,
          ),
          Expanded(
            child: _buildStatItem(
              context,
              Icons.star,
              rating.toStringAsFixed(1),
              'Puan',
              AppColors.warning,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppColors.border,
          ),
          Expanded(
            child: _buildStatItem(
              context,
              Icons.account_balance_wallet,
              '₺${totalEarnings.toStringAsFixed(0)}',
              'Toplam',
              AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: 'Kişisel Bilgiler',
            onTap: () => context.push('/profile/personal'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.directions_car_outlined,
            title: 'Araç Bilgileri',
            onTap: () => context.push('/profile/vehicle'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Ödeme Bilgileri',
            onTap: () => context.push('/profile/payment'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'Bildirimler',
            onTap: () => context.push('/profile/notifications'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.help_outline,
            title: 'Yardım & Destek',
            onTap: () => context.push('/profile/help'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: 'Hakkında',
            onTap: () => context.push('/profile/about'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.logout,
            title: 'Çıkış Yap',
            iconColor: AppColors.error,
            textColor: AppColors.error,
            onTap: () {
              _showLogoutDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: textColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

}
