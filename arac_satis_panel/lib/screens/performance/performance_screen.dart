import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/car_models.dart';
import '../../providers/dealer_provider.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/loading_skeleton.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  int _selectedTimePeriod = 1; // 0=7d, 1=30d, 2=90d
  String? _selectedListingForGraph;

  int get _days {
    switch (_selectedTimePeriod) {
      case 0:
        return 7;
      case 2:
        return 90;
      default:
        return 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsAsync = ref.watch(listingPerformanceStatsProvider(_days));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Filter Chips
          _buildTimeFilterChips(isDark),
          const SizedBox(height: 24),

          // Stats content
          statsAsync.when(
            data: (data) => _buildContent(context, isDark, data),
            loading: () => _buildLoadingState(),
            error: (_, _) => Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: CarSalesColors.textTertiary(isDark),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Veriler yuklenirken hata olustu',
                    style: TextStyle(
                      color: CarSalesColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(listingPerformanceStatsProvider(_days)),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChips(bool isDark) {
    final labels = ['7 Gun', '30 Gun', '3 Ay'];

    return Row(
      children: List.generate(labels.length, (index) {
        final isSelected = _selectedTimePeriod == index;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(labels[index]),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedTimePeriod = index;
                  _selectedListingForGraph = null;
                });
              }
            },
            selectedColor: CarSalesColors.primary,
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : CarSalesColors.textSecondary(isDark),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            backgroundColor: CarSalesColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected
                    ? CarSalesColors.primary
                    : CarSalesColors.border(isDark),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> data,
  ) {
    final listings =
        (data['listings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totals = (data['totals'] as Map<String, dynamic>?) ?? {};
    final previousTotals =
        (data['previousTotals'] as Map<String, dynamic>?) ?? {};

    final totalViews = totals['views'] as int? ?? 0;
    final totalFavorites = totals['favorites'] as int? ?? 0;
    final totalContacts = totals['contacts'] as int? ?? 0;
    final prevViews = previousTotals['views'] as int? ?? 0;
    final prevFavorites = previousTotals['favorites'] as int? ?? 0;
    final prevContacts = previousTotals['contacts'] as int? ?? 0;

    final viewsChange = prevViews > 0
        ? ((totalViews - prevViews) / prevViews * 100)
        : (totalViews > 0 ? 100.0 : 0.0);
    final favoritesChange = prevFavorites > 0
        ? ((totalFavorites - prevFavorites) / prevFavorites * 100)
        : (totalFavorites > 0 ? 100.0 : 0.0);
    final contactsChange = prevContacts > 0
        ? ((totalContacts - prevContacts) / prevContacts * 100)
        : (totalContacts > 0 ? 100.0 : 0.0);

    final conversionRate = totalViews > 0
        ? (totalContacts / totalViews * 100)
        : 0.0;

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            StatCard(
              title: 'Goruntuleme',
              value: '$totalViews',
              icon: Icons.visibility_outlined,
              color: CarSalesColors.primary,
              change: viewsChange,
            ),
            StatCard(
              title: 'Favori',
              value: '$totalFavorites',
              icon: Icons.favorite_outline,
              color: CarSalesColors.accent,
              change: favoritesChange,
            ),
            StatCard(
              title: 'Iletisim',
              value: '$totalContacts',
              icon: Icons.phone_outlined,
              color: CarSalesColors.success,
              change: contactsChange,
            ),
            StatCard(
              title: 'Donusum',
              value: '${conversionRate.toStringAsFixed(1)}%',
              icon: Icons.trending_up,
              color: CarSalesColors.secondary,
            ),
          ],
        ),
        const SizedBox(height: 32),

        if (listings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Henuz aktif ilaniniz yok.',
                style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
              ),
            ),
          )
        else ...[
          // Top 5 Listings
          _buildTopListings(isDark, listings),
          const SizedBox(height: 32),

          // Listing Performance Table/Cards
          Text(
            'Ilan Bazli Performans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CarSalesColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          isWide
              ? _buildPerformanceTable(isDark, listings)
              : _buildPerformanceCards(isDark, listings),
          const SizedBox(height: 32),

          // Low Performing Alerts
          _buildLowPerformingAlerts(isDark, listings),
          const SizedBox(height: 32),

          // Views Graph
          _buildViewsGraph(isDark, listings),
        ],
      ],
    );
  }

  Widget _buildTopListings(bool isDark, List<Map<String, dynamic>> listings) {
    final top5 = listings.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'En Iyi Performans',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: CarSalesColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(top5.length, (index) {
          final item = top5[index];
          final images = (item['images'] as List?)?.cast<String>() ?? [];
          final views = item['views'] as int? ?? 0;
          final rankColor = index == 0
              ? const Color(0xFFFFD700)
              : index == 1
              ? const Color(0xFFC0C0C0)
              : index == 2
              ? const Color(0xFFCD7F32)
              : CarSalesColors.textTertiary(isDark);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CarSalesColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CarSalesColors.border(isDark)),
            ),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
                          width: 48,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _buildMiniPlaceholder(isDark),
                        )
                      : _buildMiniPlaceholder(isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${item['brand_name'] ?? ''} ${item['model_name'] ?? ''} ${item['year'] ?? ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: CarSalesColors.textPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$views',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: CarSalesColors.textPrimary(isDark),
                      ),
                    ),
                    Text(
                      'goruntuleme',
                      style: TextStyle(
                        color: CarSalesColors.textTertiary(isDark),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPerformanceTable(
    bool isDark,
    List<Map<String, dynamic>> listings,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            CarSalesColors.surface(isDark),
          ),
          columns: [
            DataColumn(
              label: Text(
                'Ilan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CarSalesColors.textPrimary(isDark),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Goruntuleme',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CarSalesColors.textPrimary(isDark),
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Favori',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CarSalesColors.textPrimary(isDark),
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Iletisim',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CarSalesColors.textPrimary(isDark),
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Donusum',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CarSalesColors.textPrimary(isDark),
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Trend',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CarSalesColors.textPrimary(isDark),
                ),
              ),
            ),
          ],
          rows: listings.map((item) {
            final views = item['views'] as int? ?? 0;
            final favorites = item['favorites'] as int? ?? 0;
            final contacts = item['contacts'] as int? ?? 0;
            final prevViews = item['previousViews'] as int? ?? 0;
            final conversion = views > 0 ? (contacts / views * 100) : 0.0;
            final trend = prevViews > 0
                ? ((views - prevViews) / prevViews * 100)
                : (views > 0 ? 100.0 : 0.0);

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      '${item['brand_name'] ?? ''} ${item['model_name'] ?? ''} ${item['year'] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CarSalesColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '$views',
                    style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
                  ),
                ),
                DataCell(
                  Text(
                    '$favorites',
                    style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
                  ),
                ),
                DataCell(
                  Text(
                    '$contacts',
                    style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
                  ),
                ),
                DataCell(
                  Text(
                    '${conversion.toStringAsFixed(1)}%',
                    style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
                  ),
                ),
                DataCell(_buildTrendIndicator(trend)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPerformanceCards(
    bool isDark,
    List<Map<String, dynamic>> listings,
  ) {
    return Column(
      children: listings.map((item) {
        final images = (item['images'] as List?)?.cast<String>() ?? [];
        final views = item['views'] as int? ?? 0;
        final favorites = item['favorites'] as int? ?? 0;
        final contacts = item['contacts'] as int? ?? 0;
        final prevViews = item['previousViews'] as int? ?? 0;
        final conversion = views > 0 ? (contacts / views * 100) : 0.0;
        final trend = prevViews > 0
            ? ((views - prevViews) / prevViews * 100)
            : (views > 0 ? 100.0 : 0.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CarSalesColors.card(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CarSalesColors.border(isDark)),
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
                            width: 56,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _buildMiniPlaceholder(isDark),
                          )
                        : _buildMiniPlaceholder(isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${item['brand_name'] ?? ''} ${item['model_name'] ?? ''} ${item['year'] ?? ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: CarSalesColors.textPrimary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildTrendIndicator(trend),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(
                    Icons.visibility_outlined,
                    '$views',
                    'Goruntuleme',
                    isDark,
                  ),
                  _buildMiniStat(
                    Icons.favorite_outline,
                    '$favorites',
                    'Favori',
                    isDark,
                  ),
                  _buildMiniStat(
                    Icons.phone_outlined,
                    '$contacts',
                    'Iletisim',
                    isDark,
                  ),
                  _buildMiniStat(
                    Icons.trending_up,
                    '${conversion.toStringAsFixed(1)}%',
                    'Donusum',
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLowPerformingAlerts(
    bool isDark,
    List<Map<String, dynamic>> listings,
  ) {
    final lowPerforming = listings
        .where((l) => (l['views'] as int? ?? 0) < 10)
        .toList();

    if (lowPerforming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: CarSalesColors.secondary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Dusuk Performans Uyarilari',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CarSalesColors.textPrimary(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CarSalesColors.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CarSalesColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: lowPerforming.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: CarSalesColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"${item['brand_name'] ?? ''} ${item['model_name'] ?? ''}" - ${item['views'] ?? 0} goruntuleme',
                        style: TextStyle(
                          color: CarSalesColors.textPrimary(isDark),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildViewsGraph(bool isDark, List<Map<String, dynamic>> listings) {
    // Select listing for graph
    final selectedId =
        _selectedListingForGraph ?? listings.first['id'] as String;
    final selectedListing = listings.firstWhere(
      (l) => l['id'] == selectedId,
      orElse: () => listings.first,
    );
    final dailyViews =
        (selectedListing['dailyViews'] as List?)?.cast<int>() ??
        List.filled(7, 0);
    final maxViews = dailyViews.isEmpty
        ? 1
        : dailyViews
              .reduce((a, b) => max(a, b))
              .clamp(1, double.maxFinite.toInt());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gunluk Goruntuleme Grafigi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: CarSalesColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 12),

        // Listing selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: CarSalesColors.surface(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CarSalesColors.border(isDark)),
          ),
          child: DropdownButton<String>(
            value: selectedId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: CarSalesColors.card(isDark),
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 14,
            ),
            items: listings.map((l) {
              return DropdownMenuItem<String>(
                value: l['id'] as String,
                child: Text(
                  '${l['brand_name'] ?? ''} ${l['model_name'] ?? ''} ${l['year'] ?? ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedListingForGraph = value;
                });
              }
            },
          ),
        ),
        const SizedBox(height: 16),

        // Bar chart
        Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CarSalesColors.card(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CarSalesColors.border(isDark)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final value = index < dailyViews.length ? dailyViews[index] : 0;
              final barHeight = (value / maxViews) * 120;
              final dayLabel = _getDayLabel(6 - index);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CarSalesColors.textSecondary(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: barHeight.clamp(4.0, 120.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: CarSalesColors.primaryGradient,
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: CarSalesColors.textTertiary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  String _getDayLabel(int daysAgo) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    const days = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[date.weekday - 1];
  }

  Widget _buildTrendIndicator(double trend) {
    final isPositive = trend >= 0;
    final color = isPositive ? CarSalesColors.success : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: color,
          ),
          Text(
            '${trend.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: CarSalesColors.textTertiary(isDark)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: CarSalesColors.textPrimary(isDark),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: CarSalesColors.textTertiary(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPlaceholder(bool isDark) {
    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.directions_car,
        color: CarSalesColors.textTertiary(isDark),
        size: 18,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: const [
            SkeletonStatCard(),
            SkeletonStatCard(),
            SkeletonStatCard(),
            SkeletonStatCard(),
          ],
        ),
        const SizedBox(height: 24),
        const SkeletonCard(),
        const SkeletonCard(),
        const SkeletonCard(),
      ],
    );
  }
}
