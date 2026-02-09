import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/jobs/job_data_models.dart';

/// AI Moderasyon sonucu
class ModerationResult {
  final bool success;
  final String result; // approved, rejected, manual_review
  final int? score;
  final bool? isAppropriate;
  final List<String> flags;
  final String? reason;
  final List<String> matchedKeywords;

  ModerationResult({
    required this.success,
    required this.result,
    this.score,
    this.isAppropriate,
    this.flags = const [],
    this.reason,
    this.matchedKeywords = const [],
  });

  factory ModerationResult.fromJson(Map<String, dynamic> json) {
    return ModerationResult(
      success: json['success'] as bool? ?? false,
      result: json['result'] as String? ?? json['moderation_status'] as String? ?? 'pending',
      score: json['score'] as int? ?? json['ai_score'] as int?,
      isAppropriate: json['is_appropriate'] as bool?,
      flags: (json['flags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      reason: json['reason'] as String? ?? json['ai_reason'] as String?,
      matchedKeywords: (json['matched_keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  bool get isApproved => result == 'approved';
  bool get isRejected => result == 'rejected';
  bool get needsReview => result == 'manual_review' || result == 'pending';
}

/// İş İlanları Servisi - Supabase Entegrasyonu
/// SuperCyp için iş ilanı işlemleri
class JobsService {
  static final JobsService _instance = JobsService._internal();
  static JobsService get instance => _instance;
  factory JobsService() => _instance;
  JobsService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== KATEGORİLER ====================

  /// Kategorileri getir
  Future<List<JobCategoryData>> getCategories() async {
    try {
      final response = await _client
          .from('job_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => JobCategoryData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getCategories error: $e');
      return [];
    }
  }

  /// Alt kategorileri getir
  Future<List<JobSubcategoryData>> getSubcategories(String categoryId) async {
    try {
      final response = await _client
          .from('job_subcategories')
          .select()
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => JobSubcategoryData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getSubcategories error: $e');
      return [];
    }
  }

  // ==================== YETENEKLER ====================

  /// Yetenekleri getir
  Future<List<JobSkillData>> getSkills({bool popularOnly = false, String? jobCategoryId}) async {
    try {
      var query = _client.from('job_skills').select();

      if (popularOnly) {
        query = query.eq('is_popular', true);
      }

      // Job kategorisine göre filtrele
      if (jobCategoryId != null) {
        query = query.contains('job_category_ids', [jobCategoryId]);
      }

      final response = await query.order('usage_count', ascending: false);

      return (response as List)
          .map((json) => JobSkillData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getSkills error: $e');
      return [];
    }
  }

  // ==================== YAN HAKLAR ====================

  /// Yan hakları getir
  Future<List<JobBenefitData>> getBenefits() async {
    try {
      final response = await _client
          .from('job_benefits')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => JobBenefitData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getBenefits error: $e');
      return [];
    }
  }

  // ==================== ŞİRKETLER ====================

  /// Şirket profili getir
  Future<CompanyData?> getCompany(String companyId) async {
    try {
      final response = await _client
          .from('companies')
          .select()
          .eq('id', companyId)
          .single();

      return CompanyData.fromJson(response);
    } catch (e) {
      debugPrint('JobsService.getCompany error: $e');
      return null;
    }
  }

  /// Kullanıcının şirketini getir
  Future<CompanyData?> getUserCompany() async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from('companies')
          .select()
          .eq('user_id', _userId!)
          .maybeSingle();

      if (response == null) return null;
      return CompanyData.fromJson(response);
    } catch (e) {
      debugPrint('JobsService.getUserCompany error: $e');
      return null;
    }
  }

  /// Şirket oluştur
  Future<CompanyData?> createCompany(Map<String, dynamic> data) async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from('companies')
          .insert({
            ...data,
            'user_id': _userId,
          })
          .select()
          .single();

      return CompanyData.fromJson(response);
    } catch (e) {
      debugPrint('JobsService.createCompany error: $e');
      return null;
    }
  }

  // ==================== İŞVEREN PROFİLİ ====================

  /// İşveren profili getir veya oluştur
  Future<JobPosterData?> getOrCreatePoster() async {
    if (_userId == null) return null;

    try {
      // Mevcut profil var mı kontrol et
      var response = await _client
          .from('job_posters')
          .select('*, company:company_id(*)')
          .eq('user_id', _userId!)
          .maybeSingle();

      if (response != null) {
        return JobPosterData.fromJson(response);
      }

      // Profil yoksa oluştur
      final user = _client.auth.currentUser;
      final newPoster = await _client
          .from('job_posters')
          .insert({
            'user_id': _userId,
            'name': user?.userMetadata?['full_name'] ?? 'İsimsiz',
            'email': user?.email,
            'phone': user?.phone ?? '',
          })
          .select('*, company:company_id(*)')
          .single();

      return JobPosterData.fromJson(newPoster);
    } catch (e) {
      debugPrint('JobsService.getOrCreatePoster error: $e');
      return null;
    }
  }

  // ==================== İŞ İLANLARI ====================

  /// Aktif ilanları getir (ana sayfa için)
  Future<List<JobListingData>> getActiveListings({
    String? categoryId,
    String? jobType,
    String? workArrangement,
    String? experienceLevel,
    String? city,
    double? minSalary,
    double? maxSalary,
    bool featuredOnly = false,
    bool urgentOnly = false,
    bool premiumOnly = false,
    String? searchQuery,
    String sortBy = 'newest',
    int limit = 20,
    int offset = 0,
  }) async {
    debugPrint('JobsService.getActiveListings: START - categoryId=$categoryId, limit=$limit, offset=$offset');
    try {
      // Basitleştirilmiş sorgu - önce ilanları al
      var query = _client
          .from('job_listings')
          .select('*')
          .eq('status', 'active');

      debugPrint('JobsService.getActiveListings: Query built successfully');

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      if (jobType != null) {
        query = query.eq('job_type', jobType);
      }
      if (workArrangement != null) {
        query = query.eq('work_arrangement', workArrangement);
      }
      if (experienceLevel != null) {
        query = query.eq('experience_level', experienceLevel);
      }
      if (city != null) {
        query = query.eq('city', city);
      }
      if (minSalary != null) {
        query = query.gte('salary_min', minSalary);
      }
      if (maxSalary != null) {
        query = query.lte('salary_max', maxSalary);
      }
      if (featuredOnly) {
        query = query.eq('is_featured', true);
      }
      if (urgentOnly) {
        query = query.eq('is_urgent', true);
      }
      if (premiumOnly) {
        query = query.eq('is_premium', true);
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.textSearch('title', searchQuery);
      }

      // Sıralama
      debugPrint('JobsService.getActiveListings: Executing query with categoryId=$categoryId');
      dynamic response;
      switch (sortBy) {
        case 'salary_high':
          response = await query.order('salary_max', ascending: false).range(offset, offset + limit - 1);
          break;
        case 'salary_low':
          response = await query.order('salary_min', ascending: true).range(offset, offset + limit - 1);
          break;
        case 'most_viewed':
          response = await query.order('view_count', ascending: false).range(offset, offset + limit - 1);
          break;
        case 'deadline':
          response = await query.order('deadline', ascending: true).range(offset, offset + limit - 1);
          break;
        case 'oldest':
          response = await query.order('created_at', ascending: true).range(offset, offset + limit - 1);
          break;
        case 'newest':
        default:
          response = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
          break;
      }

      final responseList = response as List;
      debugPrint('JobsService.getActiveListings: Got ${responseList.length} listings from database');
      if (responseList.isNotEmpty) {
        debugPrint('JobsService.getActiveListings: First listing: ${responseList.first}');
      }
      return responseList
          .map((json) => JobListingData.fromJson(json))
          .toList();
    } catch (e, stack) {
      debugPrint('JobsService.getActiveListings error: $e');
      debugPrint('Stack trace: $stack');
      return [];
    }
  }

  /// Featured ilanları getir
  Future<List<JobListingData>> getFeaturedListings({int limit = 10}) async {
    return getActiveListings(featuredOnly: true, limit: limit);
  }

  /// Acil ilanları getir
  Future<List<JobListingData>> getUrgentListings({int limit = 10}) async {
    return getActiveListings(urgentOnly: true, limit: limit);
  }

  /// Premium ilanları getir
  Future<List<JobListingData>> getPremiumListings({int limit = 10}) async {
    return getActiveListings(premiumOnly: true, limit: limit);
  }

  /// Kategoriye göre ilanları getir
  Future<List<JobListingData>> getListingsByCategory(String categoryId, {int limit = 20}) async {
    return getActiveListings(categoryId: categoryId, limit: limit);
  }

  /// Tek ilan detayı getir
  Future<JobListingData?> getListing(String listingId) async {
    try {
      final response = await _client
          .from('job_listings')
          .select('''
            *,
            poster:poster_id (
              id, name, title, phone, email, image_url, is_verified,
              active_listings, total_hires, response_rate, avg_response_time
            ),
            company:company_id (
              id, name, logo_url, website, industry, size, description,
              city, is_verified, is_premium, rating, review_count
            )
          ''')
          .eq('id', listingId)
          .single();

      return JobListingData.fromJson(response);
    } catch (e) {
      debugPrint('JobsService.getListing error: $e');
      return null;
    }
  }

  /// İlan yeteneklerini getir
  Future<List<JobSkillData>> getListingSkills(String listingId) async {
    try {
      final response = await _client
          .from('job_listing_skills')
          .select('skill:skill_id(*), is_required')
          .eq('listing_id', listingId);

      return (response as List).map((json) {
        final skill = JobSkillData.fromJson(json['skill']);
        return skill.copyWith(isRequired: json['is_required'] as bool);
      }).toList();
    } catch (e) {
      debugPrint('JobsService.getListingSkills error: $e');
      return [];
    }
  }

  /// İlan yan haklarını getir
  Future<List<JobBenefitData>> getListingBenefits(String listingId) async {
    try {
      final response = await _client
          .from('job_listing_benefits')
          .select('benefit:benefit_id(*)')
          .eq('listing_id', listingId);

      return (response as List)
          .map((json) => JobBenefitData.fromJson(json['benefit']))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getListingBenefits error: $e');
      return [];
    }
  }

  /// Kullanıcının ilanlarını getir
  Future<List<JobListingData>> getUserListings({String? status}) async {
    if (_userId == null) return [];

    try {
      var query = _client
          .from('job_listings')
          .select('''
            *,
            company:company_id (
              id, name, logo_url
            )
          ''')
          .eq('user_id', _userId!);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => JobListingData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getUserListings error: $e');
      return [];
    }
  }

  /// Yeni ilan oluştur
  Future<JobListingData?> createListing(Map<String, dynamic> data) async {
    if (_userId == null) return null;

    try {
      // Poster'ı al veya oluştur
      final poster = await getOrCreatePoster();

      final response = await _client
          .from('job_listings')
          .insert({
            ...data,
            'user_id': _userId,
            'poster_id': poster?.id,
            'status': 'pending', // Admin onayı gerekiyor
          })
          .select()
          .single();

      final listing = JobListingData.fromJson(response);

      // AI Moderasyon çağır (arka planda)
      // Moderasyon artık add_job_listing_screen'de çağrılacak
      // moderateListing(listing.id);

      return listing;
    } catch (e) {
      debugPrint('JobsService.createListing error: $e');
      return null;
    }
  }

  /// AI Moderasyon Edge Function çağır (public - sonuç döndürür)
  Future<ModerationResult?> moderateListing(String listingId) async {
    try {
      final response = await _client.functions.invoke(
        'moderate-listing',
        body: {'type': 'job', 'listing_id': listingId},
      );

      if (response.status == 200 && response.data != null) {
        return ModerationResult.fromJson(response.data as Map<String, dynamic>);
      }

      debugPrint('Moderation response: ${response.status} - ${response.data}');
      return null;
    } catch (e) {
      debugPrint('JobsService._moderateListing error: $e');
      return null;
    }
  }

  /// Moderasyon sonucunu al
  Future<ModerationResult?> getModerationResult(String listingId) async {
    try {
      final response = await _client
          .from('content_moderation')
          .select()
          .eq('listing_type', 'job')
          .eq('listing_id', listingId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ModerationResult.fromJson(response);
    } catch (e) {
      debugPrint('JobsService.getModerationResult error: $e');
      return null;
    }
  }

  /// İlan güncelle
  Future<bool> updateListing(String listingId, Map<String, dynamic> data) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('job_listings')
          .update(data)
          .eq('id', listingId)
          .eq('user_id', _userId!);

      return true;
    } catch (e) {
      debugPrint('JobsService.updateListing error: $e');
      return false;
    }
  }

  /// İlan sil
  Future<bool> deleteListing(String listingId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('job_listings')
          .delete()
          .eq('id', listingId)
          .eq('user_id', _userId!);

      return true;
    } catch (e) {
      debugPrint('JobsService.deleteListing error: $e');
      return false;
    }
  }

  /// İlan yeteneklerini kaydet
  Future<bool> saveListingSkills(String listingId, List<String> skillIds, {List<String>? requiredSkillIds}) async {
    try {
      // Önce mevcut yetenekleri sil
      await _client
          .from('job_listing_skills')
          .delete()
          .eq('listing_id', listingId);

      // Yeni yetenekleri ekle
      if (skillIds.isNotEmpty) {
        final skills = skillIds.map((skillId) => {
          'listing_id': listingId,
          'skill_id': skillId,
          'is_required': requiredSkillIds?.contains(skillId) ?? true,
        }).toList();

        await _client.from('job_listing_skills').insert(skills);
      }

      return true;
    } catch (e) {
      debugPrint('JobsService.saveListingSkills error: $e');
      return false;
    }
  }

  /// İlan yan haklarını kaydet
  Future<bool> saveListingBenefits(String listingId, List<String> benefitIds) async {
    try {
      // Önce mevcut yan hakları sil
      await _client
          .from('job_listing_benefits')
          .delete()
          .eq('listing_id', listingId);

      // Yeni yan hakları ekle
      if (benefitIds.isNotEmpty) {
        final benefits = benefitIds.map((benefitId) => {
          'listing_id': listingId,
          'benefit_id': benefitId,
        }).toList();

        await _client.from('job_listing_benefits').insert(benefits);
      }

      return true;
    } catch (e) {
      debugPrint('JobsService.saveListingBenefits error: $e');
      return false;
    }
  }

  // ==================== BAŞVURULAR ====================

  /// İlana başvur
  Future<JobApplicationData?> applyToListing({
    required String listingId,
    required String name,
    required String email,
    String? phone,
    String? coverLetter,
    String? resumeUrl,
    List<String>? portfolioLinks,
  }) async {
    if (_userId == null) return null;

    try {
      // Daha önce başvuru yapılmış mı kontrol et
      final existing = await _client
          .from('job_applications')
          .select('id')
          .eq('listing_id', listingId)
          .eq('user_id', _userId!)
          .maybeSingle();

      if (existing != null) {
        debugPrint('JobsService.applyToListing: Already applied');
        return null;
      }

      final response = await _client
          .from('job_applications')
          .insert({
            'listing_id': listingId,
            'user_id': _userId,
            'applicant_name': name,
            'applicant_email': email,
            'applicant_phone': phone,
            'cover_letter': coverLetter,
            'resume_url': resumeUrl,
            'portfolio_links': portfolioLinks,
          })
          .select()
          .single();

      return JobApplicationData.fromJson(response);
    } catch (e) {
      debugPrint('JobsService.applyToListing error: $e');
      return null;
    }
  }

  /// Kullanıcının başvurularını getir
  Future<List<JobApplicationData>> getUserApplications() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('job_applications')
          .select('''
            *,
            listing:listing_id (
              id, title, city, company:company_id(name, logo_url)
            )
          ''')
          .eq('user_id', _userId!)
          .order('applied_at', ascending: false);

      return (response as List)
          .map((json) => JobApplicationData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getUserApplications error: $e');
      return [];
    }
  }

