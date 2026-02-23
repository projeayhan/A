import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/realtor_provider.dart';
import '../../../core/theme/app_colors.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _statusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Onaylı';
      case 'pending':
        return 'Beklemede';
      case 'under_review':
        return 'İnceleniyor';
      case 'rejected':
        return 'Reddedildi';
      case 'suspended':
        return 'Askıya Alındı';
      default:
        return status ?? 'Bilinmiyor';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'pending':
      case 'under_review':
        return AppColors.warning;
      case 'rejected':
      case 'suspended':
        return AppColors.error;
      default:
        return AppColors.textMutedLight;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(realtorProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Profil yüklenemedi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(realtorProfileProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text(
                'Profil bulunamadı',
                style: TextStyle(color: AppColors.textSecondaryLight),
              ),
            );
          }
          return _buildProfileContent(context, ref, profile);
        },
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> profile,
  ) {
    final companyName = profile['company_name'] as String? ?? 'Emlakçı';
    final email = profile['email'] as String? ??
        profile['contact_email'] as String? ??
        '';
    final city = profile['city'] as String? ?? '';
    final phone = profile['phone'] as String? ??
        profile['contact_phone'] as String? ??
        '-';
    final licenseNumber = profile['license_number'] as String? ?? '-';
    final status = profile['status'] as String?;
    final about = profile['about'] as String? ??
        profile['bio'] as String? ??
        '-';
    final totalListings = profile['total_listings'] as int? ??
        profile['listing_count'] as int? ??
        0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  companyName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    city,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to profile edit
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Profili Düzenle'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Profile Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profil Bilgileri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Telefon',
                  value: phone,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Lisans No',
                  value: licenseNumber,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.location_city_outlined,
                  label: 'Şehir',
                  value: city.isNotEmpty ? city : '-',
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.verified_outlined,
                  label: 'Durum',
                  value: _statusText(status),
                  valueColor: _statusColor(status),
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.info_outline,
                  label: 'Hakkımda',
                  value: about,
                  isMultiLine: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statistics Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'İstatistikler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatRow(
                  icon: Icons.home_work_outlined,
                  label: 'Toplam İlan',
                  value: '$totalListings',
                  iconColor: AppColors.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isMultiLine = false,
  }) {
    return Row(
      crossAxisAlignment:
          isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}
