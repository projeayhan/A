import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_dialogs.dart';
import '../../core/utils/profanity_filter.dart';

class OrderReviewScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderReviewScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends ConsumerState<OrderReviewScreen>
    with TickerProviderStateMixin {
  // Rating values (1-5)
  int _courierRating = 0;
  int _serviceRating = 0;
  int _tasteRating = 0;

  // Comment
  final _commentController = TextEditingController();

  // Order data
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    _starController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('*, merchants(business_name, logo_url)')
          .eq('id', widget.orderId)
          .single();

      if (mounted) {
        setState(() {
          _orderData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialogs.showError(context, 'Sipariş yüklenemedi: $e');
      }
    }
  }

  Future<void> _submitReview() async {
    // Validate all ratings
    if (_courierRating == 0 || _serviceRating == 0 || _tasteRating == 0) {
      AppDialogs.showWarning(context, 'Lütfen tüm kategorileri değerlendirin');
      return;
    }

    // Check for profanity in comment
    final comment = _commentController.text.trim();
    if (comment.isNotEmpty && ProfanityFilter.containsProfanity(comment)) {
      AppDialogs.showError(context, 'Yorumunuz uygunsuz ifadeler içeriyor. Lütfen düzenleyin.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) throw Exception('Kullanıcı girişi gerekli');

      final merchantId = _orderData?['merchant_id'];
      if (merchantId == null) throw Exception('Restoran bulunamadı');

      // Calculate average rating
      final avgRating = ((_courierRating + _serviceRating + _tasteRating) / 3).round();

      // Get customer name from order or user metadata
      String? customerName = _orderData?['customer_name'];
      if (customerName == null || customerName.isEmpty) {
        // Try to get from user metadata
        final userMeta = SupabaseService.currentUser?.userMetadata;
        customerName = userMeta?['full_name'] ?? userMeta?['name'] ?? 'Müşteri';
      }

      // Insert review
      await SupabaseService.client.from('reviews').insert({
        'order_id': widget.orderId,
        'user_id': userId,
        'merchant_id': merchantId,
        'rating': avgRating,
        'courier_rating': _courierRating,
        'service_rating': _serviceRating,
        'taste_rating': _tasteRating,
        'comment': _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        'customer_name': customerName,
        'order_number': _orderData?['order_number'],
      });

      // Mark order as reviewed
      await SupabaseService.client
          .from('orders')
          .update({'is_reviewed': true})
          .eq('id', widget.orderId);

      if (mounted) {
        // Show success dialog
        await _showSuccessDialog();
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Review error: $e');
      if (mounted) {
        String errorMessage = 'Değerlendirme gönderilemedi';

        // Check for specific error types
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('duplicate') ||
            errorString.contains('unique') ||
            errorString.contains('reviews_order_id') ||
            errorString.contains('already exists') ||
            errorString.contains('23505')) {
          errorMessage = 'Bu sipariş için zaten değerlendirme yaptınız';
        } else if (errorString.contains('uygunsuz ifadeler')) {
          errorMessage = 'Yorumunuz uygunsuz ifadeler içeriyor';
        } else if (errorString.contains('foreign key') || errorString.contains('23503')) {
          errorMessage = 'Sipariş veya kullanıcı bilgisi bulunamadı';
        }

        AppDialogs.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Teşekkürler!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Değerlendirmeniz başarıyla gönderildi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Tamam',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _starController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Siparişi Değerlendir'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeController,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant Info Card
                    _buildRestaurantCard(isDark),
                    const SizedBox(height: 24),

                    // Rating Categories
                    _buildRatingSection(
                      isDark: isDark,
                      icon: Icons.delivery_dining,
                      title: 'Kurye',
                      subtitle: 'Teslimat hızı ve kurye davranışı',
                      rating: _courierRating,
                      onRatingChanged: (rating) {
                        setState(() => _courierRating = rating);
                        _starController.forward(from: 0);
                      },
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 16),

                    _buildRatingSection(
                      isDark: isDark,
                      icon: Icons.room_service,
                      title: 'Servis',
                      subtitle: 'Paketleme ve sunum kalitesi',
                      rating: _serviceRating,
                      onRatingChanged: (rating) {
                        setState(() => _serviceRating = rating);
                        _starController.forward(from: 0);
                      },
                      color: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(height: 16),

                    _buildRatingSection(
                      isDark: isDark,
                      icon: Icons.restaurant,
                      title: 'Lezzet',
                      subtitle: 'Yemeklerin tadı ve kalitesi',
                      rating: _tasteRating,
                      onRatingChanged: (rating) {
                        setState(() => _tasteRating = rating);
                        _starController.forward(from: 0);
                      },
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 24),

                    // Average Score Display
                    if (_courierRating > 0 && _serviceRating > 0 && _tasteRating > 0)
                      _buildAverageScore(isDark),

                    const SizedBox(height: 24),

                    // Comment Section
                    _buildCommentSection(isDark),

                    const SizedBox(height: 32),

                    // Submit Button
                    _buildSubmitButton(isDark),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRestaurantCard(bool isDark) {
    final merchantName = _orderData?['merchants']?['business_name'] ?? 'Restoran';
    final orderNumber = _orderData?['order_number'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.restaurant,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchantName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sipariş #$orderNumber',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required int rating,
    required Function(int) onRatingChanged,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: rating > 0
            ? Border.all(color: color.withValues(alpha: 0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: rating > 0
                ? color.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (rating > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rating.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Star Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = starValue <= rating;

              return GestureDetector(
                onTap: () => onRatingChanged(starValue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: isSelected ? 44 : 40,
                    color: isSelected ? color : Colors.grey[400],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Rating labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kötü',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              Text(
                'Orta',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              Text(
                'Harika',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAverageScore(bool isDark) {
    final average = (_courierRating + _serviceRating + _tasteRating) / 3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Text(
            average.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ortalama Puan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Bu restoran için verilecek',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yorumunuz (İsteğe Bağlı)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: TextField(
            controller: _commentController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Deneyiminizi paylaşın...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    final isComplete = _courierRating > 0 && _serviceRating > 0 && _tasteRating > 0;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isComplete && !_isSubmitting ? _submitReview : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isComplete ? AppColors.primary : Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isComplete ? 8 : 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isComplete ? Icons.send : Icons.star_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isComplete ? 'Değerlendirmeyi Gönder' : 'Tüm Kategorileri Değerlendirin',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
