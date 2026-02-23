import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';

// ============================================
// REVIEW SERVICE PROVIDER
// ============================================

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

// ============================================
// REVIEWS LIST PROVIDER
// ============================================

final reviewsProvider = FutureProvider<List<RealtorReview>>((ref) async {
  final service = ref.watch(reviewServiceProvider);
  return service.getReviews();
});

// ============================================
// REVIEW STATS PROVIDER
// ============================================

/// Returns: averageRating, totalReviews, ratingDistribution,
/// avgCommunication, avgProfessionalism, avgKnowledge
final reviewStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(reviewServiceProvider);
  return service.getReviewStats();
});
