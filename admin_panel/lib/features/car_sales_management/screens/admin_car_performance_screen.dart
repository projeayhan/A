import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/car_sales_management_providers.dart';

class AdminCarPerformanceScreen extends ConsumerStatefulWidget {
  final String dealerId;
  final String? dealerName;

  const AdminCarPerformanceScreen({
    super.key,
    required this.dealerId,
    this.dealerName,
  });

  @override
  ConsumerState<AdminCarPerformanceScreen> createState() => _AdminCarPerformanceScreenState();
}

class _AdminCarPerformanceScreenState extends ConsumerState<AdminCarPerformanceScreen> {
  String _selectedPeriod = '30';
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
  final _numberFormat = NumberFormat('#,###', 'tr_TR');

  final List<Map<String, String>> _periodChips = [
    {'key': '7', 'label': '7 gün'},
    {'key': '30', 'label': '30 gün'},
    {'key': '90', 'label': '90 gün'},
  ];

  @override
  Widget build(BuildContext context) {
    final params = (dealerId: widget.dealerId, period: _selectedPeriod);
    final performanceAsync = ref.watch(dealerPerformanceProvider(params));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: performanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Hata: $e', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(dealerPerformanceProvider(params)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (data) => _buildContent(data),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final allListings = List<Map<String, dynamic>>.from(data['listings'] ?? []);

    // Calculate totals
    int totalViews = (data['total_views'] as num?)?.toInt() ?? 0;
    int totalFavorites = (data['total_favorites'] as num?)?.toInt() ?? 0;
    int totalContacts = (data['total_contacts'] as num?)?.toInt() ?? 0;

    // Conversion rate
    final conversionRate = totalViews > 0
        ? ((totalContacts / totalViews) * 100).toStringAsFixed(1)
        : '0.0';

    // Top 5 performing listings by views
    final sortedByViews = List<Map<String, dynamic>>.from(allListings)
      ..sort((a, b) => ((b['view_count'] as num?) ?? 0).compareTo((a['view_count'] as num?) ?? 0));
    final top5 = sortedByViews.take(5).toList();

    // Low performance listings (0 views)
    final lowPerformance = allListings.where((l) {
      return ((l['view_count'] as num?)?.toInt() ?? 0) == 0;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    tooltip: 'Geri',
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.dealerName != null
                            ? '${widget.dealerName} - Performans'
                            : 'Galeri Performans',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Galeri ilan ve etkileşim istatistikleri',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildPeriodChips(),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      final params = (dealerId: widget.dealerId, period: _selectedPeriod);
                      ref.invalidate(dealerPerformanceProvider(params));
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Yenile'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 4 Stat Cards: Toplam Görüntülenme, Favoriler, İletişim Sayısı, Dönüşüm Oranı
          Row(
            children: [
              _buildSummaryCard(
                'Toplam Görüntülenme',
                _numberFormat.format(totalViews),
                Icons.visibility,
                AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Favoriler',
                _numberFormat.format(totalFavorites),
                Icons.favorite,
                AppColors.error,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'İletişim Sayısı',
                _numberFormat.format(totalContacts),
                Icons.phone,
                AppColors.success,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Dönüşüm Oranı',
                '%$conversionRate',
                Icons.trending_up,
                AppColors.warning,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Daily views trend area (placeholder)
          _buildDailyViewsTrend(allListings),

          const SizedBox(height: 32),

          // Top 5 performing listings
          if (top5.isNotEmpty) ...[
            _buildTop5Section(top5),
            const SizedBox(height: 32),
          ],

          // Low performance alerts
          if (lowPerformance.isNotEmpty) ...[
            _buildLowPerformanceAlerts(lowPerformance),
            const SizedBox(height: 32),
          ],

          // Full performance table
          _buildPerformanceTable(allListings),
        ],
      ),
    );
  }

  // ==================== PERIOD CHIPS ====================

  Widget _buildPeriodChips() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _periodChips.map((chip) {
          final isSelected = chip['key'] == _selectedPeriod;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = chip['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chip['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== SUMMARY CARD ====================

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DAILY VIEWS TREND ====================

  Widget _buildDailyViewsTrend(List<Map<String, dynamic>> listings) {
    final totalViews = listings.fold<int>(
      0,
      (sum, l) => sum + ((l['view_count'] as num?)?.toInt() ?? 0),
    );
    final days = int.tryParse(_selectedPeriod) ?? 30;
    final avgDailyViews = days > 0 ? totalViews / days : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günlük Görüntülenme Trendi',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Seçili dönemdeki günlük görüntülenme verileri',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              if (totalViews > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.show_chart, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Toplam: ${_numberFormat.format(totalViews)} | Ort: ${avgDailyViews.toStringAsFixed(1)} / gün',
                        style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline, color: AppColors.info, size: 22),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Günlük görüntüleme verisi henüz mevcut değil',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Günlük bazda detaylı görüntülenme istatistikleri yakında aktif edilecektir. '
                        'Şu an için toplam ve ortalama veriler yukarıda gösterilmektedir.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TOP 5 SECTION ====================

  Widget _buildTop5Section(List<Map<String, dynamic>> top5) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Text(
                'En İyi 5 İlan',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Görüntülenme sayısına göre en iyi performans gösteren ilanlar',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ...top5.asMap().entries.map((entry) {
            return _buildTop5Item(entry.key + 1, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildTop5Item(int rank, Map<String, dynamic> listing) {
    final brand = listing['brand_name'] ?? listing['brand'] ?? '';
    final model = listing['model_name'] ?? listing['model'] ?? '';
    final year = listing['year']?.toString() ?? '';
    final title = '$brand $model $year'.trim();
    final views = (listing['view_count'] as num?)?.toInt() ?? 0;
    final favorites = (listing['favorite_count'] as num?)?.toInt() ?? 0;
    final contacts = (listing['contact_count'] as num?)?.toInt() ?? 0;

    // Get image
    String? imageUrl;
    final images = listing['images'];
    if (images is List && images.isNotEmpty) {
      imageUrl = images[0] as String?;
    }

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 42,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildSmallPlaceholder(),
                    )
                  : _buildSmallPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : (listing['title'] ?? 'İsimsiz'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (listing['price'] != null)
                  Text(
                    _currencyFormat.format(listing['price']),
                    style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),

          // Stats
          _buildMiniStat(Icons.visibility, views, AppColors.info),
          const SizedBox(width: 16),
          _buildMiniStat(Icons.favorite, favorites, AppColors.error),
          const SizedBox(width: 16),
          _buildMiniStat(Icons.phone, contacts, AppColors.success),
        ],
      ),
    );
  }

  Widget _buildSmallPlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(Icons.directions_car, color: AppColors.textMuted, size: 18),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, int value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(
          _numberFormat.format(value),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ==================== LOW PERFORMANCE ALERTS ====================

  Widget _buildLowPerformanceAlerts(List<Map<String, dynamic>> listings) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Düşük Performans Uyarıları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${listings.length} ilan henüz hiç görüntülenmemiş',
                      style: const TextStyle(color: AppColors.warning, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...listings.take(5).map((listing) {
            final brand = listing['brand_name'] ?? listing['brand'] ?? '';
            final model = listing['model_name'] ?? listing['model'] ?? '';
            final year = listing['year']?.toString() ?? '';
            final title = '$brand $model $year'.trim();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off, size: 16, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.isNotEmpty ? title : (listing['title'] ?? 'İsimsiz'),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (listing['price'] != null)
                    Text(
                      _currencyFormat.format(listing['price']),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '0 görüntülenme',
                      style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (listings.length > 5) ...[
            const SizedBox(height: 8),
            Text(
              '... ve ${listings.length - 5} ilan daha',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== PERFORMANCE TABLE ====================

  Widget _buildPerformanceTable(List<Map<String, dynamic>> listings) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performans Tablosu',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tüm ilanların detaylı performans verileri',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('İLAN', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('FİYAT', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('GÖRÜNTÜLENME', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('FAVORİ', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('İLETİŞİM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('DURUM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (listings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Henüz ilan yok', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ...listings.map((listing) => _buildPerformanceRow(listing)),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(Map<String, dynamic> listing) {
    final brand = listing['brand_name'] ?? listing['brand'] ?? '';
    final model = listing['model_name'] ?? listing['model'] ?? '';
    final year = listing['year']?.toString() ?? '';
    final title = listing['title'] ?? '$brand $model $year';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$brand $model $year',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              listing['price'] != null ? _currencyFormat.format(listing['price']) : '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.visibility, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  _numberFormat.format(listing['view_count'] ?? 0),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.favorite, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  _numberFormat.format(listing['favorite_count'] ?? 0),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.phone, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  _numberFormat.format(listing['contact_count'] ?? 0),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(child: _buildStatusBadge(listing['status'] ?? 'pending')),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'active':
        color = AppColors.success;
        text = 'Aktif';
        break;
      case 'pending':
        color = AppColors.warning;
        text = 'Beklemede';
        break;
      case 'sold':
        color = AppColors.info;
        text = 'Satıldı';
        break;
      case 'reserved':
        color = AppColors.primary;
        text = 'Rezerve';
        break;
      case 'expired':
        color = AppColors.textMuted;
        text = 'Süresi Dolmuş';
        break;
      case 'rejected':
        color = AppColors.error;
        text = 'Reddedildi';
        break;
      default:
        color = AppColors.textMuted;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
