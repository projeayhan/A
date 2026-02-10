import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/name_masking.dart';
import '../../models/taxi/driver_review_models.dart';
import '../../core/services/taxi_service.dart';
import '../../widgets/taxi/driver_rating_stats_widget.dart';
import 'widgets/review_reply_sheet.dart';

class DriverReviewsScreen extends ConsumerStatefulWidget {
  final String driverId;

  const DriverReviewsScreen({
    super.key,
    required this.driverId,
  });

  @override
  ConsumerState<DriverReviewsScreen> createState() => _DriverReviewsScreenState();
}

class _DriverReviewsScreenState extends ConsumerState<DriverReviewsScreen> {
  DriverRatingStats? _stats;
  List<DriverReview> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int? _selectedFilter;
  String _error = '';

  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _realtimeChannel;

  static const int _pageSize = 20;
  int _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeSubscription();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _realtimeChannel = TaxiService.subscribeToDriverRatings(
      widget.driverId,
      (data) {
        // Yeni değerlendirme geldiğinde listeyi yenile
        _loadData();
        _showNewRatingNotification(data);
      },
    );
  }

  void _showNewRatingNotification(Map<String, dynamic> data) {
    if (!mounted) return;

    final rating = data['rating'] as int?;
    final customerName = maskUserName(data['customer_name'] as String?);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$customerName size ${rating ?? 0} yıldız verdi!'),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Görüntüle',
          onPressed: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final results = await Future.wait([
        TaxiService.getDriverRatingStats(widget.driverId),
        TaxiService.getDriverReviews(
          driverId: widget.driverId,
          ratingFilter: _selectedFilter,
          limit: _pageSize,
          offset: 0,
        ),
      ]);

      final statsData = results[0] as Map<String, dynamic>?;
      final reviewsData = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _stats = statsData != null ? DriverRatingStats.fromMap(statsData) : null;
          _reviews = reviewsData.map((e) => DriverReview.fromMap(e)).toList();
          _currentOffset = _reviews.length;
          _hasMore = reviewsData.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final reviewsData = await TaxiService.getDriverReviews(
        driverId: widget.driverId,
        ratingFilter: _selectedFilter,
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (mounted) {
        setState(() {
          _reviews.addAll(reviewsData.map((e) => DriverReview.fromMap(e)));
          _currentOffset = _reviews.length;
          _hasMore = reviewsData.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onFilterChanged(int? filter) {
    if (_selectedFilter == filter) return;

    setState(() {
      _selectedFilter = filter;
      _currentOffset = 0;
      _hasMore = true;
    });
    _loadData();
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Değerlendirmelerim'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorView(theme, colorScheme)
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Stats Header
                      if (_stats != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: DriverRatingStatsWidget(stats: _stats!),
                          ),
                        ),

                      // Filter Chips
                      SliverToBoxAdapter(
                        child: _buildFilterChips(theme, colorScheme),
                      ),

                      // Reviews List
                      _reviews.isEmpty
                          ? SliverFillRemaining(
                              child: _buildEmptyView(theme, colorScheme),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index == _reviews.length) {
                                      return _isLoadingMore
                                          ? const Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            )
                                          : const SizedBox.shrink();
                                    }
                                    return _buildReviewCard(
                                      theme,
                                      colorScheme,
                                      _reviews[index],
                                    );
                                  },
                                  childCount: _reviews.length + 1,
                                ),
                              ),
                            ),

                      // Bottom padding
                      const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorView(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Bir hata oluştu',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter != null
                  ? '$_selectedFilter yıldızlı değerlendirme yok'
                  : 'Henüz değerlendirme yok',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Müşterileriniz sizi değerlendirdiğinde\nburada görünecek.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            theme,
            colorScheme,
            label: 'Tümü',
            value: null,
            count: _stats?.totalRatings ?? 0,
          ),
          const SizedBox(width: 8),
          ...List.generate(5, (index) {
            final rating = 5 - index;
            final count = _stats?.getCountForRating(rating) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                theme,
                colorScheme,
                label: '$rating',
                value: rating,
                count: count,
                showStar: true,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    ThemeData theme,
    ColorScheme colorScheme, {
    required String label,
    required int? value,
    required int count,
    bool showStar = false,
  }) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(value),
      avatar: showStar
          ? Icon(
              Icons.star_rounded,
              size: 18,
              color: isSelected ? colorScheme.onPrimary : Colors.amber,
            )
          : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.onPrimary.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
    );
  }

  Widget _buildReviewCard(
    ThemeData theme,
    ColorScheme colorScheme,
    DriverReview review,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Customer name, rating, date
            Row(
              children: [
                // Customer avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    maskUserName(review.customerName)[0].toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        maskUserName(review.customerName),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        review.formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating stars
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),

            // Comment
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment!,
                style: theme.textTheme.bodyMedium,
              ),
            ],

            // Feedback tags
            if (review.feedbackTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: review.feedbackTags.map((tag) {
                  final isPositive = !tag.startsWith('!');
                  final displayTag = isPositive ? tag : tag.substring(1);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPositive
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_down_alt_rounded,
                          size: 14,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayTag,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Driver reply section
            const SizedBox(height: 12),
            if (review.hasReply) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cevabınız',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (review.replyDate != null)
                          Text(
                            _formatReplyDate(review.replyDate!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      review.driverReply!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Reply button (only show if no reply yet - one reply only policy)
            if (!review.hasReply)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openReplySheet(review),
                  icon: const Icon(
                    Icons.reply_rounded,
                    size: 18,
                  ),
                  label: const Text('Cevapla'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatReplyDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Bugün';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  void _openReplySheet(DriverReview review) {
    ReviewReplySheet.show(
      context,
      review,
      onReplied: () {
        _loadData();
      },
    );
  }
}
