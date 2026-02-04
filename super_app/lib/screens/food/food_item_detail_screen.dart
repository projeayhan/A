import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/utils/app_dialogs.dart';
import '../../core/utils/image_utils.dart';
import '../../core/providers/cart_provider.dart';
import 'food_home_screen.dart';
import '../../widgets/food/add_to_cart_animation.dart';

class FoodItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final double rating;
  final String restaurantName;
  final String deliveryTime;

  const FoodItemDetailScreen({
    super.key,
    required this.itemId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.restaurantName,
    required this.deliveryTime,
  });

  @override
  ConsumerState<FoodItemDetailScreen> createState() => _FoodItemDetailScreenState();
}

class _FoodItemDetailScreenState extends ConsumerState<FoodItemDetailScreen> {
  int _quantity = 1;
  final _noteController = TextEditingController();

  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _cartTargetKey = GlobalKey();
  final GlobalKey<CartIconBounceState> _cartBounceKey = GlobalKey<CartIconBounceState>();
  bool _isAnimating = false;
  bool _isLoading = true;

  // Option groups from database
  List<Map<String, dynamic>> _optionGroups = [];

  // Reviews from database
  List<Map<String, dynamic>> _reviews = [];
  int _totalReviewCount = 0;

  double get _totalPrice {
    double total = widget.price;
    // Add selected option prices
    for (final group in _optionGroups) {
      final selectedIndices = group['selectedIndices'] as Set<int>? ?? {};
      final options = group['options'] as List<Map<String, dynamic>>? ?? [];
      for (final index in selectedIndices) {
        if (index < options.length) {
          total += (options[index]['price'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    return total * _quantity;
  }

  @override
  void initState() {
    super.initState();
    _loadOptionGroups();
    _loadReviews();
  }

  Future<void> _loadOptionGroups() async {
    if (widget.itemId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Get option groups linked to this menu item
      final linkResponse = await supabase
          .from('menu_item_option_groups')
          .select('option_group_id')
          .eq('menu_item_id', widget.itemId);

      if (linkResponse.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final groupIds = (linkResponse as List).map((e) => e['option_group_id']).toList();

      // Get option groups with their options
      final groupsResponse = await supabase
          .from('product_option_groups')
          .select()
          .inFilter('id', groupIds);

      final List<Map<String, dynamic>> groups = [];

      for (final group in groupsResponse) {
        final optionsResponse = await supabase
            .from('product_options')
            .select()
            .eq('option_group_id', group['id']);

        groups.add({
          'id': group['id'],
          'name': group['name'],
          'isRequired': group['is_required'] ?? false,
          'maxSelections': group['max_selections'] ?? 1,
          'options': (optionsResponse as List).map((o) => {
            'id': o['id'],
            'name': o['name'],
            'price': (o['price'] as num?)?.toDouble() ?? 0.0,
          }).toList(),
          'selectedIndices': <int>{},
        });
      }

      setState(() {
        _optionGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) print('Error loading option groups: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    if (widget.itemId.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;

      // Get reviews for this menu item
      final reviewsResponse = await supabase
          .from('menu_item_reviews')
          .select('id, rating, comment, customer_name, created_at')
          .eq('menu_item_id', widget.itemId)
          .order('created_at', ascending: false)
          .limit(5);

      // Get total count
      final countResponse = await supabase
          .from('menu_item_reviews')
          .select('id')
          .eq('menu_item_id', widget.itemId);

      setState(() {
        _reviews = List<Map<String, dynamic>>.from(reviewsResponse);
        _totalReviewCount = (countResponse as List).length;
      });
    } catch (e) {
      if (kDebugMode) print('Error loading reviews: $e');
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FoodColors.backgroundDark : const Color(0xFFF8F7F5),
      body: Stack(
        children: [
          // Main Content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Image
                _buildHeroSection(isDark),

                // Content with rounded top
                _buildContent(isDark),
              ],
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isDark) {
    return SizedBox(
      height: context.heroImageHeight + 20, // Slightly taller for detail view
      child: Stack(
        children: [
          // Image
          Positioned.fill(
            child: Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: widget.imageUrl.isNotEmpty
                  ? Image.network(
                      ImageUtils.getProductDetail(widget.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(Icons.fastfood, size: 48, color: Colors.grey[400]),
                        );
                      },
                    )
                  : Center(
                      child: Icon(Icons.fastfood, size: 48, color: Colors.grey[400]),
                    ),
            ),
          ),

          // Top Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Navigation Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: context.pagePaddingH,
            right: context.pagePaddingH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleButton(Icons.arrow_back, () => context.pop()),
                Row(
                  children: [
                    _buildCircleButton(Icons.share, () {}),
                    const SizedBox(width: 8),
                    _buildCircleButton(Icons.favorite_border, () {}),
                  ],
                ),
              ],
            ),
          ),

          // Pagination Dots
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return Container(
      transform: Matrix4.translationValues(0, -20, 0),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.backgroundDark : const Color(0xFFF8F7F5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.pagePaddingH, 16, context.pagePaddingH, 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Rating
            _buildTitleSection(isDark),

            const SizedBox(height: 20),

            // Stats Row
            _buildStatsRow(isDark),

            const SizedBox(height: 20),

            // Description
            Text(
              widget.description.isNotEmpty
                  ? widget.description
                  : '100% dana eti, özel şef sosu, çift katmanlı cheddar peyniri, karamelize soğan, turşu ve taze yeşillikler ile hazırlanan, brioche ekmeği arasında servis edilen enfes burger.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                height: 1.6,
              ),
            ),

            const SizedBox(height: 20),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
            const SizedBox(height: 20),

            // Option Groups from database (if any)
            if (_optionGroups.isNotEmpty) ...[
              _buildOptionGroups(isDark),
              const SizedBox(height: 24),
            ],

            // Note Section
            _buildNoteSection(isDark),

            const SizedBox(height: 24),

            // Reviews Preview
            _buildReviewsPreview(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1C130D),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.restaurantName} • Amerikan Mutfağı',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF166534).withValues(alpha: 0.3)
                : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                size: 16,
                color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
              ),
              const SizedBox(width: 4),
              Text(
                widget.rating.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        _buildStatCard(
          '${widget.price.toInt()} TL',
          'Başlangıç Fiyatı',
          isPrimary: true,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          widget.deliveryTime.split('-').first,
          'Dakika',
          icon: Icons.schedule,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Ücretsiz',
          'Teslimat',
          icon: Icons.moped,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, {bool isPrimary = false, IconData? icon, required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2F2219) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF3E2D23) : Colors.grey[100]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isPrimary
                    ? FoodColors.primary
                    : (isDark ? Colors.white : const Color(0xFF1C130D)),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: FoodColors.primary),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionGroups(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int groupIndex = 0; groupIndex < _optionGroups.length; groupIndex++) ...[
          if (groupIndex > 0) const SizedBox(height: 24),
          _buildOptionGroup(groupIndex, isDark),
        ],
      ],
    );
  }

  Widget _buildOptionGroup(int groupIndex, bool isDark) {
    final group = _optionGroups[groupIndex];
    final options = group['options'] as List<Map<String, dynamic>>? ?? [];
    final selectedIndices = group['selectedIndices'] as Set<int>;
    final isRequired = group['isRequired'] as bool? ?? false;
    final maxSelections = group['maxSelections'] as int? ?? 1;
    final isMultiSelect = maxSelections > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              group['name'] ?? 'Seçenekler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1C130D),
              ),
            ),
            Text(
              isRequired ? 'Zorunlu' : 'İsteğe bağlı',
              style: TextStyle(
                fontSize: 12,
                color: isRequired ? FoodColors.primary : Colors.grey[400],
                fontWeight: isRequired ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(options.length, (optionIndex) {
          final option = options[optionIndex];
          final isSelected = selectedIndices.contains(optionIndex);
          final price = (option['price'] as num?)?.toDouble() ?? 0.0;

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isMultiSelect) {
                  // Multi-select: toggle
                  if (isSelected) {
                    selectedIndices.remove(optionIndex);
                  } else {
                    selectedIndices.add(optionIndex);
                  }
                } else {
                  // Single select: replace
                  selectedIndices.clear();
                  selectedIndices.add(optionIndex);
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2F2219) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? FoodColors.primary.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected ? FoodColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(isMultiSelect ? 4 : 10),
                      border: Border.all(
                        color: isSelected
                            ? FoodColors.primary
                            : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option['name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[200] : const Color(0xFF1C130D),
                      ),
                    ),
                  ),
                  if (price > 0)
                    Text(
                      '+${price.toInt()} TL',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FoodColors.primary,
                      ),
                    )
                  else
                    Text(
                      'Ücretsiz',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNoteSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sipariş Notu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1C130D),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 3,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF1C130D),
          ),
          decoration: InputDecoration(
            hintText: 'Örn: Turşu olmasın, sosu ayrı olsun...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF2F2219) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: FoodColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsPreview(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Değerlendirmeler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1C130D),
              ),
            ),
            if (_totalReviewCount > 0)
              TextButton(
                onPressed: () {
                  // TODO: Navigate to all reviews screen
                },
                child: Text(
                  'Tümünü gör ($_totalReviewCount)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FoodColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2F2219) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz değerlendirme yok',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bu ürünü ilk değerlendiren siz olun!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_reviews.take(3).map((review) => _buildReviewCard(review, isDark))),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isDark) {
    final rating = review['rating'] as int? ?? 5;
    final comment = review['comment'] as String? ?? '';
    final customerName = review['customer_name'] as String? ?? 'Anonim';

    // Get initials for avatar
    final nameParts = customerName.split(' ');
    String initials = nameParts.isNotEmpty ? nameParts[0][0] : '?';
    if (nameParts.length > 1) {
      initials += nameParts[1][0];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2F2219) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: FoodColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      initials.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FoodColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    customerName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1C130D),
                    ),
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: const Color(0xFFFACC15),
                  );
                }),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FoodColors.backgroundDark : const Color(0xFFF8F7F5),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cart Action Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Quantity Stepper
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2F2219) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove,
                          size: 20,
                          color: _quantity > 1 ? Colors.grey[500] : Colors.grey[300],
                        ),
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                      ),
                      Text(
                        _quantity.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1C130D),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 20, color: Colors.grey[500]),
                        onPressed: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Add to Cart Button
                Expanded(
                  child: GestureDetector(
                    key: _addButtonKey,
                    onTap: () async {
                      if (_isAnimating) return;

                      // Check if all required options are selected
                      final missingRequired = <String>[];
                      for (final group in _optionGroups) {
                        final isRequired = group['isRequired'] as bool? ?? false;
                        final selectedIndices = group['selectedIndices'] as Set<int>? ?? {};
                        if (isRequired && selectedIndices.isEmpty) {
                          missingRequired.add(group['name'] as String? ?? 'Seçenek');
                        }
                      }

                      if (missingRequired.isNotEmpty) {
                        await AppDialogs.showError(context, 'Lütfen zorunlu seçenekleri belirleyin: ${missingRequired.join(", ")}');
                        return;
                      }

                      setState(() => _isAnimating = true);

                      // Build extra info string from selected options
                      String? extraInfo;
                      final selectedOptions = <String>[];
                      for (final group in _optionGroups) {
                        final selectedIndices = group['selectedIndices'] as Set<int>? ?? {};
                        final options = group['options'] as List<Map<String, dynamic>>? ?? [];
                        for (final index in selectedIndices) {
                          if (index < options.length) {
                            selectedOptions.add(options[index]['name'] as String? ?? '');
                          }
                        }
                      }
                      if (selectedOptions.isNotEmpty) {
                        extraInfo = selectedOptions.join(', ');
                      }

                      // Get merchantId from database
                      String? merchantId;
                      try {
                        final menuItemResponse = await Supabase.instance.client
                            .from('menu_items')
                            .select('merchant_id')
                            .eq('id', widget.itemId)
                            .maybeSingle();
                        merchantId = menuItemResponse?['merchant_id'] as String?;
                      } catch (e) {
                        if (kDebugMode) print('Error fetching merchant_id: $e');
                      }

                      // Add item to cart
                      final cartItem = CartItem(
                        id: '${widget.itemId}_${DateTime.now().millisecondsSinceEpoch}',
                        name: widget.name,
                        description: widget.description,
                        extra: extraInfo,
                        price: _totalPrice / _quantity,
                        quantity: _quantity,
                        imageUrl: widget.imageUrl,
                        merchantId: merchantId,
                        merchantName: widget.restaurantName,
                        type: 'food',
                      );
                      ref.read(cartProvider.notifier).addItem(cartItem);

                      // Trigger flying animation
                      CartAnimationHelper.animateToCart(
                        context: context,
                        startKey: _addButtonKey,
                        endKey: _cartTargetKey,
                        imageUrl: widget.imageUrl,
                        onComplete: () {
                          setState(() => _isAnimating = false);
                          _cartBounceKey.currentState?.bounce();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${widget.name} sepete eklendi'),
                              backgroundColor: FoodColors.primary,
                              duration: const Duration(milliseconds: 1500),
                            ),
                          );
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) context.pop();
                          });
                        },
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: FoodColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: FoodColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Text(
                              'Sepete Ekle',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          CartIconBounce(
                            key: _cartBounceKey,
                            child: Container(
                              key: _cartTargetKey,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_totalPrice.toInt()} TL',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Navigation
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A120D) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                ),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, 'Ana Sayfa', false, isDark, '/'),
                _buildNavItem(Icons.favorite, 'Favoriler', false, isDark, '/favorites'),
                _buildNavItem(Icons.receipt_long, 'Siparişlerim', false, isDark, '/orders'),
                _buildNavItem(Icons.person, 'Profil', false, isDark, '/profile'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, bool isDark, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.go(route),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? FoodColors.primary
                  : (isDark ? Colors.grey[400] : Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? FoodColors.primary
                    : (isDark ? Colors.grey[400] : Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
