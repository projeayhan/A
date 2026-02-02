import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/job_listings_admin_service.dart';

class JobCompaniesScreen extends ConsumerStatefulWidget {
  const JobCompaniesScreen({super.key});

  @override
  ConsumerState<JobCompaniesScreen> createState() => _JobCompaniesScreenState();
}

class _JobCompaniesScreenState extends ConsumerState<JobCompaniesScreen> {
  String _selectedStatus = 'all';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'all', 'label': 'Tümü', 'color': AppColors.textMuted},
    {'value': 'pending', 'label': 'Bekleyen', 'color': AppColors.warning},
    {'value': 'active', 'label': 'Aktif', 'color': AppColors.success},
    {'value': 'rejected', 'label': 'Reddedildi', 'color': AppColors.error},
  ];

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(companiesProvider(null));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
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
                    Text(
                      'Şirketler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Şirket profillerini ve başvurularını yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(companiesProvider(null)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yenile'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Filters
            _buildFilters(),

            const SizedBox(height: 16),

            // Table
            Expanded(
              child: companiesAsync.when(
                data: (companies) {
                  var filtered = companies;
                  if (_selectedStatus != 'all') {
                    filtered = filtered.where((c) => c.status == _selectedStatus).toList();
                  }
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered.where((c) =>
                      c.name.toLowerCase().contains(_searchQuery.toLowerCase())
                    ).toList();
                  }
                  return _buildCompaniesTable(filtered);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Şirket ara...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 24),
          const Text('Durum:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: _statusOptions.map((opt) {
                final isSelected = _selectedStatus == opt['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(opt['label']),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedStatus = opt['value']),
                    selectedColor: (opt['color'] as Color).withValues(alpha: 0.2),
                    checkmarkColor: opt['color'],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompaniesTable(List<Company> companies) {
    if (companies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Şirket bulunamadı', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Şirket')),
            DataColumn(label: Text('Sektör')),
            DataColumn(label: Text('Şehir')),
            DataColumn(label: Text('Aktif İlan')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('Onay')),
            DataColumn(label: Text('Premium')),
            DataColumn(label: Text('Kayıt Tarihi')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: companies.map((company) => _buildCompanyRow(company)).toList(),
        ),
      ),
    );
  }

  DataRow _buildCompanyRow(Company company) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: company.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(company.logoUrl!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.business, color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Text(company.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        DataCell(Text(company.industry ?? '-')),
        DataCell(Text(company.city ?? '-')),
        DataCell(Text('${company.activeListings}')),
        DataCell(_buildStatusBadge(company.status)),
        DataCell(_buildVerifiedBadge(company.isVerified)),
        DataCell(_buildPremiumBadge(company.isPremium)),
        DataCell(Text(_formatDate(company.createdAt))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (company.status == 'pending') ...[
                IconButton(
                  onPressed: () => _approveCompany(company),
                  icon: const Icon(Icons.check_circle, size: 20),
                  tooltip: 'Onayla',
                  color: AppColors.success,
                ),
                IconButton(
                  onPressed: () => _rejectCompany(company),
                  icon: const Icon(Icons.cancel, size: 20),
                  tooltip: 'Reddet',
                  color: AppColors.error,
                ),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) => _handleCompanyAction(company, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'verify',
                    child: Text(company.isVerified ? 'Onayı Kaldır' : 'Onayla'),
                  ),
                  PopupMenuItem(
                    value: 'premium',
                    child: Text(company.isPremium ? 'Premium Kaldır' : 'Premium Yap'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Bekleyen';
        break;
      case 'active':
        color = AppColors.success;
        label = 'Aktif';
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'Reddedildi';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildVerifiedBadge(bool isVerified) {
    return Icon(
      isVerified ? Icons.verified : Icons.verified_outlined,
      color: isVerified ? AppColors.info : AppColors.textMuted,
      size: 22,
    );
  }

  Widget _buildPremiumBadge(bool isPremium) {
    return Icon(
      isPremium ? Icons.star : Icons.star_border,
      color: isPremium ? AppColors.warning : AppColors.textMuted,
      size: 22,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _approveCompany(Company company) async {
    final service = ref.read(jobListingsAdminServiceProvider);
    try {
      await service.updateCompanyStatus(company.id, 'active');
      ref.invalidate(companiesProvider(null));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şirket onaylandı'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _rejectCompany(Company company) async {
    final service = ref.read(jobListingsAdminServiceProvider);
    try {
      await service.updateCompanyStatus(company.id, 'rejected');
      ref.invalidate(companiesProvider(null));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şirket reddedildi'), backgroundColor: AppColors.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _handleCompanyAction(Company company, String action) async {
    final service = ref.read(jobListingsAdminServiceProvider);
    try {
      switch (action) {
        case 'verify':
          await service.toggleCompanyVerified(company.id, !company.isVerified);
          break;
        case 'premium':
          await service.toggleCompanyPremium(company.id, !company.isPremium);
          break;
      }
      ref.invalidate(companiesProvider(null));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarılı'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
