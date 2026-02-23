import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/realtor_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Analytics Screen - Extracted from monolith _buildPerformanceContent
/// Shows property performance analytics with time filtering, stat cards,
/// performance tables, top/low-performing properties, trend graphs, and promotions.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedTimePeriod = 1; // 0: 7 gun, 1: 30 gun, 2: 3 ay
  String? _selectedPropertyForGraph;

  int _getSelectedDays() {
    switch (_selectedTimePeriod) {
      case 0:
        return 7;
      case 1:
        return 30;
      case 2:
        return 90;
      default:
        return 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _getSelectedDays();
    final performanceStats = ref.watch(propertyPerformanceStatsProvider(days));

    return performanceStats.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                'Veriler yuklenirken hata olustu: $error',
                style: TextStyle(color: AppColors.textSecondary(isDark)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(propertyPerformanceStatsProvider(days)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final propertyStatsList =
            (data['properties'] as List<Map<String, dynamic>>?) ?? [];
        final totals = (data['totals'] as Map<String, dynamic>?) ?? {};
        final previousTotals =
            (data['previousTotals'] as Map<String, dynamic>?) ?? {};

        // Toplam istatistikler
        final totalViews = (totals['views'] as int?) ?? 0;
        final totalFavorites = (totals['favorites'] as int?) ?? 0;
        final totalAppointments = (totals['appointments'] as int?) ?? 0;
        final prevTotalViews = (previousTotals['views'] as int?) ?? 0;
        final prevTotalFavorites = (previousTotals['favorites'] as int?) ?? 0;
        final prevTotalAppointments =
            (previousTotals['appointments'] as int?) ?? 0;

        // Degisim oranlari
        final viewsChange = prevTotalViews > 0
            ? ((totalViews - prevTotalViews) / prevTotalViews * 100)
            : 0.0;
        final favoritesChange = prevTotalFavorites > 0
            ? ((totalFavorites - prevTotalFavorites) /
                prevTotalFavorites *
                100)
            : 0.0;
        final appointmentsChange = prevTotalAppointments > 0
            ? ((totalAppointments - prevTotalAppointments) /
                prevTotalAppointments *
                100)
            : 0.0;
        final conversionRate =
            totalViews > 0 ? (totalAppointments / totalViews * 100) : 0.0;
        final prevConversionRate = prevTotalViews > 0
            ? (prevTotalAppointments / prevTotalViews * 100)
            : 0.0;
        final conversionChange = prevConversionRate > 0
            ? ((conversionRate - prevConversionRate) /
                prevConversionRate *
                100)
            : 0.0;

        // En iyi 5 ve dusuk performansli ilanlar
        final topPropertyStats = propertyStatsList.take(5).toList();
        final lowPerformingStats = propertyStatsList
            .where((p) => (p['views'] as int? ?? 0) < 10)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zaman Filtresi
              _buildTimeFilterChips(isDark),
              const SizedBox(height: 24),

              // Ozet Kartlari
              _buildSectionTitle('Performans Ozeti', isDark),
              const SizedBox(height: 16),
              _buildPerformanceSummaryCards(
                isDark: isDark,
                totalViews: totalViews,
                totalFavorites: totalFavorites,
                totalAppointments: totalAppointments,
                conversionRate: conversionRate,
                viewsChange: viewsChange,
                favoritesChange: favoritesChange,
                appointmentsChange: appointmentsChange,
                conversionChange: conversionChange,
              ),

              const SizedBox(height: 32),

              // Ilan Bazli Performans Tablosu
              _buildSectionTitle('Ilan Bazli Performans', isDark),
              const SizedBox(height: 16),
              _buildPropertyPerformanceTable(propertyStatsList, isDark),

              const SizedBox(height: 32),

              // En Iyi 5 Ilan
              if (topPropertyStats.isNotEmpty) ...[
                _buildSectionTitle(
                    'En Iyi Performans Gosteren Ilanlar', isDark),
                const SizedBox(height: 16),
                _buildTopPropertiesSection(topPropertyStats, isDark),
                const SizedBox(height: 32),
              ],

              // Dusuk Performansli Ilanlar
              if (lowPerformingStats.isNotEmpty) ...[
                _buildSectionTitle('Dikkat Gerektiren Ilanlar', isDark),
                const SizedBox(height: 16),
                _buildLowPerformingSection(lowPerformingStats, isDark),
                const SizedBox(height: 32),
              ],

              // Grafik Alani
              if (propertyStatsList.isNotEmpty) ...[
                _buildSectionTitle('Goruntülenme Trendi', isDark),
                const SizedBox(height: 16),
                _buildViewsGraphSection(propertyStatsList, isDark),
                const SizedBox(height: 32),
              ],

              // Aktif Promosyonlar
              _buildSectionTitle('Aktif Promosyonlar', isDark),
              const SizedBox(height: 16),
              _buildActivePromotionsSection(isDark),
            ],
          ),
        );
      },
    );
  }

  // ==================== SECTION TITLE ====================

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textPrimary(isDark),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ==================== TIME FILTER CHIPS ====================

  Widget _buildTimeFilterChips(bool isDark) {
    final periods = ['7 Gun', '30 Gun', '3 Ay'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today,
              color: AppColors.textSecondary(isDark), size: 20),
          const SizedBox(width: 12),
          Text(
            'Donem:',
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          ...List.generate(periods.length, (index) {
            final isSelected = _selectedTimePeriod == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(periods[index]),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedTimePeriod = index);
                  }
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textSecondary(isDark),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor:
                    isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                side: BorderSide.none,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== SUMMARY CARDS ====================

  Widget _buildPerformanceSummaryCards({
    required bool isDark,
    required int totalViews,
    required int totalFavorites,
    required int totalAppointments,
    required double conversionRate,
    required double viewsChange,
    required double favoritesChange,
    required double appointmentsChange,
    required double conversionChange,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildStatCardWithChange(
              'Toplam Goruntülenme',
              '$totalViews',
              Icons.visibility_rounded,
              const Color(0xFF3B82F6),
              viewsChange,
              isDark,
            ),
            _buildStatCardWithChange(
              'Favorilere Eklenme',
              '$totalFavorites',
              Icons.favorite_rounded,
              const Color(0xFFEF4444),
              favoritesChange,
              isDark,
            ),
            _buildStatCardWithChange(
              'Randevu Talebi',
              '$totalAppointments',
              Icons.calendar_month_rounded,
              const Color(0xFF8B5CF6),
              appointmentsChange,
              isDark,
            ),
            _buildStatCardWithChange(
              'Donusum Orani',
              '%${conversionRate.toStringAsFixed(1)}',
              Icons.trending_up_rounded,
              AppColors.success,
              conversionChange,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCardWithChange(
    String title,
    String value,
    IconData icon,
    Color color,
    double change,
    bool isDark,
  ) {
    final isPositive = change >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(isDark)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color:
                          isPositive ? AppColors.success : AppColors.error,
                      size: 14,
                    ),
                    Text(
                      '${change.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color:
                            isPositive ? AppColors.success : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PERFORMANCE TABLE ====================

  Widget _buildPropertyPerformanceTable(
      List<Map<String, dynamic>> propertyStatsList, bool isDark) {
    if (propertyStatsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(isDark)),
        ),
        child: Center(
          child: Text(
            'Henuz aktif ilaniniz bulunmuyor',
            style: TextStyle(color: AppColors.textSecondary(isDark)),
          ),
        ),
      );
    }

    // Hide table on mobile, show cards instead
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          return _buildPropertyPerformanceMobileCards(
              propertyStatsList, isDark);
        }
        return _buildPropertyPerformanceDesktopTable(
            propertyStatsList, isDark);
      },
    );
  }

  Widget _buildPropertyPerformanceDesktopTable(
      List<Map<String, dynamic>> propertyStatsList, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Ilan',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(isDark)))),
                Expanded(
                    child: Text('Goruntülenme',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(isDark)),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('Favori',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(isDark)),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('Randevu',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(isDark)),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('Donusum',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(isDark)),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 80,
                    child: Text('Trend',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(isDark)),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 120,
                    child: Text('Islem',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(isDark)),
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border(isDark)),
          // Table Rows
          ...propertyStatsList.take(10).map((propStats) {
            final views = propStats['views'] as int? ?? 0;
            final favorites = propStats['favorites'] as int? ?? 0;
            final appointments = propStats['appointments'] as int? ?? 0;
            final conversion =
                views > 0 ? (appointments / views * 100) : 0.0;
            final prevViews = propStats['previousViews'] as int? ?? 0;
            final trend = prevViews > 0
                ? ((views - prevViews) / prevViews * 100)
                : 0.0;

            return _buildPropertyTableRow(
                propStats, views, favorites, appointments, conversion, trend,
                isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildPropertyTableRow(
    Map<String, dynamic> propStats,
    int views,
    int favorites,
    int appointments,
    double conversion,
    double trend,
    bool isDark,
  ) {
    final propertyId = propStats['id'] as String? ?? '';
    final images = (propStats['images'] as List?)?.cast<String>() ?? [];
    final title = propStats['title'] as String? ?? '';
    final district = propStats['district'] as String? ?? '';
    final city = propStats['city'] as String? ?? '';
    final isPositiveTrend = trend >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border(isDark))),
      ),
      child: Row(
        children: [
          // Ilan Bilgisi
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildImagePlaceholder(48),
                        )
                      : _buildImagePlaceholder(48),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(isDark)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$district, $city',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Goruntülenme
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility,
                    size: 14, color: Color(0xFF3B82F6)),
                const SizedBox(width: 4),
                Text('$views',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark))),
              ],
            ),
          ),
          // Favori
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Text('$favorites',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark))),
              ],
            ),
          ),
          // Randevu
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 4),
                Text('$appointments',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark))),
              ],
            ),
          ),
          // Donusum
          Expanded(
            child: Text(
              '%${conversion.toStringAsFixed(1)}',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(isDark)),
              textAlign: TextAlign.center,
            ),
          ),
          // Trend
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositiveTrend
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPositiveTrend
                        ? Icons.trending_up
                        : Icons.trending_down,
                    size: 14,
                    color: isPositiveTrend
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${trend.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPositiveTrend
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Promosyon butonu
          SizedBox(
            width: 120,
            child: Center(
              child: _buildPromotionButton(
                propertyId: propertyId,
                title: title,
                isFeatured: propStats['is_featured'] as bool? ?? false,
                isPremium: propStats['is_premium'] as bool? ?? false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyPerformanceMobileCards(
      List<Map<String, dynamic>> propertyStatsList, bool isDark) {
    return Column(
      children: propertyStatsList.take(10).map((propStats) {
        final views = propStats['views'] as int? ?? 0;
        final favorites = propStats['favorites'] as int? ?? 0;
        final appointments = propStats['appointments'] as int? ?? 0;
        final images = (propStats['images'] as List?)?.cast<String>() ?? [];
        final title = propStats['title'] as String? ?? '';
        final district = propStats['district'] as String? ?? '';
        final city = propStats['city'] as String? ?? '';
        final propertyId = propStats['id'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: images.isNotEmpty
                        ? Image.network(
                            images.first,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _buildImagePlaceholder(48),
                          )
                        : _buildImagePlaceholder(48),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(isDark)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text('$district, $city',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(isDark))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(
                      Icons.visibility, '$views', const Color(0xFF3B82F6)),
                  _buildMiniStat(
                      Icons.favorite, '$favorites', const Color(0xFFEF4444)),
                  _buildMiniStat(Icons.calendar_today, '$appointments',
                      const Color(0xFF8B5CF6)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _buildPromotionButton(
                  propertyId: propertyId,
                  title: title,
                  isFeatured: propStats['is_featured'] as bool? ?? false,
                  isPremium: propStats['is_premium'] as bool? ?? false,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==================== TOP PROPERTIES ====================

  Widget _buildTopPropertiesSection(
      List<Map<String, dynamic>> topPropertyStats, bool isDark) {
    if (topPropertyStats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.1 : 0.05),
            const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.1 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: topPropertyStats.asMap().entries.map((entry) {
          final index = entry.key;
          final propStats = entry.value;
          final propertyId = propStats['id'] as String? ?? '';
          final images =
              (propStats['images'] as List?)?.cast<String>() ?? [];
          final title = propStats['title'] as String? ?? '';
          final district = propStats['district'] as String? ?? '';
          final city = propStats['city'] as String? ?? '';
          final views = propStats['views'] as int? ?? 0;
          final favorites = propStats['favorites'] as int? ?? 0;
          final appointments = propStats['appointments'] as int? ?? 0;

          return Container(
            margin: EdgeInsets.only(
                bottom: index < topPropertyStats.length - 1 ? 12 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Ranking badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: index == 0
                          ? [
                              const Color(0xFFFFD700),
                              const Color(0xFFFFA500)
                            ]
                          : index == 1
                              ? [
                                  const Color(0xFFC0C0C0),
                                  const Color(0xFF808080)
                                ]
                              : index == 2
                                  ? [
                                      const Color(0xFFCD7F32),
                                      const Color(0xFF8B4513)
                                    ]
                                  : [
                                      const Color(0xFF3B82F6),
                                      const Color(0xFF3B82F6)
                                    ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _buildImagePlaceholder(56),
                        )
                      : _buildImagePlaceholder(56),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(isDark)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$district, $city',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
                // Stats and One Cikar button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMiniStat(Icons.visibility, '$views',
                            const Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        _buildMiniStat(Icons.favorite, '$favorites',
                            const Color(0xFFEF4444)),
                        const SizedBox(width: 12),
                        _buildMiniStat(Icons.calendar_today,
                            '$appointments', const Color(0xFF8B5CF6)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPromotionButton(
                      propertyId: propertyId,
                      title: title,
                      isFeatured: propStats['is_featured'] as bool? ?? false,
                      isPremium: propStats['is_premium'] as bool? ?? false,
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== LOW PERFORMING PROPERTIES ====================

  Widget _buildLowPerformingSection(
      List<Map<String, dynamic>> lowPerformingStats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.2)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? const Color(0xFFFCD34D).withValues(alpha: 0.4)
                : const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dusuk Performansli Ilanlar',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFFCD34D)
                            : const Color(0xFF92400E)),
                  ),
                  Text(
                    'Bu ilanlar son donemde az ilgi gordu',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFB45309)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...lowPerformingStats.take(3).map((propStats) {
            final propertyId = propStats['id'] as String? ?? '';
            final images =
                (propStats['images'] as List?)?.cast<String>() ?? [];
            final title = propStats['title'] as String? ?? '';
            final views = propStats['views'] as int? ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card(isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: images.isNotEmpty
                        ? Image.network(
                            images.first,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _buildImagePlaceholder(40),
                          )
                        : _buildImagePlaceholder(40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: AppColors.textPrimary(isDark)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Sadece $views goruntülenme',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  _buildPromotionButton(
                    propertyId: propertyId,
                    title: title,
                    isFeatured: propStats['is_featured'] as bool? ?? false,
                    isPremium: propStats['is_premium'] as bool? ?? false,
                    fontSize: 12,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== VIEWS GRAPH ====================

  Widget _buildViewsGraphSection(
      List<Map<String, dynamic>> propertyStatsList, bool isDark) {
    final selectedId = _selectedPropertyForGraph ??
        (propertyStatsList.isNotEmpty
            ? propertyStatsList.first['id'] as String?
            : null);

    if (propertyStatsList.isEmpty || selectedId == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(isDark)),
        ),
        child: Center(
          child: Text(
            'Grafik icin ilan bulunamadi',
            style: TextStyle(color: AppColors.textSecondary(isDark)),
          ),
        ),
      );
    }

    final selectedPropStats = propertyStatsList.firstWhere(
      (p) => p['id'] == selectedId,
      orElse: () => propertyStatsList.first,
    );

    final images =
        (selectedPropStats['images'] as List?)?.cast<String>() ?? [];
    final title = selectedPropStats['title'] as String? ?? '';
    final district = selectedPropStats['district'] as String? ?? '';
    final city = selectedPropStats['city'] as String? ?? '';
    final dailyViews =
        (selectedPropStats['dailyViews'] as List?)?.cast<int>() ??
            List.filled(7, 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property selector dropdown
          Row(
            children: [
              Text('Ilan:',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(isDark))),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: AppColors.card(isDark),
                    style: TextStyle(color: AppColors.textPrimary(isDark)),
                    items:
                        propertyStatsList.take(10).map((propStats) {
                      return DropdownMenuItem<String>(
                        value: propStats['id'] as String?,
                        child: Text(
                          propStats['title'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPropertyForGraph = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Selected property info
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: images.isNotEmpty
                    ? Image.network(
                        images.first,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _buildImagePlaceholder(60),
                      )
                    : _buildImagePlaceholder(60),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.textPrimary(isDark)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$district, $city',
                      style: TextStyle(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Bar Chart
          Text(
            'Son 7 Gunluk Goruntülenme',
            style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(isDark),
                fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value =
                    dailyViews.length > index ? dailyViews[index] : 0;
                final maxValue = dailyViews.isNotEmpty
                    ? dailyViews.reduce((a, b) => a > b ? a : b)
                    : 1;
                final heightPercent =
                    maxValue > 0 ? value / maxValue : 0.0;
                final days = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(isDark)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 80 * heightPercent,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[index],
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(isDark)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIVE PROMOTIONS ====================

  Widget _buildActivePromotionsSection(bool isDark) {
    final activePromotions = ref.watch(activePromotionsProvider);

    return activePromotions.when(
      data: (promotions) {
        if (promotions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(isDark)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 48,
                  color: AppColors.textMuted(isDark),
                ),
                const SizedBox(height: 12),
                Text(
                  'Aktif promosyonunuz bulunmuyor',
                  style: TextStyle(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ilanlarinizi one cikararak daha fazla goruntülenme alabilirsiniz',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: promotions.map((promo) {
            final propertyTitle =
                promo['property_title'] as String? ?? 'Ilan';
            final promotionType =
                promo['promotion_type'] as String? ?? 'featured';
            final startDate = promo['start_date'] != null
                ? DateTime.parse(promo['start_date'])
                : DateTime.now();
            final endDate = promo['end_date'] != null
                ? DateTime.parse(promo['end_date'])
                : DateTime.now();
            final now = DateTime.now();
            final remainingDays = endDate.difference(now).inDays;
            final remainingHours = endDate.difference(now).inHours % 24;
            final totalDays = endDate.difference(startDate).inDays;
            final elapsedDays = now.difference(startDate).inDays;
            final progress = totalDays > 0
                ? (elapsedDays / totalDays).clamp(0.0, 1.0)
                : 0.0;

            final isPremium = promotionType == 'premium';
            final propertyImages =
                (promo['property_images'] as List?)?.cast<String>() ?? [];
            final viewsBefore = promo['views_before'] as int? ?? 0;
            final viewsDuring = promo['views_during'] as int? ?? 0;
            final viewsIncrease = viewsBefore > 0
                ? ((viewsDuring - viewsBefore) / viewsBefore * 100)
                    .toStringAsFixed(0)
                : '0';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPremium
                      ? isDark
                          ? [
                              const Color(0xFF78350F).withValues(alpha: 0.3),
                              const Color(0xFF92400E).withValues(alpha: 0.2)
                            ]
                          : [
                              const Color(0xFFFFFBEB),
                              const Color(0xFFFEF3C7)
                            ]
                      : isDark
                          ? [
                              const Color(0xFF0C4A6E).withValues(alpha: 0.3),
                              const Color(0xFF075985).withValues(alpha: 0.2)
                            ]
                          : [
                              const Color(0xFFF0F9FF),
                              const Color(0xFFE0F2FE)
                            ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPremium
                      ? const Color(0xFFFCD34D)
                          .withValues(alpha: isDark ? 0.4 : 1.0)
                      : const Color(0xFF7DD3FC)
                          .withValues(alpha: isDark ? 0.4 : 1.0),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isPremium
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF0EA5E9))
                        .withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top section - property info and type
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: propertyImages.isNotEmpty
                              ? Image.network(
                                  propertyImages.first,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _buildImagePlaceholder(64),
                                )
                              : _buildImagePlaceholder(64),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isPremium
                                        ? [
                                            const Color(0xFFFFD700),
                                            const Color(0xFFFFA500)
                                          ]
                                        : [
                                            const Color(0xFF3B82F6),
                                            const Color(0xFF0EA5E9)
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPremium
                                          ? Icons.workspace_premium
                                          : Icons.star,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isPremium ? 'Premium' : 'One Cikan',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                propertyTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textPrimary(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Remaining time
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.card(isDark),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                remainingDays > 0
                                    ? '$remainingDays'
                                    : '$remainingHours',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: remainingDays <= 2
                                      ? AppColors.error
                                      : AppColors.textPrimary(isDark),
                                ),
                              ),
                              Text(
                                remainingDays > 0
                                    ? 'gun kaldi'
                                    : 'saat kaldi',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Promosyon suresi',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}% tamamlandi',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: AppColors.card(isDark),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isPremium
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stats
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card(isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPromoStatItem(
                          'Promosyon Oncesi',
                          '$viewsBefore goruntülenme',
                          Icons.visibility_outlined,
                          AppColors.textSecondary(isDark),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.border(isDark),
                        ),
                        _buildPromoStatItem(
                          'Promosyon Suresince',
                          '$viewsDuring goruntülenme',
                          Icons.trending_up,
                          AppColors.success,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.border(isDark),
                        ),
                        _buildPromoStatItem(
                          'Artis',
                          '%$viewsIncrease',
                          Icons.arrow_upward,
                          int.parse(viewsIncrease) > 0
                              ? AppColors.success
                              : AppColors.textSecondary(isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.2)
              : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? const Color(0xFFFCA5A5).withValues(alpha: 0.3)
                  : const Color(0xFFFECACA)),
        ),
        child: Text(
          'Promosyonlar yuklenirken hata: $e',
          style: TextStyle(
              color: isDark
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFDC2626)),
        ),
      ),
    );
  }

  // ==================== PROMOTION MODAL ====================

  Future<void> _showPromotionModal(
      String propertyId, String propertyTitle) async {
    final realtorService = ref.read(realtorServiceProvider);

    final prices = await realtorService.getPromotionPrices();
    final activePromotion =
        await realtorService.getActivePromotion(propertyId);

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final featuredPrices =
        prices.where((p) => p['promotion_type'] == 'featured').toList();
    final premiumPrices =
        prices.where((p) => p['promotion_type'] == 'premium').toList();

    String selectedType = 'featured';
    int selectedDuration = 7;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedPrices =
              selectedType == 'featured' ? featuredPrices : premiumPrices;
          final selectedPrice = selectedPrices.firstWhere(
            (p) => p['duration_days'] == selectedDuration,
            orElse: () =>
                selectedPrices.isNotEmpty ? selectedPrices.first : {'price': 0},
          );
          final originalPrice =
              (selectedPrice['price'] as num?)?.toDouble() ?? 0;
          final discountedPrice =
              (selectedPrice['discounted_price'] as num?)?.toDouble();
          final price = discountedPrice ?? originalPrice;

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: AppColors.card(isDark),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.rocket_launch_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ilani One Cikar',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary(isDark)),
                              ),
                              Text(
                                propertyTitle,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary(isDark)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: Icon(Icons.close,
                              color: AppColors.textSecondary(isDark)),
                        ),
                      ],
                    ),

                    // Active promotion warning
                    if (activePromotion != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF166534).withValues(alpha: 0.2)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF22C55E)
                                  .withValues(alpha: isDark ? 0.4 : 1.0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF22C55E)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Aktif ${activePromotion['promotion_type'] == 'premium' ? 'Premium' : 'One Cikarma'} Promosyonu',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFF4ADE80)
                                            : const Color(0xFF166534)),
                                  ),
                                  Text(
                                    'Bitis: ${_formatDate(activePromotion['expires_at'])}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? const Color(0xFF4ADE80)
                                            : const Color(0xFF166534)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Promotion type selection
                    Text(
                      'Promosyon Tipi',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPromotionTypeCard(
                            title: 'One Cikan',
                            description: 'Ana sayfada carousel\'da gosterilir',
                            icon: Icons.star_rounded,
                            color: const Color(0xFF3B82F6),
                            isSelected: selectedType == 'featured',
                            isDark: isDark,
                            onTap: () =>
                                setDialogState(() => selectedType = 'featured'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPromotionTypeCard(
                            title: 'Premium',
                            description:
                                'One cikan + altin rozet + ust sira',
                            icon: Icons.workspace_premium_rounded,
                            color: const Color(0xFFF59E0B),
                            isSelected: selectedType == 'premium',
                            isDark: isDark,
                            onTap: () =>
                                setDialogState(() => selectedType = 'premium'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Duration selection
                    Text(
                      'Sure',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDurationCard(
                            days: 7,
                            price: selectedPrices.firstWhere(
                                (p) => p['duration_days'] == 7,
                                orElse: () => {'price': 0})['price'],
                            discountedPrice: selectedPrices.firstWhere(
                                (p) => p['duration_days'] == 7,
                                orElse: () => {})['discounted_price'],
                            isSelected: selectedDuration == 7,
                            isDark: isDark,
                            onTap: () =>
                                setDialogState(() => selectedDuration = 7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDurationCard(
                            days: 30,
                            price: selectedPrices.firstWhere(
                                (p) => p['duration_days'] == 30,
                                orElse: () => {'price': 0})['price'],
                            discountedPrice: selectedPrices.firstWhere(
                                (p) => p['duration_days'] == 30,
                                orElse: () => {})['discounted_price'],
                            isSelected: selectedDuration == 30,
                            isPopular: true,
                            isDark: isDark,
                            onTap: () =>
                                setDialogState(() => selectedDuration = 30),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Benefits
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu Pakette Neler Var?',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(isDark),
                                fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          _buildBenefitRow(Icons.visibility,
                              'Ana sayfada one cikan bolumde gosterilir'),
                          if (selectedType == 'premium') ...[
                            _buildBenefitRow(Icons.workspace_premium,
                                'Altin Premium rozeti'),
                            _buildBenefitRow(Icons.arrow_upward,
                                'Arama sonuclarinda her zaman ustte'),
                            _buildBenefitRow(Icons.star,
                                'Detay sayfasinda sponsor etiketi'),
                          ],
                          _buildBenefitRow(
                              Icons.trending_up,
                              'Ortalama %${selectedType == 'premium' ? '300' : '150'} daha fazla goruntülenme'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Total and purchase button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: selectedType == 'premium'
                              ? [
                                  const Color(0xFFF59E0B),
                                  const Color(0xFFEF4444)
                                ]
                              : [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF8B5CF6)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Toplam',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                                if (discountedPrice != null) ...[
                                  Text(
                                    '${originalPrice.toStringAsFixed(0)} TL',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                                Text(
                                  '${price.toStringAsFixed(0)} TL',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '$selectedDuration gun',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    setDialogState(() => isLoading = true);

                                    final result =
                                        await realtorService.createPromotion(
                                      propertyId: propertyId,
                                      promotionType: selectedType,
                                      durationDays: selectedDuration,
                                      amountPaid: price,
                                      paymentMethod: 'demo',
                                    );

                                    if (!mounted) return;

                                    if (result != null) {
                                      Navigator.pop(dialogContext);
                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${selectedType == 'premium' ? 'Premium' : 'One Cikarma'} promosyonu basariyla aktif edildi!'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                      ref.invalidate(
                                          propertyPerformanceStatsProvider);
                                      ref.invalidate(activePromotionsProvider);
                                    } else {
                                      setDialogState(
                                          () => isLoading = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                                'Promosyon olusturulamadi. Lutfen tekrar deneyin.'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: selectedType == 'premium'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF3B82F6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.flash_on_rounded),
                                      SizedBox(width: 8),
                                      Text('Simdi Baslat',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: color, fontSize: 12)),
      ],
    );
  }

  /// Promosyon durumuna göre akıllı buton:
  /// - Premium → "Premium" badge (yeşil, tıklanamaz)
  /// - Featured → "Premium'a Yukselt" butonu (altın)
  /// - Hiçbiri → "One Cikar" butonu (turuncu)
  Widget _buildPromotionButton({
    required String propertyId,
    required String title,
    required bool isFeatured,
    required bool isPremium,
    double fontSize = 11,
  }) {
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded,
                size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Premium',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (isFeatured) {
      return TextButton(
        onPressed: () => _showPromotionModal(propertyId, title),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          backgroundColor: const Color(0xFFF59E0B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_upward_rounded,
                size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              'Premium\'a Yukselt',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return TextButton(
      onPressed: () => _showPromotionModal(propertyId, title),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        'One Cikar',
        style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildPromoStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textMuted(
                Theme.of(context).brightness == Brightness.dark),
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : AppColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border(isDark),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? color : AppColors.textSecondary(isDark),
                size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary(isDark)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard({
    required int days,
    required dynamic price,
    dynamic discountedPrice,
    required bool isSelected,
    required bool isDark,
    bool isPopular = false,
    required VoidCallback onTap,
  }) {
    final originalPrice = (price as num?)?.toDouble() ?? 0;
    final discount = (discountedPrice as num?)?.toDouble();
    final effectivePrice = discount ?? originalPrice;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
              : AppColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : AppColors.border(isDark),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Text(
                  '$days Gun',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                if (discount != null) ...[
                  Text(
                    '${originalPrice.toStringAsFixed(0)} TL',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted(isDark),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    '${discount.toStringAsFixed(0)} TL',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF22C55E),
                    ),
                  ),
                ] else
                  Text(
                    '${originalPrice.toStringAsFixed(0)} TL',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : AppColors.textSecondary(isDark),
                    ),
                  ),
                if (days == 30) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${(effectivePrice / 30).toStringAsFixed(2)} TL/gun',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(isDark)),
                  ),
                ],
              ],
            ),
            if (isPopular)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Populer',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(
                      Theme.of(context).brightness == Brightness.dark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.border(isDark),
        borderRadius: BorderRadius.circular(size > 50 ? 8 : 6),
      ),
      child: Icon(Icons.home,
          color: AppColors.textMuted(isDark), size: size * 0.5),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
