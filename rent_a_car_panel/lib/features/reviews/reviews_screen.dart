import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allReviews = [];
  List<Map<String, dynamic>> _pendingReviews = [];
  List<Map<String, dynamic>> _repliedReviews = [];
  bool _isLoading = true;
  String? _companyId;
  Map<String, dynamic>? _ratingSummary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCompanyId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyId() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('rental_companies')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();

    if (response != null && mounted) {
      setState(() => _companyId = response['id']);
      _loadReviews();
    }
  }

  Future<void> _loadReviews() async {
    if (_companyId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('rental_reviews')
          .select('''
            *,
            profiles:user_id(full_name, avatar_url),
            rental_cars:car_id(brand, model),
            rental_bookings:booking_id(booking_number)
          ''')
          .eq('company_id', _companyId!)
          .order('created_at', ascending: false);

      final reviews = List<Map<String, dynamic>>.from(response);

      // Calculate rating summary
      if (reviews.isNotEmpty) {
        final approvedReviews = reviews.where((r) => r['is_approved'] == true).toList();
        final totalRating = approvedReviews.fold<int>(0, (sum, r) => sum + (r['overall_rating'] as int));
        final avgRating = approvedReviews.isNotEmpty ? totalRating / approvedReviews.length : 0.0;

        final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        for (final review in approvedReviews) {
          final rating = review['overall_rating'] as int;
          distribution[rating] = (distribution[rating] ?? 0) + 1;
        }

        _ratingSummary = {
          'average': avgRating,
          'total': approvedReviews.length,
          'distribution': distribution,
        };
      }

      if (mounted) {
        setState(() {
          _allReviews = reviews;
          _pendingReviews = reviews.where((r) =>
            r['company_reply'] == null && r['is_approved'] == true
          ).toList();
          _repliedReviews = reviews.where((r) =>
            r['company_reply'] != null
          ).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorumlar yüklenirken hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Müşteri Yorumları'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1976D2),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1976D2),
          tabs: [
            Tab(text: 'Tümü (${_allReviews.length})'),
            Tab(text: 'Yanıt Bekleyen (${_pendingReviews.length})'),
            Tab(text: 'Yanıtlanan (${_repliedReviews.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Rating Summary Card
                if (_ratingSummary != null) _buildRatingSummary(),

                // Reviews List
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildReviewsList(_allReviews),
                      _buildReviewsList(_pendingReviews),
                      _buildReviewsList(_repliedReviews),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRatingSummary() {
    final avg = _ratingSummary!['average'] as double;
    final total = _ratingSummary!['total'] as int;
    final distribution = _ratingSummary!['distribution'] as Map<int, int>;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  if (avg >= index + 1) {
                    return const Icon(Icons.star, color: Color(0xFF1976D2), size: 18);
                  } else if (avg >= index + 0.5) {
                    return const Icon(Icons.star_half, color: Color(0xFF1976D2), size: 18);
                  } else {
                    return const Icon(Icons.star_border, color: Color(0xFF1976D2), size: 18);
                  }
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$total yorum',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((rating) {
                final count = distribution[rating] ?? 0;
                final percentage = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$rating',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 12, color: Color(0xFF1976D2)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF1976D2)),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
      ),
    );
  }

  Widget _buildReviewsList(List<Map<String, dynamic>> reviews) {
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz yorum yok',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReviews,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reviews.length,
        itemBuilder: (context, index) => _buildReviewCard(reviews[index]),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final profile = review['profiles'] as Map<String, dynamic>?;
    final car = review['rental_cars'] as Map<String, dynamic>?;
    final booking = review['rental_bookings'] as Map<String, dynamic>?;
    final userName = profile?['full_name'] ?? 'Anonim';
    final userAvatar = profile?['avatar_url'];
    final rating = review['overall_rating'] as int;
    final comment = review['comment'] as String?;
    final companyReply = review['company_reply'] as String?;
    final createdAt = DateTime.tryParse(review['created_at'] ?? '');
    final isHidden = review['is_hidden'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isHidden ? Border.all(color: Colors.red.withValues(alpha: 0.3)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  backgroundImage: userAvatar != null ? NetworkImage(userAvatar) : null,
                  child: userAvatar == null
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF1976D2),
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
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (car != null)
                        Text(
                          '${car['brand']} ${car['model']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      if (booking != null)
                        Text(
                          'Rezervasyon: ${booking['booking_number']}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRatingColor(rating).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: _getRatingColor(rating), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$rating',
                            style: TextStyle(
                              color: _getRatingColor(rating),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (createdAt != null)
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Detailed ratings
          if (review['car_condition_rating'] != null ||
              review['cleanliness_rating'] != null ||
              review['service_rating'] != null ||
              review['value_rating'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (review['car_condition_rating'] != null)
                    _buildMiniRating('Araç', review['car_condition_rating']),
                  if (review['cleanliness_rating'] != null)
                    _buildMiniRating('Temizlik', review['cleanliness_rating']),
                  if (review['service_rating'] != null)
                    _buildMiniRating('Hizmet', review['service_rating']),
                  if (review['value_rating'] != null)
                    _buildMiniRating('Değer', review['value_rating']),
                ],
              ),
            ),

          // Comment
          if (comment != null && comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                comment,
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),

          // Pros & Cons
          if (review['pros'] != null && (review['pros'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (review['pros'] as List).map((pro) => Container(
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
                        pro.toString(),
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),

          if (review['cons'] != null && (review['cons'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (review['cons'] as List).map((con) => Container(
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
                        con.toString(),
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),

          // Company Reply
          if (companyReply != null && companyReply.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, size: 16, color: Color(0xFF1976D2)),
                      const SizedBox(width: 6),
                      const Text(
                        'Yanıtınız',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      const Spacer(),
                      if (review['replied_at'] != null)
                        Text(
                          _formatDate(DateTime.parse(review['replied_at'])),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    companyReply,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                if (companyReply == null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showReplyDialog(review),
                      icon: const Icon(Icons.reply, size: 18),
                      label: const Text('Yanıtla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showReplyDialog(review, isEdit: true),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Yanıtı Düzenle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _toggleHideReview(review),
                  icon: Icon(
                    isHidden ? Icons.visibility : Icons.visibility_off,
                    color: isHidden ? Colors.green : Colors.red,
                  ),
                  tooltip: isHidden ? 'Göster' : 'Gizle',
                ),
              ],
            ),
          ),
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
            color: Colors.grey[600],
          ),
        ),
        ...List.generate(5, (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: const Color(0xFF1976D2),
          size: 12,
        )),
      ],
    );
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showReplyDialog(Map<String, dynamic> review, {bool isEdit = false}) {
    final controller = TextEditingController(
      text: isEdit ? review['company_reply'] : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Yanıtı Düzenle' : 'Yoruma Yanıt Ver'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Yanıtınızı yazın...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              await _submitReply(review['id'], controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
            ),
            child: Text(isEdit ? 'Güncelle' : 'Gönder'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReply(String reviewId, String reply) async {
    try {
      await Supabase.instance.client
          .from('rental_reviews')
          .update({
            'company_reply': reply,
            'replied_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yanıt kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReviews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleHideReview(Map<String, dynamic> review) async {
    final currentlyHidden = review['is_hidden'] as bool? ?? false;

    try {
      await Supabase.instance.client
          .from('rental_reviews')
          .update({'is_hidden': !currentlyHidden})
          .eq('id', review['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyHidden ? 'Yorum gösterilecek' : 'Yorum gizlendi'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReviews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
