import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/emlak_models.dart';
import '../../providers/property_provider.dart';

/// İlan Detay Ekranı
class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProperties = ref.watch(userPropertiesProvider);
    final property = userProperties.allProperties.where((p) => p.id == widget.propertyId).firstOrNull;

    if (userProperties.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('İlan Detayı')),
        body: const Center(child: Text('İlan bulunamadı')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF1E293B),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
                onPressed: () => _showEditOptions(property),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white),
                ),
                onPressed: () => _showMoreOptions(property),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image Carousel
                  if (property.images.isNotEmpty)
                    PageView.builder(
                      itemCount: property.images.length,
                      onPageChanged: (index) => setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) {
                        return Image.network(
                          property.images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF1E293B),
                            child: const Icon(Icons.home, size: 64, color: Colors.white24),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: const Color(0xFF1E293B),
                      child: const Icon(Icons.home, size: 64, color: Colors.white24),
                    ),

                  // Image Indicator
                  if (property.images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          property.images.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Status Badge
                  Positioned(
                    top: 100,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(property.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        property.status.label,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: property.listingType.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                property.listingType.label,
                                style: TextStyle(
                                  color: property.listingType.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              property.title,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            property.formattedPrice,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (property.listingType == ListingType.rent)
                            const Text(
                              '/ay',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF64748B), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          property.location.fullAddress,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Stats
                  _buildQuickStats(property),

                  const SizedBox(height: 24),

                  // Description
                  _buildSection('Açıklama', property.description),

                  const SizedBox(height: 24),

                  // Features
                  _buildFeaturesSection(property),

                  const SizedBox(height: 24),

                  // Property Details
                  _buildDetailsSection(property),

                  const SizedBox(height: 24),

                  // Statistics
                  _buildStatisticsSection(property),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(property),
    );
  }

  Widget _buildQuickStats(Property property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.square_foot, '${property.squareMeters} m²', 'Alan'),
          _buildStatDivider(),
          _buildStatItem(Icons.bed, '${property.rooms}', 'Oda'),
          _buildStatDivider(),
          _buildStatItem(Icons.bathtub, '${property.bathrooms}', 'Banyo'),
          if (property.floor != null) ...[
            _buildStatDivider(),
            _buildStatItem(Icons.stairs, '${property.floor}', 'Kat'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF3B82F6), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 50,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(Property property) {
    final features = <MapEntry<IconData, String>>[];

    if (property.hasParking) features.add(const MapEntry(Icons.local_parking, 'Otopark'));
    if (property.hasBalcony) features.add(const MapEntry(Icons.balcony, 'Balkon'));
    if (property.hasFurniture) features.add(const MapEntry(Icons.chair, 'Eşyalı'));
    if (property.hasPool) features.add(const MapEntry(Icons.pool, 'Havuz'));
    if (property.hasGym) features.add(const MapEntry(Icons.fitness_center, 'Spor Salonu'));
    if (property.hasSecurity) features.add(const MapEntry(Icons.security, 'Güvenlik'));
    if (property.hasElevator) features.add(const MapEntry(Icons.elevator, 'Asansör'));
    if (property.isSmartHome) features.add(const MapEntry(Icons.home_max, 'Akıllı Ev'));

    if (features.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Özellikler',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: features.map((feature) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feature.key, color: const Color(0xFF3B82F6), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      feature.value,
                      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(Property property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detaylar',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Emlak Türü', property.type.label),
          _buildDetailRow('İlan Türü', property.listingType.label),
          _buildDetailRow('Brüt m²', '${property.squareMeters} m²'),
          _buildDetailRow('Oda Sayısı', '${property.rooms}'),
          _buildDetailRow('Banyo Sayısı', '${property.bathrooms}'),
          if (property.floor != null)
            _buildDetailRow('Bulunduğu Kat', '${property.floor}'),
          if (property.totalFloors != null)
            _buildDetailRow('Toplam Kat', '${property.totalFloors}'),
          if (property.buildingAge != null)
            _buildDetailRow('Bina Yaşı', '${property.buildingAge} yıl'),
          _buildDetailRow('İlan Tarihi', _formatDate(property.createdAt)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(Property property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İstatistikler',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  Icons.visibility,
                  '${property.viewCount}',
                  'Görüntülenme',
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  Icons.favorite,
                  '${property.favoriteCount}',
                  'Favori',
                  const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  Icons.phone,
                  '0',
                  'Arama',
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Property property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _changeStatus(property),
              icon: const Icon(Icons.sync),
              label: const Text('Durumu Değiştir'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.share),
              label: const Text('Paylaş'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.active:
        return const Color(0xFF10B981);
      case PropertyStatus.pending:
        return const Color(0xFFF59E0B);
      case PropertyStatus.sold:
        return const Color(0xFF8B5CF6);
      case PropertyStatus.rented:
        return const Color(0xFF3B82F6);
      case PropertyStatus.reserved:
        return const Color(0xFF64748B);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showEditOptions(Property property) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
              title: const Text('İlanı Düzenle'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to edit screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFF8B5CF6)),
              title: const Text('Fotoğrafları Düzenle'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to edit images
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(Property property) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Color(0xFFF59E0B)),
              title: const Text('İlanı Rezerve Et'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(userPropertiesProvider.notifier)
                    .updatePropertyStatus(property.id, PropertyStatus.reserved);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('İlanı Sil', style: TextStyle(color: Colors.red)),
              onTap: () => _confirmDelete(property),
            ),
          ],
        ),
      ),
    );
  }

  void _changeStatus(Property property) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Durum Değiştir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...PropertyStatus.values.map((status) {
              return ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(status.label),
                trailing: property.status == status
                    ? const Icon(Icons.check, color: Color(0xFF10B981))
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(userPropertiesProvider.notifier)
                      .updatePropertyStatus(property.id, status);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Property property) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: const Text('Bu ilanı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(userPropertiesProvider.notifier).deleteProperty(property.id);
              if (mounted) context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
