import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/merchant_provider.dart';
import '../../../core/services/notification_sound_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/name_masking.dart';

// Reviews stream provider
final reviewsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final merchantAsync = ref.watch(currentMerchantProvider);
  final merchant = merchantAsync.valueOrNull;

  if (merchant == null) {
    return Stream.value([]);
  }

  return Supabase.instance.client
      .from('reviews')
      .stream(primaryKey: ['id'])
      .eq('merchant_id', merchant.id)
      .order('created_at', ascending: false);
});

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RealtimeChannel? _reviewChannel;
  final Set<String> _seenReviewIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final merchantAsync = ref.read(currentMerchantProvider);
    final merchant = merchantAsync.valueOrNull;

    if (merchant == null) return;

    final merchantId = merchant.id;

    _reviewChannel = Supabase.instance.client
        .channel('merchant_reviews_$merchantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reviews',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: merchantId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              final reviewId = newRecord['id'] as String;
              if (!_seenReviewIds.contains(reviewId)) {
                _seenReviewIds.add(reviewId);
                // Play notification sound for new review
                NotificationSoundService.playSound(type: NotificationSoundType.general);
                _showNewReviewNotification(newRecord);
              }
            }
          },
        )
        .subscribe();
  }

  void _showNewReviewNotification(Map<String, dynamic> review) {
    final rating = (review['courier_rating'] as int? ?? 0) +
        (review['service_rating'] as int? ?? 0) +
        (review['taste_rating'] as int? ?? 0);
    final avgRating = (rating / 3).toStringAsFixed(1);
    final customerName = maskUserName(review['customer_name'] as String?);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Yeni Değerlendirme!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$customerName $avgRating puan verdi',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.amber[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reviewChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(reviewsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Değerlendirmeler'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amber[700],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.amber[700],
          tabs: const [
            Tab(text: 'Tümü'),
            Tab(text: 'Cevaplanmamış'),
            Tab(text: 'Cevaplanmış'),
          ],
        ),
      ),
      body: reviewsAsync.when(
        data: (reviews) {
          // Mark all as seen
          for (final review in reviews) {
            _seenReviewIds.add(review['id'] as String);
          }

          final unanswered = reviews.where((r) => r['merchant_reply'] == null).toList();
          final answered = reviews.where((r) => r['merchant_reply'] != null).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildReviewsList(reviews, isDark),
              _buildReviewsList(unanswered, isDark),
              _buildReviewsList(answered, isDark),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Hata: $error')),
      ),
    );
  }

  Widget _buildReviewsList(List<Map<String, dynamic>> reviews, bool isDark) {
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz değerlendirme yok',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        return _buildReviewCard(review, isDark);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isDark) {
    final courierRating = review['courier_rating'] as int? ?? 0;
    final serviceRating = review['service_rating'] as int? ?? 0;
    final tasteRating = review['taste_rating'] as int? ?? 0;
    final avgRating = (courierRating + serviceRating + tasteRating) / 3;
    final comment = review['comment'] as String?;
    final merchantReply = review['merchant_reply'] as String?;
    final customerName = maskUserName(review['customer_name'] as String?);
    final orderNumber = review['order_number'] as String? ?? '';
    final createdAt = DateTime.tryParse(review['created_at'] as String? ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: merchantReply == null
            ? Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
                  backgroundColor: Colors.amber.withValues(alpha: 0.1),
                  child: Text(
                    customerName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Sipariş #$orderNumber • ${_formatDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                // Average rating badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRatingColor(avgRating),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rating breakdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildRatingChip('Kurye', courierRating, const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _buildRatingChip('Servis', serviceRating, const Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                _buildRatingChip('Lezzet', tasteRating, const Color(0xFFF59E0B)),
              ],
            ),
          ),

          // Comment
          if (comment != null && comment.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  comment,
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
            ),
          ],

          // Merchant reply section
          if (merchantReply != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Cevabınız',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    merchantReply,
                    style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Reply button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReplyDialog(review),
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Yanıtla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingChip(String label, int rating, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.star, size: 12, color: color),
          Text(
            rating.toString(),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return const Color(0xFF22C55E);
    if (rating >= 3) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} dk önce';
      }
      return '${diff.inHours} saat önce';
    }
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showReplyDialog(Map<String, dynamic> review) {
    final replyController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Müşteriye Yanıt Ver',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yanıtınız müşteriye bildirim olarak gönderilecektir.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: replyController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Yanıtınızı yazın...',
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (replyController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen bir yanıt yazın')),
                          );
                          return;
                        }

                        await _submitReply(review['id'] as String, replyController.text.trim());
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Yanıtı Gönder'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReply(String reviewId, String reply) async {
    try {
      await Supabase.instance.client.from('reviews').update({
        'merchant_reply': reply,
        'replied_at': DateTime.now().toIso8601String(),
      }).eq('id', reviewId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yanıtınız gönderildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Hata: $e');
      }
    }
  }
}
