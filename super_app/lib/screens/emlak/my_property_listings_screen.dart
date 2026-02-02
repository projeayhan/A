import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/providers/emlak_provider.dart';
import '../../widgets/moderation_feedback_widget.dart';
import '../../services/emlak/property_service.dart';

class MyPropertyListingsScreen extends ConsumerStatefulWidget {
  const MyPropertyListingsScreen({super.key});

  @override
  ConsumerState<MyPropertyListingsScreen> createState() =>
      _MyPropertyListingsScreenState();
}

class _MyPropertyListingsScreenState extends ConsumerState<MyPropertyListingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, ModerationInfo> _moderationCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Supabase'den kullanıcı ilanlarını al
    final userPropertiesState = ref.watch(userPropertiesProvider);

    // Aktif, bekleyen, reddedilen ve kapalı ilanları ayır
    final activeListings = userPropertiesState.activeProperties;
    final pendingListings = userPropertiesState.pendingProperties;
    final rejectedListings = userPropertiesState.rejectedProperties;
    final closedListings = userPropertiesState.closedProperties;

    final isLoading = userPropertiesState.isLoading;

    // Moderasyon bilgilerini yükle
    _loadModerationInfo(pendingListings, rejectedListings);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: EmlakColors.background(isDark),
        appBar: AppBar(
          backgroundColor: EmlakColors.background(isDark),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: EmlakColors.textPrimary(isDark),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'İlanlarım',
            style: TextStyle(
              color: EmlakColors.textPrimary(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: EmlakColors.primary),
              onPressed: () => context.push('/emlak/add'),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: EmlakColors.primary,
            unselectedLabelColor: EmlakColors.textSecondary(isDark),
            indicatorColor: EmlakColors.primary,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Aktif'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: EmlakColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${activeListings.length}',
                        style: TextStyle(
                          color: EmlakColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bekleyen'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: EmlakColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingListings.length}',
                        style: TextStyle(
                          color: EmlakColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Kapanan'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: EmlakColors.textTertiary(
                          isDark,
                        ).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${closedListings.length}',
                        style: TextStyle(
                          color: EmlakColors.textTertiary(isDark),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Reddedilen'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: EmlakColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${rejectedListings.length}',
                        style: TextStyle(
                          color: EmlakColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildListingsTab(activeListings, isDark, 'active', isLoading),
            _buildListingsTab(pendingListings, isDark, 'pending', isLoading),
            _buildListingsTab(closedListings, isDark, 'closed', isLoading),
            _buildListingsTab(rejectedListings, isDark, 'rejected', isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsTab(
    List<Property> listings,
    bool isDark,
    String status,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (listings.isEmpty) {
      return _buildEmptyState(isDark, status);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listings.length + 1, // +1 for stats card
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStatsCard(isDark, listings.length, status);
        }
        final property = listings[index - 1];
        return _buildListingCard(property, isDark, status);
      },
    );
  }

  Widget _buildStatsCard(bool isDark, int count, String status) {
    final stats = _getStatsForStatus(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EmlakColors.primary,
            EmlakColors.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Görüntülenme',
            stats['views'].toString(),
            Icons.visibility,
          ),
          _buildStatItem('Mesaj', stats['messages'].toString(), Icons.message),
          _buildStatItem(
            'Favori',
            stats['favorites'].toString(),
            Icons.favorite,
          ),
        ],
      ),
    );
  }

  Map<String, int> _getStatsForStatus(String status) {
    switch (status) {
      case 'active':
        return {'views': 1234, 'messages': 28, 'favorites': 45};
      case 'pending':
        return {'views': 0, 'messages': 0, 'favorites': 0};
      case 'closed':
        return {'views': 856, 'messages': 12, 'favorites': 23};
      case 'rejected':
        return {'views': 0, 'messages': 0, 'favorites': 0};
      default:
        return {'views': 0, 'messages': 0, 'favorites': 0};
    }
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildListingCard(Property property, bool isDark, String status) {
    return Dismissible(
      key: Key(property.id),
      direction: status == 'closed'
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: EmlakColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation();
      },
      child: GestureDetector(
        onTap: () => context.push('/emlak/property/${property.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: EmlakColors.card(isDark),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Image and Status Badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      property.images.first,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        color: EmlakColors.surface(isDark),
                        child: Icon(
                          Icons.home,
                          size: 60,
                          color: EmlakColors.textTertiary(isDark),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildStatusBadge(status, isDark),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildListingTypeBadge(property.listingType, isDark),
                  ),
                ],
              ),

              // Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: TextStyle(
                        color: EmlakColors.textPrimary(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: EmlakColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location.shortAddress,
                            style: TextStyle(
                              color: EmlakColors.textSecondary(isDark),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          property.formattedPrice,
                          style: TextStyle(
                            color: EmlakColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            _buildActionButton(
                              Icons.edit,
                              EmlakColors.primary,
                              () => _editListing(property),
                            ),
                            const SizedBox(width: 8),
                            if (status == 'active')
                              _buildActionButton(
                                Icons.pause_circle_outline,
                                EmlakColors.accent,
                                () => _pauseListing(property),
                              ),
                            if (status == 'pending')
                              _buildActionButton(
                                Icons.check_circle_outline,
                                EmlakColors.success,
                                () => _approveListing(property),
                              ),
                            if (status == 'closed')
                              _buildActionButton(
                                Icons.refresh,
                                EmlakColors.success,
                                () => _reactivateListing(property),
                              ),
                            if (status == 'rejected')
                              _buildActionButton(
                                Icons.info_outline,
                                EmlakColors.error,
                                () => _showModerationDetails(property, isDark),
                              ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              Icons.delete_outline,
                              EmlakColors.error,
                              () => _deleteListing(property),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Moderasyon feedback section for pending/rejected
                    if (status == 'pending' || status == 'rejected') ...[
                      const SizedBox(height: 12),
                      _buildModerationFeedbackSection(isDark, property.id, status),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'active':
        bgColor = EmlakColors.success;
        textColor = Colors.white;
        label = 'Aktif';
        icon = Icons.check_circle;
        break;
      case 'pending':
        bgColor = EmlakColors.accent;
        textColor = Colors.white;
        label = 'Onay Bekliyor';
        icon = Icons.hourglass_empty;
        break;
      case 'closed':
        bgColor = EmlakColors.textTertiary(isDark);
        textColor = Colors.white;
        label = 'Kapandı';
        icon = Icons.block;
        break;
      case 'rejected':
        bgColor = EmlakColors.error;
        textColor = Colors.white;
        label = 'Reddedildi';
        icon = Icons.cancel;
        break;
      default:
        bgColor = EmlakColors.textTertiary(isDark);
        textColor = Colors.white;
        label = 'Bilinmeyen';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingTypeBadge(ListingType type, bool isDark) {
    final isSale = type == ListingType.sale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSale ? EmlakColors.primary : const Color(0xFF8B5CF6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isSale ? 'Satılık' : 'Kiralık',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String status) {
    String title;
    String subtitle;
    IconData icon;

    switch (status) {
      case 'active':
        title = 'Aktif İlanınız Yok';
        subtitle = 'Hemen yeni bir ilan vererek mülkünüzü satışa çıkarın.';
        icon = Icons.home_work_outlined;
        break;
      case 'pending':
        title = 'Bekleyen İlan Yok';
        subtitle = 'Onay bekleyen ilanınız bulunmuyor.';
        icon = Icons.hourglass_empty;
        break;
      case 'closed':
        title = 'Kapanan İlan Yok';
        subtitle = 'Geçmişte kapattığınız ilan bulunmuyor.';
        icon = Icons.history;
        break;
      case 'rejected':
        title = 'Reddedilen İlan Yok';
        subtitle = 'Reddedilmiş ilanınız bulunmuyor.';
        icon = Icons.cancel_outlined;
        break;
      default:
        title = 'İlan Yok';
        subtitle = '';
        icon = Icons.inbox;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: EmlakColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: EmlakColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: EmlakColors.textPrimary(isDark),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EmlakColors.textSecondary(isDark),
                fontSize: 14,
              ),
            ),
            if (status == 'active') ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.push('/emlak/add'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [EmlakColors.primary, const Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'İlan Ver',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: EmlakColors.card(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'İlanı Sil',
              style: TextStyle(color: EmlakColors.textPrimary(isDark)),
            ),
            content: Text(
              'Bu ilanı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
              style: TextStyle(color: EmlakColors.textSecondary(isDark)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'İptal',
                  style: TextStyle(color: EmlakColors.textSecondary(isDark)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Sil', style: TextStyle(color: EmlakColors.error)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _editListing(Property property) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${property.title} düzenleniyor...'),
        backgroundColor: EmlakColors.primary,
      ),
    );
  }

  Future<void> _pauseListing(Property property) async {
    HapticFeedback.lightImpact();

    final success = await ref.read(userPropertiesProvider.notifier)
        .updatePropertyStatus(property.id, PropertyStatus.pending);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${property.title} duraklatıldı'
              : 'İşlem başarısız oldu'),
          backgroundColor: success ? EmlakColors.accent : EmlakColors.error,
        ),
      );
    }
  }

  Future<void> _approveListing(Property property) async {
    HapticFeedback.lightImpact();

    final success = await ref.read(userPropertiesProvider.notifier)
        .updatePropertyStatus(property.id, PropertyStatus.active);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${property.title} aktifleştirildi'
              : 'İşlem başarısız oldu'),
          backgroundColor: success ? EmlakColors.success : EmlakColors.error,
        ),
      );
    }
  }

  Future<void> _reactivateListing(Property property) async {
    HapticFeedback.lightImpact();

    final success = await ref.read(userPropertiesProvider.notifier)
        .updatePropertyStatus(property.id, PropertyStatus.active);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${property.title} yeniden aktifleştirildi'
              : 'İşlem başarısız oldu'),
          backgroundColor: success ? EmlakColors.success : EmlakColors.error,
        ),
      );
    }
  }

  Future<void> _deleteListing(Property property) async {
    final confirmed = await _showDeleteConfirmation();
    if (!mounted) return;

    if (confirmed) {
      HapticFeedback.mediumImpact();

      final success = await ref.read(userPropertiesProvider.notifier)
          .deleteProperty(property.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '${property.title} silindi'
                : 'Silme işlemi başarısız oldu'),
            backgroundColor: success ? EmlakColors.error : EmlakColors.accent,
          ),
        );
      }
    }
  }

  // ============================================
  // MODERASYON METODLARI
  // ============================================

  Future<void> _loadModerationInfo(
    List<Property> pendingListings,
    List<Property> rejectedListings,
  ) async {
    final propertyService = ref.read(propertyServiceProvider);

    for (final property in [...pendingListings, ...rejectedListings]) {
      if (_moderationCache.containsKey(property.id)) continue;

      try {
        final result = await propertyService.getModerationResult(property.id);
        if (result != null && mounted) {
          setState(() {
            _moderationCache[property.id] = ModerationInfo(
              status: _mapModerationStatus(result.result),
              score: result.score,
              reason: result.reason,
              flags: result.flags,
            );
          });
        }
      } catch (e) {
        // Moderasyon bilgisi alınamazsa sessizce devam et
      }
    }
  }

  ModerationStatus _mapModerationStatus(String? status) {
    switch (status) {
      case 'approved':
        return ModerationStatus.approved;
      case 'rejected':
        return ModerationStatus.rejected;
      case 'manual_review':
        return ModerationStatus.manualReview;
      default:
        return ModerationStatus.pending;
    }
  }

  Widget _buildModerationFeedbackSection(bool isDark, String propertyId, String status) {
    if (status != 'pending' && status != 'rejected') {
      return const SizedBox.shrink();
    }

    final info = _moderationCache[propertyId];
    if (info == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EmlakColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: EmlakColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Moderasyon bilgisi yükleniyor...',
              style: TextStyle(
                color: EmlakColors.textSecondary(isDark),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (info.status == ModerationStatus.rejected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EmlakColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: EmlakColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: EmlakColors.error, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Red Sebebi',
                  style: TextStyle(
                    color: EmlakColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (info.reason != null) ...[
              const SizedBox(height: 6),
              Text(
                info.reason!,
                style: TextStyle(
                  color: EmlakColors.textSecondary(isDark),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (info.flags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: info.flags.take(3).map((flag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: EmlakColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _translateFlag(flag),
                    style: TextStyle(
                      color: EmlakColors.error,
                      fontSize: 10,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      );
    }

    if (info.status == ModerationStatus.manualReview) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EmlakColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: EmlakColors.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'İlanınız ekibimiz tarafından inceleniyor',
                style: TextStyle(
                  color: EmlakColors.textSecondary(isDark),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showModerationDetails(Property property, bool isDark) {
    final info = _moderationCache[property.id];
    if (info == null) return;

    showModerationFeedbackDialog(
      context,
      info: info,
      onEditPressed: () => _editListing(property),
    );
  }

  String _translateFlag(String flag) {
    final translations = {
      'unrealistic_pricing': 'Fiyat sorunu',
      'missing_critical_information': 'Eksik bilgi',
      'missing_critical_property_information': 'Eksik mülk bilgisi',
      'incomplete': 'Eksik ilan',
      'vague': 'Belirsiz açıklama',
      'contact_info_visible': 'İletişim bilgisi görünüyor',
      'spam': 'Spam içerik',
      'duplicate': 'Tekrarlanan içerik',
      'misleading': 'Yanıltıcı bilgi',
      'blacklist_violation': 'Yasaklı kelime',
      'fake': 'Sahte ilan',
      'fraudulent': 'Dolandırıcılık şüphesi',
      'inappropriate': 'Uygunsuz içerik',
    };

    return translations[flag.toLowerCase()] ?? flag.replaceAll('_', ' ');
  }
}
