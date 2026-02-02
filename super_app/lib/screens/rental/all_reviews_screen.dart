import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  static const Color _primaryBlue = Color(0xFF1976D2);
  static const Color _backgroundColor = Color(0xFFF5F5F5);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);

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
          .select('*, profiles:user_id(full_name, avatar_url)')
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
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.companyName} Yorumları',
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadReviews,
              color: _primaryBlue,
              child: CustomScrollView(
                slivers: [
                  // Rating Summary
                  SliverToBoxAdapter(
                    child: _buildRatingSummary(),
                  ),

                  // Filter & Sort
                  SliverToBoxAdapter(
                    child: _buildFilterSort(),
                  ),

                  // Reviews List
                  _reviews.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.rate_review_outlined,
                                  size: 64,
                                  color: _textSecondary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz yorum yok',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildReviewCard(_reviews[index]),
                              childCount: _reviews.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildRatingSummary() {
    final summary = _ratingsSummary;
    if (summary == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Text(
                    summary.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      if (summary.averageRating >= starValue) {
                        return const Icon(Icons.star, color: _primaryBlue, size: 16);
                      } else if (summary.averageRating >= starValue - 0.5) {
                        return const Icon(Icons.star_half, color: _primaryBlue, size: 16);
                      } else {
                        return const Icon(Icons.star_border, color: _primaryBlue, size: 16);
                      }
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.totalReviews} yorum',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildRatingBar('5', summary.getPercentage(5), summary.ratingDistribution[5] ?? 0),
                    _buildRatingBar('4', summary.getPercentage(4), summary.ratingDistribution[4] ?? 0),
                    _buildRatingBar('3', summary.getPercentage(3), summary.ratingDistribution[3] ?? 0),
                    _buildRatingBar('2', summary.getPercentage(2), summary.ratingDistribution[2] ?? 0),
                    _buildRatingBar('1', summary.getPercentage(1), summary.ratingDistribution[1] ?? 0),
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
                  _buildDetailedRating('Araç Durumu', summary.avgCarCondition!),
                if (summary.avgCleanliness != null)
                  _buildDetailedRating('Temizlik', summary.avgCleanliness!),
                if (summary.avgService != null)
                  _buildDetailedRating('Hizmet', summary.avgService!),
                if (summary.avgValue != null)
                  _buildDetailedRating('Fiyat/Performans', summary.avgValue!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, double percentage, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: _primaryBlue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: _textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedRating(String label, double rating) {
    return Column(
      children: [
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _primaryBlue,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSort() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Sort dropdown
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isExpanded: true,
                  icon: const Icon(Icons.sort, color: _primaryBlue),
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
            ),
          ),
          const SizedBox(width: 12),
          // Filter dropdown
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _filterRating,
                  isExpanded: true,
                  hint: const Text('Tüm Puanlar'),
                  icon: const Icon(Icons.filter_list, color: _primaryBlue),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(RentalReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                backgroundImage: review.userAvatar != null
                    ? NetworkImage(review.userAvatar!)
                    : null,
                child: review.userAvatar == null
                    ? Text(
                        (review.userName ?? 'A')[0].toUpperCase(),
                        style: const TextStyle(
                          color: _primaryBlue,
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
                    Text(
                      review.userName ?? 'Anonim',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: _primaryBlue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${review.overallRating}',
                      style: const TextStyle(
                        color: _primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
                  _buildMiniRating('Araç', review.carConditionRating!),
                if (review.cleanlinessRating != null)
                  _buildMiniRating('Temizlik', review.cleanlinessRating!),
                if (review.serviceRating != null)
                  _buildMiniRating('Hizmet', review.serviceRating!),
                if (review.valueRating != null)
                  _buildMiniRating('Değer', review.valueRating!),
              ],
            ),
          ],

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment!,
              style: TextStyle(
                color: _textSecondary,
                height: 1.5,
              ),
            ),
          ],

          // Pros & Cons
          if (review.pros != null && review.pros!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.pros!.map((pro) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle, color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      pro,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],

          if (review.cons != null && review.cons!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.cons!.map((con) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.remove_circle, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      con,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],

          // Company Reply
          if (review.companyReply != null && review.companyReply!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, size: 16, color: _primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Firma Yanıtı',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                      const Spacer(),
                      if (review.repliedAt != null)
                        Text(
                          _formatDate(review.repliedAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.companyReply!,
                    style: TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniRating(String label, int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
          ),
        ),
        ...List.generate(5, (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: _primaryBlue,
          size: 12,
        )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
