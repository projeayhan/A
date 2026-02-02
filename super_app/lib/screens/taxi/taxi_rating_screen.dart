import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/taxi/taxi_models.dart';
import '../../models/taxi/driver_review_models.dart';
import '../../core/services/taxi_service.dart';
import '../../core/router/app_router.dart';

class TaxiRatingScreen extends ConsumerStatefulWidget {
  final TaxiRide ride;

  const TaxiRatingScreen({
    super.key,
    required this.ride,
  });

  @override
  ConsumerState<TaxiRatingScreen> createState() => _TaxiRatingScreenState();
}

class _TaxiRatingScreenState extends ConsumerState<TaxiRatingScreen>
    with TickerProviderStateMixin {
  int _rating = 5;
  String _comment = '';
  double _tipAmount = 0;
  List<String> _selectedTagKeys = [];
  bool _isSubmitting = false;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Feedback tags from database - varsayılan değerlerle başla
  List<TaxiFeedbackTag> _positiveTags = [
    TaxiFeedbackTag(id: '1', tagKey: 'clean_vehicle', tagText: 'Temiz araç', category: 'positive'),
    TaxiFeedbackTag(id: '2', tagKey: 'safe_driving', tagText: 'Güvenli sürüş', category: 'positive'),
    TaxiFeedbackTag(id: '3', tagKey: 'friendly', tagText: 'Güler yüzlü', category: 'positive'),
    TaxiFeedbackTag(id: '4', tagKey: 'good_route', tagText: 'İyi rota', category: 'positive'),
  ];
  List<TaxiFeedbackTag> _negativeTags = [
    TaxiFeedbackTag(id: '5', tagKey: 'dirty_vehicle', tagText: 'Kirli araç', category: 'negative'),
    TaxiFeedbackTag(id: '6', tagKey: 'rude_driver', tagText: 'Kaba davranış', category: 'negative'),
    TaxiFeedbackTag(id: '7', tagKey: 'bad_route', tagText: 'Kötü rota', category: 'negative'),
    TaxiFeedbackTag(id: '8', tagKey: 'unsafe_driving', tagText: 'Tehlikeli sürüş', category: 'negative'),
  ];

  // Tip options
  final List<double> _tipOptions = [0, 5, 10, 20];

  @override
  void initState() {
    super.initState();
    debugPrint('TaxiRatingScreen: initState started');

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();

    _loadFeedbackTags();
    debugPrint('TaxiRatingScreen: initState completed');
  }

  Future<void> _loadFeedbackTags() async {
    debugPrint('TaxiRatingScreen: _loadFeedbackTags started');
    // Varsayılan etiketler zaten ayarlı, sadece veritabanından güncellemeyi dene
    try {
      debugPrint('TaxiRatingScreen: Calling TaxiService.getFeedbackTags');
      final tagsData = await TaxiService.getFeedbackTags()
          .timeout(const Duration(seconds: 3), onTimeout: () {
            debugPrint('TaxiRatingScreen: TaxiService.getFeedbackTags TIMEOUT');
            return <Map<String, dynamic>>[];
          });
      debugPrint('TaxiRatingScreen: Tags loaded, count: ${tagsData.length}');

      // Sadece başarılı bir şekilde veri geldiyse güncelle
      if (mounted && tagsData.isNotEmpty) {
        setState(() {
          final allTags = tagsData.map((t) => TaxiFeedbackTag.fromJson(t)).toList();
          _positiveTags = allTags.where((t) => t.isPositive).toList();
          _negativeTags = allTags.where((t) => t.isNegative).toList();
        });
        debugPrint('TaxiRatingScreen: State updated with tags from database');
      }
    } catch (e) {
      debugPrint('TaxiRatingScreen: Error loading feedback tags: $e');
      // Hata durumunda varsayılan etiketler zaten mevcut, bir şey yapmaya gerek yok
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);

    try {
      await TaxiService.rateRideWithDetails(
        rideId: widget.ride.id,
        rating: _rating,
        comment: _comment.isNotEmpty ? _comment : null,
        tipAmount: _tipAmount > 0 ? _tipAmount : null,
        feedbackTags: _selectedTagKeys.isNotEmpty ? _selectedTagKeys : null,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Değerlendirme gönderilemedi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Teşekkürler!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Değerlendirmeniz için teşekkür ederiz',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                context.go(AppRoutes.home); // Go back to home
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Tamam'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Yolculuğu Değerlendir'),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Driver info
              _buildDriverCard(theme, colorScheme),

              const SizedBox(height: 32),

              // Star rating
              ScaleTransition(
                scale: _scaleAnimation,
                child: _buildStarRating(theme, colorScheme),
              ),

              const SizedBox(height: 24),

              // Rating message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _getRatingMessage(),
                  key: ValueKey(_rating),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _getRatingColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Feedback tags
              _buildFeedbackTags(theme, colorScheme),

              const SizedBox(height: 24),

              // Comment field
              _buildCommentField(theme, colorScheme),

              const SizedBox(height: 32),

              // Tip section
              _buildTipSection(theme, colorScheme),

              const SizedBox(height: 32),

              // Submit button
              _buildSubmitButton(theme, colorScheme),

              const SizedBox(height: 16),

              // Skip button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Şimdi değil',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard(ThemeData theme, ColorScheme colorScheme) {
    final driver = widget.ride.driver;
    if (driver == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              image: driver.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(driver.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: driver.avatarUrl == null
                ? Icon(
                    Icons.person_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 32,
                  )
                : null,
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  driver.vehicleInfo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Fare
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.ride.fare.toStringAsFixed(2)} TL',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                '${widget.ride.distanceKm.toStringAsFixed(1)} km',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => setState(() => _rating = starIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            child: Icon(
              starIndex <= _rating
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 48,
              color: starIndex <= _rating
                  ? Colors.amber
                  : colorScheme.outlineVariant,
            ),
          ),
        );
      }),
    );
  }

  String _getRatingMessage() {
    switch (_rating) {
      case 1:
        return 'Çok kötü';
      case 2:
        return 'Kötü';
      case 3:
        return 'Orta';
      case 4:
        return 'İyi';
      case 5:
        return 'Mükemmel!';
      default:
        return '';
    }
  }

  Color _getRatingColor() {
    switch (_rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFeedbackTags(ThemeData theme, ColorScheme colorScheme) {
    final tags = _rating >= 4 ? _positiveTags : _negativeTags;

    if (tags.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _rating >= 4 ? 'Neyi beğendiniz?' : 'Sorun neydi?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = _selectedTagKeys.contains(tag.tagKey);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTagKeys.remove(tag.tagKey);
                  } else {
                    _selectedTagKeys.add(tag.tagKey);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  tag.tagText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCommentField(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yorum ekle (isteğe bağlı)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          maxLines: 3,
          maxLength: 500,
          onChanged: (value) => _comment = value,
          decoration: InputDecoration(
            hintText: 'Deneyiminizi paylaşın...',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.volunteer_activism_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Bahşiş bırak',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sürücüye teşekkür etmek ister misiniz?',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _tipOptions.map((amount) {
            final isSelected = _tipAmount == amount;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tipAmount = amount),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: amount != _tipOptions.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    amount == 0 ? 'Yok' : '${amount.toInt()} TL',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submitRating,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded),
                  const SizedBox(width: 8),
                  Text(
                    _tipAmount > 0
                        ? 'Gönder (${_tipAmount.toInt()} TL bahşiş)'
                        : 'Değerlendirmeyi Gönder',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
