import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/rental/rental_models.dart';

Widget buildCarSpec(IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, size: 14, color: Colors.white60),
      const SizedBox(width: 4),
      Text(text,
          style: const TextStyle(fontSize: 12, color: Colors.white60)),
    ],
  );
}

Widget buildCarChip(ThemeData theme, IconData icon, String text) {
  return Container(
    padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

Widget buildFeaturedCarCard(
  RentalCar car,
  ThemeData theme, {
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Car Image
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: car.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                  memCacheHeight: 240,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[900],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.directions_car,
                      size: 80,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Company Badge
              if (car.companyName != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (car.companyLogo != null && car.companyLogo!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: car.companyLogo!,
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.business,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          )
                        else
                          const Icon(Icons.business, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          car.companyName!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Premium Badge
              if (car.isPremium)
                Positioned(
                  top: car.companyName != null ? 52 : 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.black, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'PREMIUM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Discount Badge
              if (car.discountPercentage != null &&
                  car.discountPercentage! > 0)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '-${car.discountPercentage!.toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Car Info
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        buildCarSpec(Icons.speed, car.transmissionName),
                        const SizedBox(width: 12),
                        buildCarSpec(
                            Icons.local_gas_station, car.fuelTypeName),
                        const SizedBox(width: 12),
                        buildCarSpec(Icons.person, '${car.seats} Kisi'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rating
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              car.rating.toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              ' (${car.reviewCount})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        // Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (car.discountPercentage != null &&
                                car.discountPercentage! > 0)
                              Text(
                                '\u20BA${car.dailyPrice.toInt()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              '\u20BA${car.discountedDailyPrice.toInt()}/gun',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
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
    ),
  );
}

Widget buildCarListItem(
  RentalCar car,
  ThemeData theme,
  int index, {
  required VoidCallback onTap,
}) {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 400 + (index * 100)),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Transform.translate(
        offset: Offset(0, 30 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      );
    },
    child: Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Car Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: car.thumbnailUrl,
                  width: 100,
                  height: 75,
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                  memCacheHeight: 150,
                  placeholder: (_, __) => Container(
                    width: 100,
                    height: 75,
                    color: AppColors.surfaceLight,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 100,
                    height: 75,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.directions_car,
                        size: 40,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Car Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Company name
                    if (car.companyName != null)
                      Row(
                        children: [
                          Icon(Icons.business, size: 12,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            car.companyName!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    if (car.companyName != null)
                      const SizedBox(height: 4),
                    Text(
                      '${car.transmissionName} \u2022 ${car.fuelTypeName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          car.rating.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          ' (${car.reviewCount})',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\u20BA${car.discountedDailyPrice.toInt()}/gun',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget buildSearchResultCard(
  ThemeData theme,
  RentalCar car,
  int rentalDays,
  double totalPrice, {
  required VoidCallback onTap,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.05),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          // Car image and info
          Row(
            children: [
              // Car Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: car.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: car.thumbnailUrl,
                        width: 130,
                        height: 120,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        memCacheHeight: 180,
                        placeholder: (_, __) => Container(
                          width: 130,
                          height: 120,
                          color: AppColors.surfaceLight,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 130,
                          height: 120,
                          color: AppColors.surfaceLight,
                          child: const Icon(
                            Icons.directions_car,
                            color: AppColors.textSecondaryLight,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        width: 130,
                        height: 120,
                        color: AppColors.surfaceLight,
                        child: const Icon(
                          Icons.directions_car,
                          color:
                              AppColors.textSecondaryLight,
                          size: 40,
                        ),
                      ),
              ),

              // Car details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Company name
                      if (car.companyName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.business, size: 12,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                car.companyName!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              car.fullName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme
                                    .colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                          if (car.isPremium)
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors
                                    .primaryGradient,
                                borderRadius:
                                    BorderRadius.circular(
                                        6),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight:
                                      FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${car.rating}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme
                                  .colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            ' (${car.reviewCount})',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors
                                  .textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          buildCarChip(theme, Icons.speed,
                              car.transmissionName),
                          buildCarChip(
                              theme,
                              Icons.local_gas_station,
                              car.fuelTypeName),
                          buildCarChip(theme,
                              Icons.person, '${car.seats}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Price section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u20BA${car.discountedDailyPrice.toInt()}/gun',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme
                            .colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '\u20BA${totalPrice.toInt()}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color:
                                theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          ' / $rentalDays gun',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors
                                .textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Sec',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
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
