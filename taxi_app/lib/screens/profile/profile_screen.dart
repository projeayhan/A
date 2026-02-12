import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/taxi_service.dart';
import '../../core/theme/app_theme.dart';

// Profile provider
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return await TaxiService.getDriverProfile();
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

            // Vehicle Info
            profileAsync.when(
              data: (profile) => _buildVehicleSection(context, profile),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
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
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                authState.driverName.isNotEmpty
                    ? authState.driverName[0].toUpperCase()
                    : 'S',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            authState.driverName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            authState.driverEmail,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 16),
          if ((profile?['total_ratings'] as int? ?? 0) < 5) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_new_rounded, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Yeni Sürücü',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${5 - (profile?['total_ratings'] as int? ?? 0)} değerlendirme sonra puanınız görünür olacak',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ] else if (profile?['rating'] != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: AppColors.warning, size: 24),
                const SizedBox(width: 4),
                Text(
                  (profile!['rating'] as num).toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleSection(BuildContext context, Map<String, dynamic>? profile) {
    if (profile == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car, color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              Text(
                'Araç Bilgileri',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Divider(height: 24),
          _buildVehicleInfoRow(context, 'Marka', profile['vehicle_brand'] ?? '-'),
          _buildVehicleInfoRow(context, 'Model', profile['vehicle_model'] ?? '-'),
          _buildVehicleInfoRow(context, 'Yıl', profile['vehicle_year']?.toString() ?? '-'),
          _buildVehicleInfoRow(context, 'Renk', profile['vehicle_color'] ?? '-'),
          _buildVehicleInfoRow(context, 'Plaka', profile['vehicle_plate'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, Map<String, dynamic>? profile) {
    if (profile == null) return const SizedBox.shrink();

    final totalRides = profile['total_rides'] as int? ?? 0;
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0;
    final totalRatings = profile['total_ratings'] as int? ?? 0;
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
              Icons.local_taxi,
              totalRides.toString(),
              'Yolculuk',
              AppColors.secondary,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppColors.border,
          ),
          Expanded(
            child: totalRatings < 5
                ? _buildStatItem(
                    context,
                    Icons.fiber_new_rounded,
                    'Yeni',
                    'Puan',
                    Colors.green,
                  )
                : _buildStatItem(
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
            onTap: () => context.push('/personal-info'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.directions_car_outlined,
            title: 'Araç Bilgileri',
            onTap: () => context.push('/vehicle-info'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Ödeme Bilgileri',
            onTap: () => context.push('/payment-info'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.star_outline,
            title: 'Değerlendirmelerim',
            onTap: () => context.push('/reviews'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.emergency_outlined,
            title: 'Acil Durum Kişileri',
            iconColor: AppColors.error,
            onTap: () => context.push('/emergency-contacts'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'Bildirimler',
            onTap: () => context.push('/notification-settings'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.help_outline,
            title: 'Yardım & Destek',
            onTap: () => context.push('/help-support'),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: 'Hakkında',
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.logout,
            title: 'Çıkış Yap',
            iconColor: AppColors.error,
            textColor: AppColors.error,
            onTap: () => _showLogoutDialog(context, ref),
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
          color: (iconColor ?? AppColors.secondary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.secondary, size: 20),
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
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_taxi, color: AppColors.secondary, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Taxi App'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versiyon: 1.0.0'),
            SizedBox(height: 8),
            Text('Taksi sürücü uygulaması ile yolculuklarınızı kolayca yönetin ve kazancınızı takip edin.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
