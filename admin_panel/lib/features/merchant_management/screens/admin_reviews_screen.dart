import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';
import '../../../core/services/supabase_service.dart';

class AdminReviewsScreen extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;
  const AdminReviewsScreen({super.key, required this.entityType, required this.entityId});

  @override
  ConsumerState<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends ConsumerState<AdminReviewsScreen> {
  String _sortBy = 'newest';
  String _filterRating = 'all';

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(
      entityReviewsProvider((entityType: widget.entityType, entityId: widget.entityId)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yorumlar',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.entityType} yorumlarini goruntuleyin ve yonetin.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildSortDropdown(),
                    const SizedBox(width: 12),
                    _buildFilterDropdown(),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => ref.invalidate(
                        entityReviewsProvider((entityType: widget.entityType, entityId: widget.entityId)),
                      ),
                      icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                      tooltip: 'Yenile',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: reviewsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Yorumlar yuklenirken hata olustu',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(
                          entityReviewsProvider((entityType: widget.entityType, entityId: widget.entityId)),
                        ),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'Henuz yorum bulunmuyor',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredReviews = _applyFilters(reviews);
                  final sortedReviews = _applySorting(filteredReviews);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating distribution sidebar
                      SizedBox(
                        width: 320,
                        child: _buildRatingDistribution(reviews),
                      ),
                      const SizedBox(width: 24),
                      // Reviews list
                      Expanded(
                        child: ListView.separated(
                          itemCount: sortedReviews.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildReviewCard(sortedReviews[index]);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          items: const [
            DropdownMenuItem(value: 'newest', child: Text('En Yeni')),
            DropdownMenuItem(value: 'oldest', child: Text('En Eski')),
            DropdownMenuItem(value: 'highest', child: Text('En Yuksek Puan')),
            DropdownMenuItem(value: 'lowest', child: Text('En Dusuk Puan')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _sortBy = value);
          },
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterRating,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tum Puanlar')),
            DropdownMenuItem(value: '5', child: Text('5 Yildiz')),
            DropdownMenuItem(value: '4', child: Text('4 Yildiz')),
            DropdownMenuItem(value: '3', child: Text('3 Yildiz')),
            DropdownMenuItem(value: '2', child: Text('2 Yildiz')),
            DropdownMenuItem(value: '1', child: Text('1 Yildiz')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _filterRating = value);
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> reviews) {
    if (_filterRating == 'all') return reviews;
    final rating = int.tryParse(_filterRating);
    if (rating == null) return reviews;
    return reviews.where((r) => (r['rating'] as num?)?.toInt() == rating).toList();
  }

  List<Map<String, dynamic>> _applySorting(List<Map<String, dynamic>> reviews) {
    final sorted = List<Map<String, dynamic>>.from(reviews);
    switch (_sortBy) {
      case 'newest':
        sorted.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        break;
      case 'oldest':
        sorted.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
        break;
      case 'highest':
        sorted.sort((a, b) => ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0));
        break;
      case 'lowest':
        sorted.sort((a, b) => ((a['rating'] as num?) ?? 0).compareTo((b['rating'] as num?) ?? 0));
        break;
    }
    return sorted;
  }

  Widget _buildRatingDistribution(List<Map<String, dynamic>> reviews) {
    final totalReviews = reviews.length;
    final ratingCounts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    double totalRating = 0;

    for (final review in reviews) {
      final rating = (review['rating'] as num?)?.toInt() ?? 0;
      if (rating >= 1 && rating <= 5) {
        ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
      }
      totalRating += (review['rating'] as num?)?.toDouble() ?? 0;
    }

    final averageRating = totalReviews > 0 ? totalRating / totalReviews : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Average rating
          Text(
            averageRating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Icon(
                index < averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppColors.warning,
                size: 24,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalReviews yorum',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ortalama Puan',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.surfaceLight),
          const SizedBox(height: 16),

          // Rating bars
          ...List.generate(5, (index) {
            final star = 5 - index;
            final count = ratingCounts[star] ?? 0;
            final percentage = totalReviews > 0 ? count / totalReviews : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '$star',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          star >= 4
                              ? AppColors.success
                              : star == 3
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final user = review['users'] as Map<String, dynamic>?;
    final userName = user?['full_name'] ?? 'Anonim';
    final avatarUrl = user?['avatar_url'] as String?;
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final createdAt = review['created_at'] as String?;
    final isHidden = review['is_hidden'] as bool? ?? false;
    final reviewId = review['id'] as String;

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.'
            '${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHidden ? AppColors.surface.withValues(alpha: 0.5) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHidden ? AppColors.warning.withValues(alpha: 0.3) : AppColors.surfaceLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
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
                    index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 18,
                  );
                }),
              ),
              const SizedBox(width: 16),
              // Hidden badge
              if (isHidden)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Gizli',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Actions
              _buildActionButton(
                icon: isHidden ? Icons.visibility : Icons.visibility_off,
                tooltip: isHidden ? 'Goster' : 'Gizle',
                color: AppColors.info,
                onPressed: () => _toggleHideReview(reviewId, isHidden),
              ),
              const SizedBox(width: 4),
              _buildActionButton(
                icon: Icons.delete_outline,
                tooltip: 'Sil',
                color: AppColors.error,
                onPressed: () => _confirmDeleteReview(reviewId),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: isHidden ? AppColors.textMuted : AppColors.textSecondary,
                fontStyle: isHidden ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Future<void> _toggleHideReview(String reviewId, bool currentlyHidden) async {
    try {
      final client = ref.read(supabaseProvider);
      await client.from('reviews').update({'is_hidden': !currentlyHidden}).eq('id', reviewId);
      ref.invalidate(
        entityReviewsProvider((entityType: widget.entityType, entityId: widget.entityId)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyHidden ? 'Yorum gorunur yapildi' : 'Yorum gizlendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Islem basarisiz: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Yorumu Sil',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Bu yorumu silmek istediginizden emin misiniz? Bu islem geri alinamaz.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(supabaseProvider);
        await client.from('reviews').delete().eq('id', reviewId);
        ref.invalidate(
          entityReviewsProvider((entityType: widget.entityType, entityId: widget.entityId)),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yorum basariyla silindi'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme islemi basarisiz: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
