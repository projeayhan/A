import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/jobs_management_providers.dart';

class AdminCompanySettingsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminCompanySettingsScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminCompanySettingsScreen> createState() =>
      _AdminCompanySettingsScreenState();
}

class _AdminCompanySettingsScreenState
    extends ConsumerState<AdminCompanySettingsScreen> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyDetailProvider(widget.companyId));
    final allJobsAsync = ref.watch(
      companyJobsProvider((companyId: widget.companyId, status: 'all')),
    );
    final allApplicantsAsync = ref.watch(
      jobApplicantsProvider(
          (companyId: widget.companyId, jobId: null, status: 'all')),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: companyAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => const Center(
            child: Text('Veriler yüklenirken hata oluştu.',
                style: TextStyle(color: AppColors.textSecondary))),
        data: (company) {
          if (company == null) {
            return const Center(
                child: Text('Şirket bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          // Compute stats from jobs data
          final jobs =
              allJobsAsync.whenOrNull(data: (d) => d) ?? <Map<String, dynamic>>[];
          final applicants = allApplicantsAsync.whenOrNull(data: (d) => d) ??
              <Map<String, dynamic>>[];
          final activeJobs =
              jobs.where((j) => j['status'] == 'active').length;
          final filledJobs =
              jobs.where((j) => j['status'] == 'filled').length;

          return _buildContent(
            company,
            totalJobs: jobs.length,
            totalApplications: applicants.length,
            activeJobs: activeJobs,
            filledPositions: filledJobs,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    Map<String, dynamic> company, {
    required int totalJobs,
    required int totalApplications,
    required int activeJobs,
    required int filledPositions,
  }) {
    final status = company['status'] ?? 'active';
    final name = company['name'] ?? 'İsimsiz';
    final industry = company['industry'] ?? '-';
    final description = company['description'] ?? '';
    final email = company['email'] ?? '-';
    final phone = company['phone'] ?? '-';
    final website = company['website'] ?? '-';
    final address = company['address'] ?? '-';
    final logoUrl = company['logo_url'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Şirket Ayarları',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text(
                      'Şirket profil bilgilerini görüntüleyin ve yönetin.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh,
                    color: AppColors.textSecondary),
                onPressed: () {
                  ref.invalidate(companyDetailProvider(widget.companyId));
                  ref.invalidate(companyJobsProvider);
                  ref.invalidate(jobApplicantsProvider);
                },
                tooltip: 'Yenile',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Company profile card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                CircleAvatar(
                  radius: 40,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      logoUrl != null ? NetworkImage(logoUrl) : null,
                  child: logoUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                          ),
                          _buildCompanyStatusChip(status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(industry,
                            style: const TextStyle(
                                color: AppColors.info,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(description,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _buildStatCard(
                  Icons.work_outline, '$totalJobs', 'Toplam İlan',
                  AppColors.primary),
              const SizedBox(width: 16),
              _buildStatCard(Icons.people_outline,
                  '$totalApplications', 'Toplam Başvuru', AppColors.info),
              const SizedBox(width: 16),
              _buildStatCard(Icons.play_circle_outline,
                  '$activeJobs', 'Aktif İlan', AppColors.success),
              const SizedBox(width: 16),
              _buildStatCard(Icons.check_circle_outline,
                  '$filledPositions', 'Doldurulan', AppColors.warning),
            ],
          ),
          const SizedBox(height: 20),

          // Two column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact info section
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('İletişim Bilgileri',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 20),
                      _buildContactRow(
                          Icons.email_outlined, 'E-posta', email),
                      const Divider(
                          color: AppColors.surfaceLight, height: 24),
                      _buildContactRow(
                          Icons.phone_outlined, 'Telefon', phone),
                      const Divider(
                          color: AppColors.surfaceLight, height: 24),
                      _buildContactRow(
                          Icons.language, 'Web Sitesi', website),
                      const Divider(
                          color: AppColors.surfaceLight, height: 24),
                      _buildContactRow(
                          Icons.location_on_outlined, 'Adres', address),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Right column: status + package
              Expanded(
                child: Column(
                  children: [
                    // Status management
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Durum Yönetimi',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          _buildStatusOption(status, 'active', 'Aktif',
                              AppColors.success, Icons.check_circle),
                          const SizedBox(height: 8),
                          _buildStatusOption(
                              status,
                              'inactive',
                              'Pasif',
                              AppColors.textMuted,
                              Icons.pause_circle),
                          const SizedBox(height: 8),
                          _buildStatusOption(
                              status,
                              'suspended',
                              'Askıya Alınmış',
                              AppColors.error,
                              Icons.block),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
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
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        label = 'Aktif';
      case 'inactive':
        bgColor = AppColors.textMuted.withValues(alpha: 0.2);
        textColor = AppColors.textMuted;
        label = 'Pasif';
      case 'suspended':
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        label = 'Askıya Alınmış';
      default:
        bgColor = AppColors.textMuted.withValues(alpha: 0.2);
        textColor = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatusOption(String currentStatus, String statusValue,
      String label, Color color, IconData icon) {
    final isSelected = currentStatus == statusValue;
    return InkWell(
      onTap: () {
        if (statusValue == 'suspended' && currentStatus != 'suspended') {
          _showStatusReasonDialog(statusValue);
        } else {
          _updateStatus(statusValue);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected ? color : AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    isSelected ? color : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  color:
                      isSelected ? color : AppColors.textSecondary,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                )),
            if (isSelected) ...[
              const Spacer(),
              Icon(Icons.check, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  void _showStatusReasonDialog(String newStatus) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Askıya Alma Nedeni',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Şirketi askıya almak için bir neden belirtiniz.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Askıya alma nedeni...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.surfaceLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.surfaceLight),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateStatus(newStatus,
                  reason: reasonController.text.trim().isEmpty
                      ? null
                      : reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Askıya Al'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String newStatus, {String? reason}) async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseProvider);
      final updateData = <String, dynamic>{'status': newStatus};
      await client
          .from('companies')
          .update(updateData)
          .eq('id', widget.companyId);
      ref.invalidate(companyDetailProvider(widget.companyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Şirket durumu güncellendi.'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
