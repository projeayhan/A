import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_model.dart';

/// Singleton service for realtor review operations
class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String get _realtorId => _client.auth.currentUser!.id;

  // ==================== SORGULAMA ====================

  /// Fetch reviews for the current realtor, joined with user_profiles
  Future<List<RealtorReview>> getReviews() async {
    final response = await _client
        .from('realtor_reviews')
        .select('*, users!realtor_reviews_users_fkey(full_name, avatar_url)')
        .eq('realtor_id', _realtorId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => RealtorReview.fromJson(json))
        .toList();
  }

  /// Get aggregated review statistics
  /// Returns: averageRating, totalReviews, ratingDistribution (1-5 -> count),
  /// avgCommunication, avgProfessionalism, avgKnowledge
  Future<Map<String, dynamic>> getReviewStats() async {
    final response = await _client
        .from('realtor_reviews')
        .select(
            'rating, communication_rating, professionalism_rating, knowledge_rating')
        .eq('realtor_id', _realtorId);

    final reviews = response as List;
    final totalReviews = reviews.length;

    if (totalReviews == 0) {
      return {
        'averageRating': 0.0,
        'totalReviews': 0,
        'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        'avgCommunication': 0.0,
        'avgProfessionalism': 0.0,
        'avgKnowledge': 0.0,
      };
    }

    // Calculate average rating
    double totalRating = 0;
    final ratingDistribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    double totalCommunication = 0;
    int communicationCount = 0;
    double totalProfessionalism = 0;
    int professionalismCount = 0;
    double totalKnowledge = 0;
    int knowledgeCount = 0;

    for (final review in reviews) {
      final rating = review['rating'] as int;
      totalRating += rating;
      ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;

      if (review['communication_rating'] != null) {
        totalCommunication += (review['communication_rating'] as int);
        communicationCount++;
      }
      if (review['professionalism_rating'] != null) {
        totalProfessionalism += (review['professionalism_rating'] as int);
        professionalismCount++;
      }
      if (review['knowledge_rating'] != null) {
        totalKnowledge += (review['knowledge_rating'] as int);
        knowledgeCount++;
      }
    }

    return {
      'averageRating': totalRating / totalReviews,
      'totalReviews': totalReviews,
      'ratingDistribution': ratingDistribution,
      'avgCommunication':
          communicationCount > 0 ? totalCommunication / communicationCount : 0.0,
      'avgProfessionalism': professionalismCount > 0
          ? totalProfessionalism / professionalismCount
          : 0.0,
      'avgKnowledge':
          knowledgeCount > 0 ? totalKnowledge / knowledgeCount : 0.0,
    };
  }

  // ==================== YANIT VERME ====================

  /// Respond to a review (update realtor_response and responded_at)
  Future<void> respondToReview(String reviewId, String response) async {
    await _client
        .from('realtor_reviews')
        .update({
          'realtor_response': response,
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reviewId)
        .eq('realtor_id', _realtorId);
  }
}
