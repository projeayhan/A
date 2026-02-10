import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/rental/rental_models.dart';
import 'rental_car_cards.dart';

Widget buildSearchSummaryRow(
  ThemeData theme,
  IconData icon,
  Color color,
  String label,
  String value,
) {
  return Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 12),
      Text(
        '$label:',
        style: TextStyle(
            fontSize: 13, color: AppColors.textSecondaryLight),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.end,
        ),
      ),
    ],
  );
}

void showRentalSearchResults({
  required BuildContext context,
  required int rentalDays,
  required List<RentalCar> availableCars,
  required bool isPickupCustomAddress,
  required bool isDropoffCustomAddress,
  required String pickupCustomAddress,
  required String dropoffCustomAddress,
  required RentalLocation? selectedPickupLocation,
  required RentalLocation? selectedDropoffLocation,
  required DateTime pickupDate,
  required DateTime dropoffDate,
  required void Function(RentalCar car) onCarSelected,
}) {
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Arama Sonuclari',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme
                                    .colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${availableCars.length} arac bulundu \u2022 $rentalDays gun',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(context),
                        icon: Icon(Icons.close,
                            color: theme.colorScheme
                                .onSurfaceVariant),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Search summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color: theme.dividerColor),
                    ),
                    child: Column(
                      children: [
                        buildSearchSummaryRow(
                          theme,
                          isPickupCustomAddress
                              ? Icons.home
                              : Icons.location_on,
                          isPickupCustomAddress
                              ? theme.colorScheme.primary
                              : AppColors.success,
                          'Alis',
                          isPickupCustomAddress
                              ? pickupCustomAddress
                              : (selectedPickupLocation
                                      ?.name ??
                                  '-'),
                        ),
                        const SizedBox(height: 8),
                        buildSearchSummaryRow(
                          theme,
                          isDropoffCustomAddress
                              ? Icons.home
                              : Icons.flag,
                          isDropoffCustomAddress
                              ? theme.colorScheme.primary
                              : AppColors.error,
                          'Teslim',
                          isDropoffCustomAddress
                              ? dropoffCustomAddress
                              : (selectedDropoffLocation
                                      ?.name ??
                                  '-'),
                        ),
                        const SizedBox(height: 8),
                        buildSearchSummaryRow(
                          theme,
                          Icons.calendar_today,
                          theme.colorScheme.primary,
                          'Tarih',
                          '${pickupDate.day}/${pickupDate.month} - ${dropoffDate.day}/${dropoffDate.month}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Car list
            Expanded(
              child: availableCars.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.car_rental,
                            size: 64,
                            color: theme.dividerColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Uygun arac bulunamadi',
                            style: TextStyle(
                              fontSize: 18,
                              color: theme.colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Farkli tarih veya kategori deneyin',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors
                                  .textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      itemCount: availableCars.length,
                      itemBuilder: (context, index) {
                        final car = availableCars[index];
                        final totalPrice =
                            car.discountedDailyPrice *
                                rentalDays;
                        return buildSearchResultCard(
                          theme,
                          car,
                          rentalDays,
                          totalPrice,
                          onTap: () {
                            Navigator.pop(context);
                            onCarSelected(car);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
