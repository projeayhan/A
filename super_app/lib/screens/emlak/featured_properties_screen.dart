import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/providers/emlak_provider.dart';

class FeaturedPropertiesScreen extends ConsumerWidget {
  final String? city;
  const FeaturedPropertiesScreen({super.key, this.city});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final propertiesAsync = ref.watch(featuredAndPremiumProvider(city));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: EmlakColors.background(isDark),
        appBar: AppBar(
          backgroundColor: EmlakColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Öne Çıkan İlanlar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: propertiesAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: EmlakColors.primary),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: EmlakColors.textTertiary(isDark)),
                const SizedBox(height: 12),
                Text('Bir hata oluştu', style: TextStyle(color: EmlakColors.textPrimary(isDark))),
              ],
            ),
          ),
          data: (properties) {
            if (properties.isEmpty) {
              return _buildEmptyState(isDark);
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(featuredAndPremiumProvider(city));
              },
              color: EmlakColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPropertyCard(context, properties[index], isDark),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 64,
            color: EmlakColors.textTertiary(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz öne çıkan ilan yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: EmlakColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Premium ve öne çıkan ilanlar burada görünecek',
            style: TextStyle(
              fontSize: 14,
              color: EmlakColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Property property, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/emlak/property/${property.id}');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: EmlakColors.card(isDark),
            borderRadius: BorderRadius.circular(14),
            border: property.isPremium
                ? Border.all(color: EmlakColors.accent, width: 2)
                : property.isFeatured
                    ? Border.all(color: EmlakColors.accent.withValues(alpha: 0.5), width: 1.5)
                    : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: property.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: property.images.first,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              height: 200,
                              color: EmlakColors.surface(isDark),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: EmlakColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => Container(
                              height: 200,
                              color: EmlakColors.surface(isDark),
                              child: Icon(Icons.home, size: 48, color: EmlakColors.textTertiary(isDark)),
                            ),
                          )
                        : Container(
                            height: 200,
                            color: EmlakColors.surface(isDark),
                            child: Icon(Icons.home, size: 48, color: EmlakColors.textTertiary(isDark)),
                          ),
                  ),
                  // Badges
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        _buildBadge(property.listingType.label, property.listingType.color),
                        if (property.isPremium) ...[
                          const SizedBox(width: 6),
                          _buildBadge('Premium', EmlakColors.accent, icon: Icons.workspace_premium_rounded),
                        ] else if (property.isFeatured) ...[
                          const SizedBox(width: 6),
                          _buildBadge('Öne Çıkan', EmlakColors.accent.withValues(alpha: 0.8), icon: Icons.star_rounded),
                        ],
                      ],
                    ),
                  ),
                  // Image count
                  if (property.images.length > 1)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${property.images.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Emlakci
                  if (property.agent?.isRealtor == true)
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: EmlakColors.primary.withValues(alpha: 0.1),
                              backgroundImage: property.agent?.imageUrl != null
                                  ? NetworkImage(property.agent!.imageUrl!)
                                  : null,
                              child: property.agent?.imageUrl == null
                                  ? Icon(Icons.business, size: 16, color: EmlakColors.primary)
                                  : null,
                            ),
                            if (property.agent?.isVerified == true)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(1),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.verified, size: 10, color: EmlakColors.primary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: EmlakColors.textPrimary(isDark),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: EmlakColors.textSecondary(isDark)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location.shortAddress,
                            style: TextStyle(
                              fontSize: 13,
                              color: EmlakColors.textSecondary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Features + Price
                    Row(
                      children: [
                        _buildSmallFeature(Icons.bed_outlined, '${property.rooms}+1', isDark),
                        const SizedBox(width: 12),
                        _buildSmallFeature(Icons.bathtub_outlined, '${property.bathrooms}', isDark),
                        const SizedBox(width: 12),
                        _buildSmallFeature(Icons.square_foot, '${property.squareMeters}m²', isDark),
                        const Spacer(),
                        Text(
                          property.fullFormattedPrice,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: EmlakColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallFeature(IconData icon, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: EmlakColors.textTertiary(isDark)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: EmlakColors.textSecondary(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
