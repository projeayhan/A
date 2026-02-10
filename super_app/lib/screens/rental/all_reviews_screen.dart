import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/name_masking.dart';
import '../../models/rental/rental_models.dart';

class AllReviewsScreen extends StatefulWidget {
  final String companyId;
  final String companyName;

  const AllReviewsScreen({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  List<RentalReview> _reviews = [];
  RatingsSummary? _ratingsSummary;
  bool _isLoading = true;
  String _sortBy = 'newest';
  int? _filterRating;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);

    try {
      var query = Supabase.instance.client
          .from('rental_reviews')
          .select('*')
          .eq('company_id', widget.companyId)
          .eq('is_approved', true)
          .eq('is_hidden', false);

      if (_filterRating != null) {
        query = query.eq('overall_rating', _filterRating!);
      }

      String orderColumn = 'created_at';
      bool ascending = false;

      if (_sortBy == 'newest') {
        orderColumn = 'created_at';
        ascending = false;
      } else if (_sortBy == 'oldest') {
        orderColumn = 'created_at';
        ascending = true;
      } else if (_sortBy == 'highest') {
        orderColumn = 'overall_rating';
        ascending = false;
      } else if (_sortBy == 'lowest') {
        orderColumn = 'overall_rating';
        ascending = true;
      }

      final response = await query.order(orderColumn, ascending: ascending);

      final reviews = (response as List)
          .map((json) => RentalReview.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _ratingsSummary = RatingsSummary.fromReviews(reviews);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorumlar yüklenirken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.companyName} Yorumları'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              onRefresh: _loadReviews,
              color: colors.primary,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildRatingSummary(theme)),
                  SliverToBoxAdapter(child: _buildFilterSort(theme)),
                  _reviews.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rate_review_outlined, size: 64,
                                    color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
                                const SizedBox(height: 16),
                                Text('Henüz yorum yok',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                        color: colors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildReviewCard(_reviews[index], theme),
                              childCount: _reviews.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildRatingSummary(ThemeData theme) {
    final summary = _ratingsSummary;
    if (summary == null) return const SizedBox.shrink();
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  children: [
                    Text(
                      summary.averageRating.toStringAsFixed(1),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        if (summary.averageRating >= starValue) {
                          return Icon(Icons.star, color: colors.primary, size: 16);
                        } else if (summary.averageRating >= starValue - 0.5) {
                          return Icon(Icons.star_half, color: colors.primary, size: 16);
                        } else {
                          return Icon(Icons.star_border, color: colors.primary, size: 16);
                        }
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text('${summary.totalReviews} yorum',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _buildRatingBar('5', summary.getPercentage(5), summary.ratingDistribution[5] ?? 0, theme),
                      _buildRatingBar('4', summary.getPercentage(4), summary.ratingDistribution[4] ?? 0, theme),
                      _buildRatingBar('3', summary.getPercentage(3), summary.ratingDistribution[3] ?? 0, theme),
                      _buildRatingBar('2', summary.getPercentage(2), summary.ratingDistribution[2] ?? 0, theme),
                      _buildRatingBar('1', summary.getPercentage(1), summary.ratingDistribution[1] ?? 0, theme),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.avgCarCondition != null ||
                summary.avgCleanliness != null ||
                summary.avgService != null ||
                summary.avgValue != null) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (summary.avgCarCondition != null)
                    _buildDetailedRating('Araç Durumu', summary.avgCarCondition!, theme),
                  if (summary.avgCleanliness != null)
                    _buildDetailedRating('Temizlik', summary.avgCleanliness!, theme),
                  if (summary.avgService != null)
                    _buildDetailedRating('Hizmet', summary.avgService!, theme),
                  if (summary.avgValue != null)
                    _buildDetailedRating('Fiyat/Performans', summary.avgValue!, theme),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, double percentage, int count, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text('$count',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedRating(String label, double rating, ThemeData theme) {
    return Column(
      children: [
        Text(
          rating.toStringAsFixed(1),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildFilterSort(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _sortBy,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.sort),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('En Yeni')),
                DropdownMenuItem(value: 'oldest', child: Text('En Eski')),
                DropdownMenuItem(value: 'highest', child: Text('En Yüksek Puan')),
                DropdownMenuItem(value: 'lowest', child: Text('En Düşük Puan')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sortBy = value);
                  _loadReviews();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: _filterRating,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_list),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              hint: const Text('Tüm Puanlar'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tüm Puanlar')),
                DropdownMenuItem(value: 5, child: Text('5 Yıldız')),
                DropdownMenuItem(value: 4, child: Text('4 Yıldız')),
                DropdownMenuItem(value: 3, child: Text('3 Yıldız')),
                DropdownMenuItem(value: 2, child: Text('2 Yıldız')),
                DropdownMenuItem(value: 1, child: Text('1 Yıldız')),
              ],
              onChanged: (value) {
                setState(() => _filterRating = value);
                _loadReviews();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(RentalReview review, ThemeData theme) {
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  backgroundImage: review.userAvatar != null
                      ? NetworkImage(review.userAvatar!)
                      : null,
                  child: review.userAvatar == null
                      ? Text(
                          maskUserName(review.userName)[0].toUpperCase(),
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(maskUserName(review.userName),
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(review.timeAgo,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(Icons.star, color: colors.primary, size: 16),
                  label: Text('${review.overallRating}',
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                  backgroundColor: colors.primary.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            // Detailed ratings
            if (review.carConditionRating != null ||
                review.cleanlinessRating != null ||
                review.serviceRating != null ||
                review.valueRating != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (review.carConditionRating != null)
                    _buildMiniRating('Araç', review.carConditionRating!, theme),
                  if (review.cleanlinessRating != null)
                    _buildMiniRating('Temizlik', review.cleanlinessRating!, theme),
                  if (review.serviceRating != null)
                    _buildMiniRating('Hizmet', review.serviceRating!, theme),
                  if (review.valueRating != null)
                    _buildMiniRating('Değer', review.valueRating!, theme),
                ],
              ),
            ],

            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(review.comment!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant, height: 1.5)),
            ],

            // Pros
            if (review.pros != null && review.pros!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: review.pros!.map((pro) => Chip(
                  avatar: const Icon(Icons.add_circle, color: AppColors.success, size: 14),
                  label: Text(pro, style: const TextStyle(fontSize: 12, color: AppColors.success)),
                  backgroundColor: AppColors.success.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],

            // Cons
            if (review.cons != null && review.cons!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: review.cons!.map((con) => Chip(
                  avatar: const Icon(Icons.remove_circle, color: AppColors.error, size: 14),
                  label: Text(con, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  backgroundColor: AppColors.error.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],

            // Company Reply
            if (review.companyReply != null && review.companyReply!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Text('Firma Yanıtı',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.primary, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (review.repliedAt != null)
                          Text(_formatDate(review.repliedAt!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(review.companyReply!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant, height: 1.4)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniRating(String label, int rating, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        ...List.generate(5, (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: theme.colorScheme.primary,
          size: 12,
        )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
