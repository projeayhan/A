import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/review_model.dart';

/// Review card widget displaying a single review with user info,
/// star rating, comment, and optional realtor response section.
class ReviewCard extends StatelessWidget {
  final RealtorReview review;
  final Function(String)? onRespond;

  const ReviewCard({
    super.key,
    required this.review,
    this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: review.reviewerAvatarUrl != null
                    ? NetworkImage(review.reviewerAvatarUrl!)
                    : null,
                child: review.reviewerAvatarUrl == null
                    ? Text(
                        _getInitials(review.displayName),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
                    Row(
                      children: [
                        Text(
                          review.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(isDark),
                            fontSize: 14,
                          ),
                        ),
                        if (review.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              color: AppColors.primary, size: 16),
                        ],
                      ],
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              // Star rating
              _buildStarRating(review.rating),
            ],
          ),

          const SizedBox(height: 12),

          // Title
          if (review.title != null && review.title!.isNotEmpty) ...[
            Text(
              review.title!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty)
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(isDark),
                height: 1.5,
              ),
            ),

          // Sub-ratings
          if (review.communicationRating != null ||
              review.professionalismRating != null ||
              review.knowledgeRating != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (review.communicationRating != null)
                  _buildSubRating(
                      'Iletisim', review.communicationRating!, isDark),
                if (review.professionalismRating != null)
                  _buildSubRating(
                      'Profesyonellik', review.professionalismRating!, isDark),
                if (review.knowledgeRating != null)
                  _buildSubRating('Bilgi', review.knowledgeRating!, isDark),
              ],
            ),
          ],

          // Realtor response section
          if (review.hasResponse) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : const Color(0xFFBAE6FD),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Yanitiniz',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      if (review.respondedAt != null) ...[
                        const Spacer(),
                        Text(
                          _formatDate(review.respondedAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted(isDark),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.realtorResponse!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Respond button (if no response yet)
          if (!review.hasResponse && onRespond != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showRespondDialog(context, isDark),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text('Yanitla'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating
              ? const Color(0xFFF59E0B)
              : const Color(0xFFCBD5E1),
          size: 18,
        );
      }),
    );
  }

  Widget _buildSubRating(String label, int value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 12, color: const Color(0xFFF59E0B)),
        const SizedBox(width: 3),
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted(isDark),
          ),
        ),
      ],
    );
  }

  void _showRespondDialog(BuildContext context, bool isDark) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Degerlendirmeye Yanit Ver',
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Review preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildStarRating(review.rating),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        review.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary(isDark),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Yanitinizi yazin...',
                  hintStyle: TextStyle(color: AppColors.textMuted(isDark)),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceDark
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border(isDark)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border(isDark)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                style: TextStyle(color: AppColors.textPrimary(isDark)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Iptal',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogContext);
                onRespond?.call(text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Gonder'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Bugun';
    } else if (diff.inDays == 1) {
      return 'Dun';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gun once';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} hafta once';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} ay once';
    }
    return '${date.day}.${date.month}.${date.year}';
  }
}
