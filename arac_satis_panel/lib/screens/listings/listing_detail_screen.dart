import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/car_models.dart';
import '../../services/listing_service.dart';
import '../../services/dealer_service.dart';
import '../../providers/dealer_provider.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;

  const ListingDetailScreen({
    super.key,
    required this.listingId,
  });

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  CarListing? _listing;
  List<CarListingPromotion> _promotions = [];
  bool _isLoading = true;
  String? _error;
  int _currentImageIndex = 0;

  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final listing = await ListingService.instance.getListingById(widget.listingId);
      final promotions = await DealerService.instance.getActivePromotions();

      setState(() {
        _listing = listing;
        _promotions = promotions.where((p) => p.listingId == widget.listingId).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 800 && screenWidth <= 1200;

    return Scaffold(
      appBar: AppBar(
        title: Text(_listing?.title ?? 'İlan Detayı'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/panel'),
        ),
        actions: [
          if (_listing != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Düzenle',
              onPressed: () => context.go('/listing/${widget.listingId}/edit'),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value),
              itemBuilder: (context) => [
                if (_listing!.status == CarListingStatus.active)
                  const PopupMenuItem(
                    value: 'sold',
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Satıldı Olarak İşaretle'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (_listing!.status == CarListingStatus.sold)
                  const PopupMenuItem(
                    value: 'republish',
                    child: ListTile(
                      leading: Icon(Icons.refresh, color: Colors.blue),
                      title: Text('Tekrar Yayınla'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'promote',
                  child: ListTile(
                    leading: Icon(Icons.star, color: Colors.orange),
                    title: Text('Öne Çıkar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Sil'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _listing == null
                  ? _buildNotFoundView()
                  : isDesktop
                      ? _buildDesktopLayout(theme)
                      : _buildMobileLayout(theme, isTablet),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Hata: $_error'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadListing,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('İlan bulunamadı'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.go('/panel'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Panele Dön'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Images
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildImageGallery(theme),
                const SizedBox(height: 24),
                _buildPromotionsCard(theme),
              ],
            ),
          ),
        ),
        // Right side - Details
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPriceCard(theme),
                const SizedBox(height: 16),
                _buildStatusCard(theme),
                const SizedBox(height: 16),
                _buildBasicInfoCard(theme),
                const SizedBox(height: 16),
                _buildTechnicalInfoCard(theme),
                const SizedBox(height: 16),
                _buildFeaturesCard(theme),
                const SizedBox(height: 16),
                _buildDescriptionCard(theme),
                const SizedBox(height: 16),
                _buildStatisticsCard(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageGallery(theme),
          const SizedBox(height: 16),
          _buildPriceCard(theme),
          const SizedBox(height: 16),
          _buildStatusCard(theme),
          const SizedBox(height: 16),
          _buildPromotionsCard(theme),
          const SizedBox(height: 16),
          _buildBasicInfoCard(theme),
          const SizedBox(height: 16),
          _buildTechnicalInfoCard(theme),
          const SizedBox(height: 16),
          _buildFeaturesCard(theme),
          const SizedBox(height: 16),
          _buildDescriptionCard(theme),
          const SizedBox(height: 16),
          _buildStatisticsCard(theme),
        ],
      ),
    );
  }

  Widget _buildImageGallery(ThemeData theme) {
    final images = _listing!.images;

    if (images.isEmpty) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car, size: 64, color: Colors.grey),
              SizedBox(height: 8),
              Text('Fotoğraf yok', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Main Image
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.error),
                      ),
                    );
                  },
                ),
                // Image counter
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1} / ${images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                // Navigation arrows
                if (images.length > 1) ...[
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: _currentImageIndex > 0
                            ? () => setState(() => _currentImageIndex--)
                            : null,
                        icon: const Icon(Icons.chevron_left, size: 40),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black26,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: _currentImageIndex < images.length - 1
                            ? () => setState(() => _currentImageIndex++)
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 40),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black26,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Thumbnails
          if (images.length > 1)
            Container(
              height: 80,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentImageIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _currentImageIndex = index),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? theme.primaryColor : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currencyFormat.format(_listing!.price),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: CarSalesColors.primary,
              ),
            ),
            if (_listing!.isNegotiable)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pazarlık Payı Var',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_listing!.status) {
      case CarListingStatus.active:
        statusColor = Colors.green;
        statusText = 'Aktif';
        statusIcon = Icons.check_circle;
        break;
      case CarListingStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Onay Bekliyor';
        statusIcon = Icons.hourglass_empty;
        break;
      case CarListingStatus.sold:
        statusColor = Colors.blue;
        statusText = 'Satıldı';
        statusIcon = Icons.sell;
        break;
      case CarListingStatus.expired:
        statusColor = Colors.grey;
        statusText = 'Süresi Doldu';
        statusIcon = Icons.timer_off;
        break;
      case CarListingStatus.rejected:
        statusColor = Colors.red;
        statusText = 'Reddedildi';
        statusIcon = Icons.cancel;
        break;
      case CarListingStatus.reserved:
        statusColor = Colors.purple;
        statusText = 'Rezerve';
        statusIcon = Icons.bookmark;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İlan Durumu',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_listing!.expiresAt != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Bitiş Tarihi',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy').format(_listing!.expiresAt!),
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionsCard(ThemeData theme) {
    if (_promotions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.star_border, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Aktif Öne Çıkarma Yok',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showPromotionDialog(),
                icon: const Icon(Icons.star),
                label: const Text('Öne Çıkar'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Aktif Öne Çıkarmalar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._promotions.map((promo) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: promo.isFeatured ? Colors.orange.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: promo.isFeatured ? Colors.orange : Colors.blue,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    promo.isFeatured ? Icons.workspace_premium : Icons.trending_up,
                    color: promo.isFeatured ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promo.isFeatured ? 'Premium Öne Çıkarma' : 'Standart Öne Çıkarma',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Bitiş: ${DateFormat('dd.MM.yyyy HH:mm').format(promo.endDate)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _cancelPromotion(promo.id),
                    child: const Text('İptal'),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temel Bilgiler',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Marka', _listing!.brandName),
            _buildInfoRow('Model', _listing!.model),
            _buildInfoRow('Yıl', _listing!.year.toString()),
            _buildInfoRow('Kilometre', '${NumberFormat('#,###').format(_listing!.mileage)} km'),
            _buildInfoRow('Renk', _listing!.color ?? '-'),
            _buildInfoRow('Plaka', _listing!.plateNumber ?? '-'),
            _buildInfoRow('Şehir', _listing!.city ?? '-'),
            if (_listing!.district != null)
              _buildInfoRow('İlçe', _listing!.district!),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teknik Özellikler',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Kasa Tipi', _listing!.bodyType.displayName),
            _buildInfoRow('Yakıt', _listing!.fuelType.displayName),
            _buildInfoRow('Vites', _listing!.transmission.displayName),
            _buildInfoRow('Çekiş', _listing!.traction.displayName),
            if (_listing!.engineSize != null)
              _buildInfoRow('Motor Hacmi', '${_listing!.engineSize} cc'),
            if (_listing!.horsePower != null)
              _buildInfoRow('Beygir Gücü', '${_listing!.horsePower} HP'),
            _buildInfoRow('Durum', _listing!.condition.displayName),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(ThemeData theme) {
    final features = _listing!.features;
    if (features.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Özellikler',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features.map((feature) => Chip(
                label: Text(feature, style: const TextStyle(fontSize: 12)),
                backgroundColor: CarSalesColors.primary.withValues(alpha: 0.1),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(ThemeData theme) {
    if (_listing!.description == null || _listing!.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Açıklama',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _listing!.description!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İstatistikler',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.visibility,
                    label: 'Görüntülenme',
                    value: _listing!.viewCount.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.favorite,
                    label: 'Favori',
                    value: _listing!.favoriteCount.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.calendar_today,
                    label: 'Oluşturulma',
                    value: DateFormat('dd.MM.yy').format(_listing!.createdAt),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: CarSalesColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'sold':
        _markAsSold();
        break;
      case 'republish':
        _republishListing();
        break;
      case 'promote':
        _showPromotionDialog();
        break;
      case 'delete':
        _deleteListing();
        break;
    }
  }

  Future<void> _markAsSold() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satıldı Olarak İşaretle'),
        content: const Text('Bu ilanı satıldı olarak işaretlemek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ListingService.instance.markAsSold(widget.listingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İlan satıldı olarak işaretlendi')),
          );
          _loadListing();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  Future<void> _republishListing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tekrar Yayınla'),
        content: const Text('Bu ilanı tekrar yayınlamak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ListingService.instance.republishListing(widget.listingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İlan tekrar yayınlandı')),
          );
          _loadListing();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  Future<void> _showPromotionDialog() async {
    final promotionPrices = await ref.read(promotionPricesProvider.future);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öne Çıkarma Seçenekleri'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: promotionPrices.map((price) => Card(
              child: ListTile(
                leading: Icon(
                  price.isFeatured ? Icons.workspace_premium : Icons.trending_up,
                  color: price.isFeatured ? Colors.orange : Colors.blue,
                ),
                title: Text('${price.durationDays} Gün'),
                subtitle: Text(price.isFeatured ? 'Premium' : 'Standart'),
                trailing: Text(
                  _currencyFormat.format(price.price),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _createPromotion(price);
                },
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPromotion(PromotionPrice price) async {
    try {
      await DealerService.instance.createPromotion(
        listingId: widget.listingId,
        priceId: price.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Öne çıkarma oluşturuldu')),
        );
        _loadListing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _cancelPromotion(String promotionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öne Çıkarmayı İptal Et'),
        content: const Text('Bu öne çıkarmayı iptal etmek istediğinize emin misiniz? Ücret iadesi yapılmayacaktır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DealerService.instance.cancelPromotion(promotionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Öne çıkarma iptal edildi')),
          );
          _loadListing();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteListing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: const Text('Bu ilanı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ListingService.instance.deleteListing(widget.listingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İlan silindi')),
          );
          context.go('/panel');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }
}
