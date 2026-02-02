import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/emlak_admin_service.dart';

class EmlakListingsScreen extends ConsumerStatefulWidget {
  const EmlakListingsScreen({super.key});

  @override
  ConsumerState<EmlakListingsScreen> createState() => _EmlakListingsScreenState();
}

class _EmlakListingsScreenState extends ConsumerState<EmlakListingsScreen> {
  String _searchQuery = '';
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(emlakListingsProvider(_selectedStatus));

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
                      'İlan Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Emlak ilanlarını inceleyin ve yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(emlakListingsProvider(_selectedStatus)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  // Status Filter
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Durum Filtrele',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('Tüm İlanlar')),
                        DropdownMenuItem<String?>(value: 'pending', child: Text('Onay Bekleyen')),
                        DropdownMenuItem<String?>(value: 'active', child: Text('Aktif')),
                        DropdownMenuItem<String?>(value: 'rejected', child: Text('Reddedilen')),
                        DropdownMenuItem<String?>(value: 'sold', child: Text('Satıldı')),
                        DropdownMenuItem<String?>(value: 'rented', child: Text('Kiralandı')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedStatus = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'İlan ara...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Listings Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: listingsAsync.when(
                  data: (listings) => _buildListingsTable(listings),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Hata: $e', style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsTable(List<EmlakListing> listings) {
    final filteredListings = listings.where((listing) {
      return _searchQuery.isEmpty ||
          listing.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (listing.city?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (listing.district?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();

    if (filteredListings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('İlan bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            if (_searchQuery.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _searchQuery = ''),
                child: const Text('Aramayı Temizle'),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 60),
              Expanded(flex: 3, child: Text('İlan', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 2, child: Text('Konum', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Fiyat', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Tür', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Durum', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              SizedBox(width: 120, child: Text('İşlemler', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        // Table Body
        Expanded(
          child: ListView.builder(
            itemCount: filteredListings.length,
            itemBuilder: (context, index) {
              final listing = filteredListings[index];
              return _buildListingRow(listing, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListingRow(EmlakListing listing, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.transparent : AppColors.background.withValues(alpha: 0.5),
        border: const Border(bottom: BorderSide(color: AppColors.surfaceLight, width: 0.5)),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 60,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: listing.images.isNotEmpty
                  ? Image.network(
                      listing.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.home, color: AppColors.textMuted, size: 20),
                    )
                  : const Icon(Icons.home, color: AppColors.textMuted, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Title & Type
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getPropertyTypeText(listing.propertyType),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          // Location
          Expanded(
            flex: 2,
            child: Text(
              '${listing.city ?? '-'} / ${listing.district ?? '-'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Price
          Expanded(
            flex: 1,
            child: Text(
              _formatPrice(listing.price),
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
          // Listing Type
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: listing.listingType == 'sale'
                    ? AppColors.info.withValues(alpha: 0.15)
                    : AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                listing.listingType == 'sale' ? 'Satılık' : 'Kiralık',
                style: TextStyle(
                  color: listing.listingType == 'sale' ? AppColors.info : AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: _buildStatusBadge(listing.status),
          ),
          // Actions
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (listing.status == 'pending') ...[
                  IconButton(
                    onPressed: () => _approveListing(listing),
                    icon: const Icon(Icons.check, size: 18),
                    tooltip: 'Onayla',
                    color: AppColors.success,
                  ),
                  IconButton(
                    onPressed: () => _rejectListing(listing),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Reddet',
                    color: AppColors.error,
                  ),
                ] else ...[
                  IconButton(
                    onPressed: () => _showListingDetails(listing),
                    icon: const Icon(Icons.visibility, size: 18),
                    tooltip: 'Görüntüle',
                    color: AppColors.textMuted,
                  ),
                  IconButton(
                    onPressed: () => _showDeleteConfirmDialog(listing),
                    icon: const Icon(Icons.delete, size: 18),
                    tooltip: 'Sil',
                    color: AppColors.error,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = AppColors.warning;
        text = 'Bekliyor';
        break;
      case 'active':
        color = AppColors.success;
        text = 'Aktif';
        break;
      case 'rejected':
        color = AppColors.error;
        text = 'Reddedildi';
        break;
      case 'sold':
        color = AppColors.info;
        text = 'Satıldı';
        break;
      case 'rented':
        color = AppColors.primary;
        text = 'Kiralandı';
        break;
      default:
        color = AppColors.textMuted;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M ₺';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K ₺';
    }
    return '${price.toStringAsFixed(0)} ₺';
  }

  String _getPropertyTypeText(String type) {
    switch (type) {
      case 'apartment':
        return 'Daire';
      case 'villa':
        return 'Villa';
      case 'land':
        return 'Arsa';
      case 'office':
        return 'Ofis';
      case 'shop':
        return 'Dükkan';
      case 'warehouse':
        return 'Depo';
      case 'building':
        return 'Bina';
      case 'farm':
        return 'Çiftlik';
      default:
        return type;
    }
  }

  void _approveListing(EmlakListing listing) async {
    final service = ref.read(emlakAdminServiceProvider);
    try {
      await service.updateListingStatus(listing.id, 'active');
      ref.invalidate(emlakListingsProvider(_selectedStatus));
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

  void _rejectListing(EmlakListing listing) async {
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
      final service = ref.read(emlakAdminServiceProvider);
      try {
        await service.updateListingStatus(listing.id, 'rejected');
        ref.invalidate(emlakListingsProvider(_selectedStatus));
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

  void _showListingDetails(EmlakListing listing) {
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
                if (listing.images.isNotEmpty)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(listing.images.first),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildDetailRow('Konum', '${listing.city ?? '-'} / ${listing.district ?? '-'}'),
                _buildDetailRow('Fiyat', _formatPrice(listing.price)),
                _buildDetailRow('Tür', _getPropertyTypeText(listing.propertyType)),
                _buildDetailRow('İlan Tipi', listing.listingType == 'sale' ? 'Satılık' : 'Kiralık'),
                _buildDetailRow('Durum', listing.status),
                if (listing.description != null) ...[
                  const Divider(),
                  const Text('Açıklama:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(listing.description!, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(EmlakListing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: Text('"${listing.title}" ilanını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(emlakAdminServiceProvider);
              try {
                await service.deleteListing(listing.id);
                ref.invalidate(emlakListingsProvider(_selectedStatus));
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${listing.title} silindi')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