  /// İlana yapılan başvuruları getir (ilan sahibi için)
  Future<List<JobApplicationData>> getListingApplications(String listingId) async {
    try {
      final response = await _client
          .from('job_applications')
          .select()
          .eq('listing_id', listingId)
          .order('applied_at', ascending: false);

      return (response as List)
          .map((json) => JobApplicationData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getListingApplications error: $e');
      return [];
    }
  }

  /// Başvuru durumunu güncelle (ilan sahibi için)
  Future<bool> updateApplicationStatus(String applicationId, String status, {String? notes}) async {
    try {
      await _client
          .from('job_applications')
          .update({
            'status': status,
            'notes': notes,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', applicationId);

      return true;
    } catch (e) {
      debugPrint('JobsService.updateApplicationStatus error: $e');
      return false;
    }
  }

  /// Başvuru yapılmış mı kontrol et
  Future<bool> hasApplied(String listingId) async {
    if (_userId == null) return false;

    try {
      final response = await _client
          .from('job_applications')
          .select('id')
          .eq('listing_id', listingId)
          .eq('user_id', _userId!)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('JobsService.hasApplied error: $e');
      return false;
    }
  }

  // ==================== FAVORİLER ====================

  /// Favoriye ekle
  Future<bool> addToFavorites(String listingId) async {
    if (_userId == null) return false;

    try {
      await _client.from('job_favorites').insert({
        'listing_id': listingId,
        'user_id': _userId,
      });

      return true;
    } catch (e) {
      debugPrint('JobsService.addToFavorites error: $e');
      return false;
    }
  }

  /// Favoriden çıkar
  Future<bool> removeFromFavorites(String listingId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('job_favorites')
          .delete()
          .eq('listing_id', listingId)
          .eq('user_id', _userId!);

      return true;
    } catch (e) {
      debugPrint('JobsService.removeFromFavorites error: $e');
      return false;
    }
  }

  /// Favori mi kontrol et
  Future<bool> isFavorite(String listingId) async {
    if (_userId == null) return false;

    try {
      final response = await _client
          .from('job_favorites')
          .select('id')
          .eq('listing_id', listingId)
          .eq('user_id', _userId!)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('JobsService.isFavorite error: $e');
      return false;
    }
  }

  /// Favori ilanları getir
  Future<List<JobListingData>> getFavoriteListings() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('job_favorites')
          .select('''
            listing:listing_id (
              *,
              company:company_id (
                id, name, logo_url, is_verified
              )
            )
          ''')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => JobListingData.fromJson(json['listing']))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getFavoriteListings error: $e');
      return [];
    }
  }

  // ==================== GÖRÜNTÜLEME ====================

  /// İlan görüntüleme kaydet
  Future<void> incrementViewCount(String listingId, {String? sessionId}) async {
    try {
      await _client.rpc('increment_job_listing_view', params: {
        'p_listing_id': listingId,
        'p_user_id': _userId,
        'p_session_id': sessionId,
      });
    } catch (e) {
      debugPrint('JobsService.incrementViewCount error: $e');
    }
  }

  // ==================== İSTATİSTİKLER ====================

  /// Dashboard istatistikleri
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Toplam aktif ilan
      final activeListings = await _client
          .from('job_listings')
          .select('id')
          .eq('status', 'active');

      // Toplam şirket
      final companies = await _client
          .from('companies')
          .select('id')
          .eq('status', 'active');

      // Toplam kategori
      final categories = await _client
          .from('job_categories')
          .select('id')
          .eq('is_active', true);

      // Acil ilanlar
      final urgentListings = await _client
          .from('job_listings')
          .select('id')
          .eq('status', 'active')
          .eq('is_urgent', true);

      return {
        'active_listings': (activeListings as List).length,
        'companies': (companies as List).length,
        'categories': (categories as List).length,
        'urgent_listings': (urgentListings as List).length,
      };
    } catch (e) {
      debugPrint('JobsService.getDashboardStats error: $e');
      return {
        'active_listings': 0,
        'companies': 0,
        'categories': 0,
        'urgent_listings': 0,
      };
    }
  }

  // ==================== PROMOSYONLAR ====================

  /// Promosyon fiyatlarını getir
  Future<List<JobPromotionPrice>> getPromotionPrices() async {
    try {
      final response = await _client
          .from('job_promotion_prices')
          .select()
          .eq('is_active', true)
          .order('promotion_type')
          .order('duration_days');

      return (response as List)
          .map((json) => JobPromotionPrice.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobsService.getPromotionPrices error: $e');
      return [];
    }
  }

  /// Promosyon satın al
  Future<bool> purchasePromotion({
    required String listingId,
    required String promotionType,
    required int durationDays,
    required double amount,
    String? paymentMethod,
  }) async {
    if (_userId == null) return false;

    try {
      final expiresAt = DateTime.now().add(Duration(days: durationDays));

      await _client.from('job_listing_promotions').insert({
        'listing_id': listingId,
        'user_id': _userId,
        'promotion_type': promotionType,
        'duration_days': durationDays,
        'expires_at': expiresAt.toIso8601String(),
        'amount_paid': amount,
        'payment_method': paymentMethod,
        'payment_status': 'completed',
      });

      // İlan flag'lerini güncelle
      final updates = <String, dynamic>{};
      if (promotionType == 'featured') {
        updates['is_featured'] = true;
        updates['featured_until'] = expiresAt.toIso8601String();
      } else if (promotionType == 'premium') {
        updates['is_premium'] = true;
        updates['premium_until'] = expiresAt.toIso8601String();
      } else if (promotionType == 'urgent') {
        updates['is_urgent'] = true;
      }

      if (updates.isNotEmpty) {
        await _client
            .from('job_listings')
            .update(updates)
            .eq('id', listingId);
      }

      return true;
    } catch (e) {
      debugPrint('JobsService.purchasePromotion error: $e');
      return false;
    }
  }
}
