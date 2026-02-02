import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/car_sales_admin_service.dart';

class CarSalesListingsScreen extends ConsumerStatefulWidget {
  const CarSalesListingsScreen({super.key});

  @override
  ConsumerState<CarSalesListingsScreen> createState() => _CarSalesListingsScreenState();
}

class _CarSalesListingsScreenState extends ConsumerState<CarSalesListingsScreen> {
  String _selectedStatus = 'all';
  List<CarListing> _listings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);
    final service = ref.read(carSalesAdminServiceProvider);
    final listings = await service.getListings(
      status: _selectedStatus == 'all' ? null : _selectedStatus,
    );
    setState(() {
      _listings = listings;
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
                      'Araç İlanları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tüm araç ilanlarını görüntüleyin ve yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loadListings,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Filters
            _buildFilters(),

            const SizedBox(height: 16),

            // Table
            Expanded(
              child: _buildListingsTable(),
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
          const Text('Durum:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Tümü')),
              ButtonSegment(value: 'pending', label: Text('Bekleyen')),
              ButtonSegment(value: 'active', label: Text('Aktif')),
              ButtonSegment(value: 'sold', label: Text('Satıldı')),
              ButtonSegment(value: 'rejected', label: Text('Reddedildi')),
            ],
            selected: {_selectedStatus},
            onSelectionChanged: (value) {
              setState(() => _selectedStatus = value.first);
              _loadListings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == 'all' ? 'Henüz ilan yok' : 'Bu durumda ilan yok',
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
            DataColumn(label: Text('Görsel')),
            DataColumn(label: Text('Başlık')),
            DataColumn(label: Text('Marka/Model')),
            DataColumn(label: Text('Yıl')),
            DataColumn(label: Text('KM')),
            DataColumn(label: Text('Fiyat')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: _listings.map((listing) => _buildListingRow(listing)).toList(),
        ),
      ),
    );
  }

  DataRow _buildListingRow(CarListing listing) {
    return DataRow(
      cells: [
        DataCell(
          Container(
            width: 60,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppColors.background,
            ),
            clipBehavior: Clip.antiAlias,
            child: listing.images.isNotEmpty
                ? Image.network(listing.images.first, fit: BoxFit.cover)
                : const Icon(Icons.directions_car, color: AppColors.textMuted),
          ),
        ),
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              listing.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        DataCell(Text('${listing.brandName} ${listing.modelName}')),
        DataCell(Text(listing.year.toString())),
        DataCell(Text(_formatNumber(listing.mileage))),
        DataCell(Text(_formatPrice(listing.price), style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(_buildStatusBadge(listing.status)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (listing.status == 'pending') ...[
                IconButton(
                  onPressed: () => _approveListing(listing),
                  icon: const Icon(Icons.check, size: 20),
                  tooltip: 'Onayla',
                  color: AppColors.success,
                ),
                IconButton(
                  onPressed: () => _rejectListing(listing),
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Reddet',
                  color: AppColors.error,
                ),
              ],
              IconButton(
                onPressed: () => _deleteListing(listing),
                icon: const Icon(Icons.delete, size: 20),
                tooltip: 'Sil',
                color: AppColors.error,
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
      case 'active':
        color = AppColors.success;
        label = 'Aktif';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Bekliyor';
        break;
      case 'sold':
        color = AppColors.info;
        label = 'Satıldı';
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

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₺';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  void _approveListing(CarListing listing) async {
    final service = ref.read(carSalesAdminServiceProvider);
    try {
      await service.updateListingStatus(listing.id, 'active');
      _loadListings();
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

  void _rejectListing(CarListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı Reddet'),
        content: Text('"${listing.title}" ilanını reddetmek istediğinize emin misiniz?'),
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
        await service.updateListingStatus(listing.id, 'rejected');
        _loadListings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İlan reddedildi'), backgroundColor: AppColors.warning),
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

  void _deleteListing(CarListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: Text('"${listing.title}" ilanını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
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

    if (confirmed == true) {
      final service = ref.read(carSalesAdminServiceProvider);
      try {
        await service.deleteListing(listing.id);
        _loadListings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İlan silindi'), backgroundColor: AppColors.success),
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
