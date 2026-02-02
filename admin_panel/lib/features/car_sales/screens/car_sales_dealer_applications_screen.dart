import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/car_sales_admin_service.dart';

class CarSalesDealerApplicationsScreen extends ConsumerStatefulWidget {
  const CarSalesDealerApplicationsScreen({super.key});

  @override
  ConsumerState<CarSalesDealerApplicationsScreen> createState() => _CarSalesDealerApplicationsScreenState();
}

class _CarSalesDealerApplicationsScreenState extends ConsumerState<CarSalesDealerApplicationsScreen> {
  String _selectedStatus = 'pending';
  List<CarDealerApplication> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final service = ref.read(carSalesAdminServiceProvider);
    final apps = await service.getApplications(
      status: _selectedStatus == 'all' ? null : _selectedStatus,
    );
    setState(() {
      _applications = apps;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      'Satıcı Başvuruları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Galeri ve bireysel satıcı başvurularını inceleyin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _loadApplications,
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
            Expanded(child: _buildApplicationsTable()),
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
          const Text('Durum:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Tümü')),
              ButtonSegment(value: 'pending', label: Text('Bekleyen')),
              ButtonSegment(value: 'approved', label: Text('Onaylı')),
              ButtonSegment(value: 'rejected', label: Text('Reddedildi')),
            ],
            selected: {_selectedStatus},
            onSelectionChanged: (value) {
              setState(() => _selectedStatus = value.first);
              _loadApplications();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == 'pending' ? 'Bekleyen başvuru yok' : 'Başvuru bulunamadı',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
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
            DataColumn(label: Text('Ad Soyad')),
            DataColumn(label: Text('İşletme')),
            DataColumn(label: Text('Tip')),
            DataColumn(label: Text('Telefon')),
            DataColumn(label: Text('Şehir')),
            DataColumn(label: Text('Tarih')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: _applications.map((app) => _buildApplicationRow(app)).toList(),
        ),
      ),
    );
  }

  DataRow _buildApplicationRow(CarDealerApplication app) {
    return DataRow(
      cells: [
        DataCell(Text(app.ownerName, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(app.businessName ?? '-')),
        DataCell(_buildTypeBadge(app.dealerType)),
        DataCell(Text(app.phone)),
        DataCell(Text('${app.city}${app.district != null ? ' / ${app.district}' : ''}')),
        DataCell(Text(DateFormat('dd.MM.yyyy').format(app.createdAt))),
        DataCell(_buildStatusBadge(app.status)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showApplicationDetails(app),
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'Detay',
                color: AppColors.info,
              ),
              if (app.status == 'pending') ...[
                IconButton(
                  onPressed: () => _approveApplication(app),
                  icon: const Icon(Icons.check, size: 20),
                  tooltip: 'Onayla',
                  color: AppColors.success,
                ),
                IconButton(
                  onPressed: () => _rejectApplication(app),
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Reddet',
                  color: AppColors.error,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color;
    String label;
    switch (type) {
      case 'dealer':
        color = AppColors.primary;
        label = 'Galeri';
        break;
      case 'authorizedDealer':
        color = AppColors.warning;
        label = 'Yetkili Bayi';
        break;
      default:
        color = AppColors.textMuted;
        label = 'Bireysel';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = AppColors.success;
        label = 'Onaylı';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Bekliyor';
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  void _showApplicationDetails(CarDealerApplication app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuru Detayı'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Ad Soyad', app.ownerName),
              _buildDetailRow('İşletme Adı', app.businessName ?? '-'),
              _buildDetailRow('Satıcı Tipi', _getDealerTypeLabel(app.dealerType)),
              _buildDetailRow('Telefon', app.phone),
              _buildDetailRow('E-posta', app.email ?? '-'),
              _buildDetailRow('Şehir', app.city),
              _buildDetailRow('İlçe', app.district ?? '-'),
              _buildDetailRow('Başvuru Tarihi', DateFormat('dd.MM.yyyy HH:mm').format(app.createdAt)),
              if (app.rejectionReason != null)
                _buildDetailRow('Red Sebebi', app.rejectionReason!),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _getDealerTypeLabel(String type) {
    switch (type) {
      case 'dealer': return 'Galeri';
      case 'authorizedDealer': return 'Yetkili Bayi';
      default: return 'Bireysel';
    }
  }

  void _approveApplication(CarDealerApplication app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuruyu Onayla'),
        content: Text('"${app.ownerName}" başvurusunu onaylamak istediğinize emin misiniz?'),
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
      final service = ref.read(carSalesAdminServiceProvider);
      try {
        await service.approveApplication(app.id);
        _loadApplications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Başvuru onaylandı'), backgroundColor: AppColors.success),
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

  void _rejectApplication(CarDealerApplication app) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuruyu Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${app.ownerName}" başvurusunu reddetmek istediğinize emin misiniz?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Red Sebebi (opsiyonel)',
                hintText: 'Neden reddedildiğini açıklayın',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(carSalesAdminServiceProvider);
      try {
        await service.rejectApplication(app.id, reasonController.text);
        _loadApplications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Başvuru reddedildi'), backgroundColor: AppColors.warning),
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
}
