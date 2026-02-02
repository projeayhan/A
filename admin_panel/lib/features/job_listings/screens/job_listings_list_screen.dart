import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/job_listings_admin_service.dart';

class JobListingsListScreen extends ConsumerStatefulWidget {
  const JobListingsListScreen({super.key});

  @override
  ConsumerState<JobListingsListScreen> createState() => _JobListingsListScreenState();
}

class _JobListingsListScreenState extends ConsumerState<JobListingsListScreen> {
  String _selectedStatus = 'all';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'all', 'label': 'Tümü', 'color': AppColors.textMuted},
    {'value': 'pending', 'label': 'Bekleyen', 'color': AppColors.warning},
    {'value': 'active', 'label': 'Aktif', 'color': AppColors.success},
    {'value': 'closed', 'label': 'Kapalı', 'color': AppColors.error},
    {'value': 'filled', 'label': 'Dolu', 'color': AppColors.info},
    {'value': 'expired', 'label': 'Süresi Dolmuş', 'color': AppColors.textMuted},
  ];

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(jobListingsProvider);

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
                      'İş İlanları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tüm iş ilanlarını görüntüleyin ve yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(jobListingsProvider),
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
              child: listingsAsync.when(
                data: (listings) {
                  var filtered = listings;
                  if (_selectedStatus != 'all') {
                    filtered = filtered.where((l) => l.status == _selectedStatus).toList();
                  }
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered.where((l) =>
                      l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (l.companyName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
                    ).toList();
                  }
                  return _buildListingsTable(filtered);
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
          // Search
          SizedBox(
            width: 300,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'İlan veya şirket ara...',
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTable(List<JobListing> listings) {
    if (listings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('İlan bulunamadı', style: TextStyle(color: AppColors.textMuted)),
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
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('İlan Başlığı')),
            DataColumn(label: Text('Şirket')),
            DataColumn(label: Text('Kategori')),
            DataColumn(label: Text('Konum')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('Görüntülenme')),
            DataColumn(label: Text('Başvuru')),
            DataColumn(label: Text('Oluşturulma')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: listings.map((listing) => _buildListingRow(listing)).toList(),
        ),
      ),
    );
  }

  DataRow _buildListingRow(JobListing listing) {
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (listing.isFeatured || listing.isPremium || listing.isUrgent)
                  Row(
                    children: [
                      if (listing.isFeatured)
                        _buildSmallBadge('Öne Çıkan', AppColors.warning),
                      if (listing.isPremium)
                        _buildSmallBadge('Premium', AppColors.primary),
                      if (listing.isUrgent)
                        _buildSmallBadge('Acil', AppColors.error),
                    ],
                  ),
              ],
            ),
          ),
        ),
        DataCell(Text(listing.companyName ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis)),
        DataCell(Text(listing.categoryName ?? '-')),
        DataCell(Text(listing.city)),
        DataCell(_buildStatusBadge(listing.status)),
        DataCell(Text('${listing.viewCount}')),
        DataCell(Text('${listing.applicationCount}')),
        DataCell(Text(_formatDate(listing.createdAt))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (listing.status == 'pending')
                IconButton(
                  onPressed: () => _approveListing(listing),
                  icon: const Icon(Icons.check_circle, size: 20),
                  tooltip: 'Onayla',
                  color: AppColors.success,
                ),
              IconButton(
                onPressed: () => _showListingDetails(listing),
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'Görüntüle',
                color: AppColors.info,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) => _handleListingAction(listing, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'activate', child: Text('Aktifleştir')),
                  const PopupMenuItem(value: 'close', child: Text('Kapat')),
                  const PopupMenuItem(value: 'delete', child: Text('Sil')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500),
      ),
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
      case 'closed':
        color = AppColors.error;
        label = 'Kapalı';
        break;
      case 'filled':
        color = AppColors.info;
        label = 'Dolu';
        break;
      case 'expired':
        color = AppColors.textMuted;
        label = 'Süresi Dolmuş';
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
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _approveListing(JobListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı Onayla'),
        content: Text('"${listing.title}" ilanını onaylamak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(jobListingsAdminServiceProvider);
      try {
        await service.updateListing(listing.id, {'status': 'active'});
        ref.invalidate(jobListingsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İlan onaylandı'), backgroundColor: AppColors.success),
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

  void _showListingDetails(JobListing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(listing.title),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Şirket', listing.companyName ?? '-'),
                _buildDetailRow('Kategori', listing.categoryName ?? '-'),
                _buildDetailRow('Konum', listing.city),
                _buildDetailRow('İş Tipi', listing.jobTypeLabel),
                _buildDetailRow('Çalışma Şekli', listing.workArrangement),
                _buildDetailRow('Deneyim', listing.experienceLevel),
                if (listing.salaryMin != null || listing.salaryMax != null)
                  _buildDetailRow('Maaş', '${listing.salaryMin ?? ''} - ${listing.salaryMax ?? ''} TL'),
                _buildDetailRow('Görüntülenme', '${listing.viewCount}'),
                _buildDetailRow('Başvuru', '${listing.applicationCount}'),
                const Divider(),
                const Text('Açıklama:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(listing.description, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _handleListingAction(JobListing listing, String action) async {
    final service = ref.read(jobListingsAdminServiceProvider);

    try {
      switch (action) {
        case 'activate':
          await service.updateListing(listing.id, {'status': 'active'});
          break;
        case 'close':
          await service.updateListing(listing.id, {'status': 'closed'});
          break;
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('İlanı Sil'),
              content: Text('"${listing.title}" ilanını silmek istediğinize emin misiniz?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text('Sil'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await service.deleteListing(listing.id);
          break;
      }
      ref.invalidate(jobListingsProvider);
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
