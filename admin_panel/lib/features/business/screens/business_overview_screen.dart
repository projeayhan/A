import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/sector_type.dart';
import '../../../core/theme/app_theme.dart';
import '../services/business_service.dart';

class BusinessOverviewScreen extends ConsumerWidget {
  final SectorType sector;
  final String businessId;

  const BusinessOverviewScreen({
    super.key,
    required this.sector,
    required this.businessId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final businessAsync = ref.watch(
      businessDetailProvider((sector: sector, id: businessId)),
    );

    return businessAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Hata: $error'),
          ],
        ),
      ),
      data: (business) {
        if (business == null) {
          return const Center(child: Text('İşletme bulunamadı'));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Cards Row
              Row(
                children: [
                  Expanded(child: _buildInfoCard('Durum', business['status'] ?? '-', Icons.circle, AppColors.success, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoCard('Kayıt Tarihi', _formatDate(business['created_at']), Icons.calendar_today_outlined, AppColors.primary, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoCard('Puan', '${business['rating'] ?? '-'}', Icons.star_outline, AppColors.warning, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoCard(sector.countLabel, '${business['order_count'] ?? business['listing_count'] ?? 0}', Icons.trending_up_outlined, AppColors.info, isDark)),
                ],
              ),
              const SizedBox(height: 24),

              // Details Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Temel Bilgiler', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildDetailRow('Ad', business['name'] ?? business['full_name'] ?? business['company_name'] ?? '-', isDark),
                      _buildDetailRow('Email', business['email'] ?? '-', isDark),
                      _buildDetailRow('Telefon', business['phone'] ?? '-', isDark),
                      _buildDetailRow('Adres', business['address'] ?? '-', isDark),
                      if (business['description'] != null)
                        _buildDetailRow('Açıklama', business['description'], isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    final str = date.toString();
    return str.length >= 10 ? str.substring(0, 10) : str;
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 13, color: isDark ? AppColors.textMuted : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? AppColors.textMuted : Colors.grey.shade600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
