import 'package:flutter/material.dart';
import '../../../models/taxi/driver_review_models.dart';
import '../../../core/services/taxi_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/name_masking.dart';

class ReviewReplySheet extends StatefulWidget {
  final DriverReview review;
  final VoidCallback? onReplied;

  const ReviewReplySheet({
    super.key,
    required this.review,
    this.onReplied,
  });

  static Future<void> show(
    BuildContext context,
    DriverReview review, {
    VoidCallback? onReplied,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewReplySheet(
        review: review,
        onReplied: onReplied,
      ),
    );
  }

  @override
  State<ReviewReplySheet> createState() => _ReviewReplySheetState();
}

class _ReviewReplySheetState extends State<ReviewReplySheet> {
  late TextEditingController _controller;
  bool _isSubmitting = false;
  final int _maxLength = 500;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.review.driverReply ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final reply = _controller.text.trim();
    if (reply.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await TaxiService.replyToReview(
        reviewId: widget.review.id,
        reply: reply,
      );

      if (mounted) {
        widget.onReplied?.call();
        Navigator.pop(context);
        await AppDialogs.showSuccess(context, 'Cevabınız kaydedildi');
      }
    } catch (e) {
      if (mounted) {
        await AppDialogs.showError(context, 'Hata: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteReply() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cevabı Sil'),
        content: const Text('Cevabınızı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      await TaxiService.deleteReviewReply(widget.review.id);

      if (mounted) {
        widget.onReplied?.call();
        Navigator.pop(context);
        await AppDialogs.showSuccess(context, 'Cevap silindi');
      }
    } catch (e) {
      if (mounted) {
        await AppDialogs.showError(context, 'Hata: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  widget.review.hasReply ? 'Cevabı Düzenle' : 'Cevap Yaz',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.review.hasReply)
                  IconButton(
                    onPressed: _isSubmitting ? null : _deleteReply,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.red,
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          // Review summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Customer name
                    Text(
                      maskUserName(widget.review.customerName),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Rating
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < widget.review.rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
                if (widget.review.comment != null &&
                    widget.review.comment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.review.comment!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Reply field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: _maxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Müşteriye cevabınızı yazın...',
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
                counterText: '${_controller.text.length}/$_maxLength',
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          const SizedBox(height: 20),

          // Submit button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting || _controller.text.trim().isEmpty
                    ? null
                    : _submitReply,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.review.hasReply ? 'Güncelle' : 'Gönder',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
