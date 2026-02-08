import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/providers/unified_favorites_provider.dart';
import '../../core/providers/emlak_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../services/emlak/property_service.dart';
import '../../services/emlak/appointment_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_dialogs.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
  });

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late PageController _imageController;

  int _currentImageIndex = 0;
  Property? _property;
  bool _isLoading = true;
  bool _isStartingChat = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _imageController = PageController();

    _loadProperty();
  }

  Future<void> _loadProperty() async {
    setState(() => _isLoading = true);

    try {
      final service = PropertyService();
      final property = await service.getPropertyById(widget.propertyId);

      if (property != null) {
        setState(() {
          _property = property;
          _isLoading = false;
        });
        // Görüntüleme kaydı
        service.trackPropertyView(widget.propertyId);
        _fadeController.forward();
        _slideController.forward();
      } else {
        // İlan bulunamadı
        if (mounted) {
          setState(() => _isLoading = false);
          await AppDialogs.showError(context, 'İlan bulunamadı');
          if (mounted) context.pop();
        }
      }
    } catch (e) {
      // Hata durumunda
      if (mounted) {
        setState(() => _isLoading = false);
        await AppDialogs.showError(context, 'İlan yüklenirken hata: $e');
        if (mounted) context.pop();
      }
    }
  }

  Future<void> _startChat() async {
    if (_property == null) return;

    final currentUserId = SupabaseService.currentUser?.id;
    if (currentUserId == null) {
      AppDialogs.showError(context, 'Mesaj göndermek için giriş yapmalısınız');
      return;
    }

    // Kendi ilanımıza mesaj atamayız
    if (_property!.userId == currentUserId) {
      AppDialogs.showWarning(context, 'Kendi ilanınıza mesaj gönderemezsiniz');
      return;
    }

    setState(() => _isStartingChat = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final conversation = await chatService.getOrCreateConversation(
        propertyId: _property!.id,
        sellerId: _property!.userId,
      );

      if (mounted) {
        setState(() => _isStartingChat = false);
        context.push('/emlak/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStartingChat = false);
        AppDialogs.showError(context, 'Mesaj başlatılamadı: $e');
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _property == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final property = _property!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: EmlakColors.background(isDark),
        body: Stack(
          children: [
            // Main Content
            CustomScrollView(
              slivers: [
                // Image Gallery
                SliverToBoxAdapter(
                  child: _buildImageGallery(context, property, size, isDark),
                ),

                // Property Info
                SliverToBoxAdapter(
                  child: _buildPropertyInfo(context, property, isDark),
                ),

                // Features Section
                SliverToBoxAdapter(
                  child: _buildFeaturesSection(context, property, isDark),
                ),

                // Amenities Section
                SliverToBoxAdapter(
                  child: _buildAmenitiesSection(context, property, isDark),
                ),

                // Description Section
                SliverToBoxAdapter(
                  child: _buildDescriptionSection(context, property, isDark),
                ),

                // Location Section
                SliverToBoxAdapter(
                  child: _buildLocationSection(context, property, isDark),
                ),

                // Agent Section
                SliverToBoxAdapter(
                  child: _buildAgentSection(context, property, isDark),
                ),

                // Similar Properties
                SliverToBoxAdapter(
                  child: _buildSimilarProperties(context, property, isDark),
                ),

                // Bottom Padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ),

            // Bottom Action Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(context, property, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(
    BuildContext context,
    Property property,
    Size size,
    bool isDark,
  ) {
    return SizedBox(
      height: size.height * 0.32,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image PageView
          PageView.builder(
            controller: _imageController,
            itemCount: property.images.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showFullScreenGallery(context, property.images, index),
                child: Image.network(
                  property.images[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: EmlakColors.primary.withValues(alpha: 0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: EmlakColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: EmlakColors.primary.withValues(alpha: 0.3),
                    child: const Icon(Icons.image, size: 80, color: Colors.white54),
                  ),
                ),
              );
            },
          ),

          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop(),
                  ),
                  Row(
                    children: [
                      _buildCircleButton(
                        icon: Icons.share_rounded,
                        onTap: () => _shareProperty(property),
                      ),
                      const SizedBox(width: 12),
                      _buildFavoriteButton(property),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Indicators & Badges
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badges
                Row(
                  children: [
                    _buildBadge(
                      property.listingType.label,
                      property.listingType.color,
                    ),
                    if (property.isPremium) ...[
                      const SizedBox(width: 8),
                      _buildBadge(
                        'Premium',
                        EmlakColors.accent,
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ],
                  ],
                ),
                // Image Indicators
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${_currentImageIndex + 1}/${property.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 360° View Button (if applicable)
          Positioned(
            bottom: 70,
            right: 20,
            child: _buildCircleButton(
              icon: Icons.view_in_ar_rounded,
              onTap: () {},
              size: 48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 44,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? EmlakColors.accent : Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.grey[800],
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(Property property) {
    final isFavorite = ref.watch(isEmlakFavoriteProvider(property.id));

    return GestureDetector(
      onTap: () {
        final favoriteProperty = FavoriteProperty(
          id: property.id,
          title: property.title,
          imageUrl: property.images.isNotEmpty ? property.images.first : '',
          location: property.location.shortAddress,
          price: property.price,
          type: property.listingType == ListingType.sale ? 'sale' : 'rent',
          propertyType: property.type.label,
          rooms: property.rooms,
          area: property.squareMeters,
          addedAt: DateTime.now(),
        );
        ref.read(emlakFavoriteProvider.notifier).toggleProperty(favoriteProperty);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorite
                  ? '${property.title} favorilerden kaldırıldı'
                  : '${property.title} favorilere eklendi',
            ),
            backgroundColor: isFavorite ? Colors.red : EmlakColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isFavorite ? EmlakColors.accent : Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? Colors.white : Colors.grey[800],
          size: 22,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyInfo(
    BuildContext context,
    Property property,
    bool isDark,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          padding: const EdgeInsets.all(16),
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
                        Text(
                          property.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.grey[900],
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: EmlakColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                property.location.fullAddress,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Price Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: EmlakColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: EmlakColors.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.listingType == ListingType.rent
                              ? 'Aylık Kira'
                              : 'Satış Fiyatı',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          property.fullFormattedPrice,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.square_foot,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(property.price / property.squareMeters).toStringAsFixed(0)} TL/m²',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Stats
              Row(
                children: [
                  _buildStatCard(
                    Icons.visibility_outlined,
                    '${property.viewCount}',
                    'Görüntülenme',
                    isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    Icons.favorite_outline_rounded,
                    '${property.favoriteCount}',
                    'Favori',
                    isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    Icons.access_time_rounded,
                    _getTimeAgo(property.createdAt),
                    'Yayın',
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: EmlakColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(
    BuildContext context,
    Property property,
    bool isDark,
  ) {
    final features = [
      {'icon': Icons.bed_outlined, 'value': '${property.rooms}+1', 'label': 'Oda'},
      {'icon': Icons.bathtub_outlined, 'value': '${property.bathrooms}', 'label': 'Banyo'},
      {'icon': Icons.square_foot, 'value': '${property.squareMeters}', 'label': 'm²'},
      if (property.floor != null)
        {'icon': Icons.stairs, 'value': '${property.floor}/${property.totalFloors}', 'label': 'Kat'},
      if (property.buildingAge != null && property.buildingAge! > 0)
        {'icon': Icons.calendar_today_outlined, 'value': '${property.buildingAge}', 'label': 'Yaş'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Özellikler', isDark),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: features.map((feature) {
              return _buildFeatureItem(
                feature['icon'] as IconData,
                feature['value'] as String,
                feature['label'] as String,
                isDark,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: EmlakColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: EmlakColors.primary, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection(
    BuildContext context,
    Property property,
    bool isDark,
  ) {
    final amenities = <Map<String, dynamic>>[
      if (property.hasParking)
        {'icon': Icons.local_parking_rounded, 'label': 'Otopark'},
      if (property.hasBalcony)
        {'icon': Icons.balcony_rounded, 'label': 'Balkon'},
      if (property.hasFurniture)
        {'icon': Icons.chair_rounded, 'label': 'Eşyalı'},
      if (property.hasPool)
        {'icon': Icons.pool_rounded, 'label': 'Havuz'},
      if (property.hasGym)
        {'icon': Icons.fitness_center_rounded, 'label': 'Spor Salonu'},
      if (property.hasSecurity)
        {'icon': Icons.security_rounded, 'label': 'Güvenlik'},
      if (property.hasElevator)
        {'icon': Icons.elevator_rounded, 'label': 'Asansör'},
      if (property.isSmartHome)
        {'icon': Icons.smart_toy_rounded, 'label': 'Akıllı Ev'},
    ];

    if (amenities.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Olanaklar', isDark),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: amenities.map((amenity) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      amenity['icon'] as IconData,
                      color: EmlakColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      amenity['label'] as String,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          // Additional amenities
          if (property.amenities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: property.amenities.map((amenity) {
                return Chip(
                  label: Text(
                    amenity,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.grey[700],
                    ),
                  ),
                  backgroundColor: isDark
                      ? Colors.grey[800]
                      : EmlakColors.primary.withValues(alpha: 0.1),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(
    BuildContext context,
    Property property,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Açıklama', isDark),
          const SizedBox(height: 12),
          Text(
            property.description,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    Property property,
    bool isDark,
  ) {
    final hasCoordinates = property.location.latitude != null &&
                           property.location.longitude != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Konum', isDark),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasCoordinates
                ? GestureDetector(
                    onTap: () => _openInMaps(property),
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              property.location.latitude!,
                              property.location.longitude!,
                            ),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none, // Harita etkileşimini devre dışı bırak
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.super.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    property.location.latitude!,
                                    property.location.longitude!,
                                  ),
                                  width: 50,
                                  height: 50,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: EmlakColors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: EmlakColors.primary.withValues(alpha: 0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.home_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Haritayı aç butonu
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new, size: 16, color: EmlakColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Haritada Aç',
                                  style: TextStyle(
                                    color: EmlakColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : // Konum bilgisi yoksa placeholder göster
                  InkWell(
                    onTap: () => _searchInMaps(property),
                    child: Container(
                      color: EmlakColors.primary.withValues(alpha: 0.1),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 48,
                              color: EmlakColors.primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Haritada Ara',
                              style: TextStyle(
                                color: EmlakColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              property.location.fullAddress,
                              style: TextStyle(
                                color: EmlakColors.primary.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  property.location.fullAddress,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Koordinatları Google Maps'te aç
  Future<void> _openInMaps(Property property) async {
    if (property.location.latitude == null || property.location.longitude == null) return;

    final lat = property.location.latitude!;
    final lng = property.location.longitude!;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Adres ile Google Maps'te ara
  Future<void> _searchInMaps(Property property) async {
    final address = Uri.encodeComponent(property.location.fullAddress);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildAgentSection(
    BuildContext context,
    Property property,
    bool isDark,
  ) {
    final agent = property.agent;

    if (agent == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('İlan Sahibi', isDark),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: EmlakColors.primaryGradient,
                    ),
                  ),
                  child: agent.imageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            agent.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            agent.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[900],
                            ),
                          ),
                          if (agent.isVerified) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.verified_rounded,
                              color: EmlakColors.primary,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      if (agent.company != null)
                        Text(
                          agent.company!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: EmlakColors.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${agent.rating}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${agent.totalListings} ilan',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Chat Button
                GestureDetector(
                  onTap: _isStartingChat ? null : _startChat,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: EmlakColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isStartingChat
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: EmlakColors.primary,
                            size: 22,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarProperties(
    BuildContext context,
    Property currentProperty,
    bool isDark,
  ) {
    return FutureBuilder<List<Property>>(
      future: PropertyService().getSimilarProperties(currentProperty),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final similar = snapshot.data ?? [];
        if (similar.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSectionTitle('Benzer İlanlar', isDark),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: similar.length,
                  itemBuilder: (context, index) {
                    final property = similar[index];
                    return _buildSimilarCard(context, property, isDark);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimilarCard(
    BuildContext context,
    Property property,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => context.push('/emlak/property/${property.id}'),
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                property.images.first,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: EmlakColors.primary.withValues(alpha: 0.2),
                  child: const Icon(Icons.image, color: Colors.white54),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.location.shortAddress,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    property.formattedPrice,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: EmlakColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.grey[900],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    Property property,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Call Button (icon only)
          GestureDetector(
            onTap: property.agent != null ? () => _callAgent(property.agent!) : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: EmlakColors.primary, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.phone_rounded, color: EmlakColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          // Message Button (icon only)
          GestureDetector(
            onTap: _isStartingChat ? null : _startChat,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: EmlakColors.secondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isStartingChat
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Schedule Button (primary CTA - expanded)
          Expanded(
            child: GestureDetector(
              onTap: () => _scheduleVisit(context, property),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: EmlakColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Randevu Al',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} hafta';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat';
    } else {
      return 'Az önce';
    }
  }

  /// Tam ekran fotoğraf galerisi
  void _showFullScreenGallery(BuildContext context, List<String> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenGallery(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _shareProperty(Property property) {
    final text = '''
${property.title}

📍 ${property.location.fullAddress}
💰 ${property.fullFormattedPrice}
🏠 ${property.rooms}+1 | ${property.squareMeters} m²

${property.description.length > 200 ? '${property.description.substring(0, 200)}...' : property.description}

Bu ilanı SuperApp'te görüntüle!
''';

    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: property.title,
      ),
    );
  }

  Future<void> _callAgent(PropertyAgent agent) async {
    if (agent.phone.isEmpty) {
      if (mounted) {
        AppDialogs.showWarning(context, 'Telefon numarası bulunamadı');
      }
      return;
    }

    final phoneNumber = agent.phone.replaceAll(' ', '').replaceAll('-', '');
    final uri = Uri.parse('tel:$phoneNumber');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppDialogs.showError(context, 'Arama yapılamadı');
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Hata: $e');
      }
    }
  }

  void _scheduleVisit(BuildContext context, Property property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ScheduleVisitSheet(property: property),
    );
  }
}

class _ScheduleVisitSheet extends StatefulWidget {
  final Property property;

  const _ScheduleVisitSheet({required this.property});

  @override
  State<_ScheduleVisitSheet> createState() => _ScheduleVisitSheetState();
}

class _ScheduleVisitSheetState extends State<_ScheduleVisitSheet> {
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;
  final _noteController = TextEditingController();
  final _appointmentService = AppointmentService();

  final times = ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitAppointment() async {
    if (_selectedDate == null || _selectedTime == null) return;

    final currentUserId = SupabaseService.currentUser?.id;
    if (currentUserId == null) {
      AppDialogs.showError(context, 'Randevu almak için giriş yapmalısınız');
      return;
    }

    if (widget.property.userId == currentUserId) {
      AppDialogs.showWarning(context, 'Kendi ilanınıza randevu alamazsınız');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _appointmentService.createAppointment(
        propertyId: widget.property.id,
        ownerId: widget.property.userId,
        date: _selectedDate!,
        time: _selectedTime!,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Randevu talebiniz gönderildi! İlan sahibi onayladığında bilgilendirileceksiniz.'),
            backgroundColor: EmlakColors.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialogs.showError(context, 'Randevu oluşturulamadı: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Randevu Al',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Property Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.property.images.first,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 60,
                              color: EmlakColors.primary.withValues(alpha: 0.2),
                              child: const Icon(Icons.home, color: Colors.white54),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.property.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.grey[900],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.property.formattedPrice,
                                style: TextStyle(
                                  color: EmlakColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Tarih Seçin',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 14,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index + 1));
                        final isSelected = _selectedDate?.day == date.day &&
                            _selectedDate?.month == date.month;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDate = date),
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? EmlakColors.primary
                                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                    ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getDayName(date.weekday),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white : Colors.grey[900]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Saat Seçin',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: times.map((time) {
                      final isSelected = _selectedTime == time;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTime = time),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? EmlakColors.primary
                                : (isDark ? Colors.grey[800] : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                  ),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.grey[800]),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Not (İsteğe bağlı)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'İlan sahibine iletmek istediğiniz bir not...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_selectedDate != null && _selectedTime != null && !_isLoading)
                    ? _submitAppointment
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EmlakColors.primary,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Randevu Talebi Gönder',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[weekday - 1];
  }
}

/// Tam ekran fotoğraf galerisi
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fotoğraf PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      size: 80,
                      color: Colors.white54,
                    ),
                  ),
                ),
              );
            },
          ),

          // Üst bar - Kapat butonu ve sayaç
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Kapat butonu
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  // Fotoğraf sayacı
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Alt bar - Thumbnail'lar
          if (widget.images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Opacity(
                            opacity: isSelected ? 1.0 : 0.5,
                            child: Image.network(
                              widget.images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.white54,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
