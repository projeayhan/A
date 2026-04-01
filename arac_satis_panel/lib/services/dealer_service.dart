import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arac_satis_panel/core/services/log_service.dart';
import '../models/car_models.dart';

/// Araç Satıcısı (Dealer) Servisi
/// Satıcı başvuruları, profil yönetimi, promosyon işlemleri
class DealerService {
  static final DealerService _instance = DealerService._internal();
  static DealerService get instance => _instance;
  factory DealerService() => _instance;
  DealerService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== BAŞVURU İŞLEMLERİ ====================

  /// Satıcı başvurusu yap
  Future<Map<String, dynamic>?> submitApplication({
    required String ownerName,
    required String phone,
    required String city,
    required DealerType dealerType,
    String? businessName,
    String? email,
    String? taxNumber,
    String? district,
    String? address,
    List<Map<String, dynamic>>? documents,
  }) async {
    // Mevcut başvuru var mı kontrol et (RPC ile - RLS bypass)
    try {
      final existing = await _client.rpc('check_dealer_application_exists', params: {
        'p_phone': phone,
      });
      if (existing == true) {
        throw Exception('Bu telefon numarasıyla zaten bekleyen bir başvurunuz var');
      }
    } catch (e) {
      // RPC yoksa veya hata verirse devam et
      if (e.toString().contains('bekleyen bir başvurunuz')) rethrow;
    }

    await _client.from('car_dealer_applications').insert({
      if (_userId != null) 'user_id': _userId,
      'dealer_type': dealerType.name,
      'owner_name': ownerName,
      'business_name': businessName,
      'phone': phone,
      'email': email,
      'tax_number': taxNumber,
      'city': city,
      'district': district,
      'address': address,
      'documents': documents ?? [],
      'status': 'pending',
    });

    return {'status': 'pending'};
  }

  /// Başvuru durumunu kontrol et
  Future<Map<String, dynamic>?> getApplicationStatus() async {
    if (_userId == null) return null;

    final response = await _client
        .from('car_dealer_applications')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  // ==================== PROFİL İŞLEMLERİ ====================

  /// Satıcı profili var mı kontrol et
  Future<bool> isDealer() async {
    if (_userId == null) return false;

    final response = await _client
        .from('car_dealers')
        .select('id, status')
        .eq('user_id', _userId!)
        .eq('status', 'active')
        .maybeSingle();

    return response != null;
  }

  /// Satıcı profilini getir
  Future<CarDealer?> getDealerProfile() async {
    if (_userId == null) return null;

    final response = await _client
        .from('car_dealers')
        .select()
        .eq('user_id', _userId!)
        .maybeSingle();

    if (response == null) return null;
    return CarDealer.fromJson(response);
  }

  /// Satıcı profilini güncelle
  Future<CarDealer?> updateDealerProfile(Map<String, dynamic> updates) async {
    if (_userId == null) return null;

    final response = await _client
        .from('car_dealers')
        .update(updates)
        .eq('user_id', _userId!)
        .select()
        .single();

    return CarDealer.fromJson(response);
  }

  // ==================== İSTATİSTİKLER ====================

  /// Dashboard istatistiklerini getir
  Future<Map<String, dynamic>> getDashboardStats() async {
    if (_userId == null) {
      return _emptyStats();
    }

    try {
      // İlan sayıları
      final activeListings = await _client
          .from('car_listings')
          .select('id')
          .eq('user_id', _userId!)
          .eq('status', 'active')
          .count();

      final pendingListings = await _client
          .from('car_listings')
          .select('id')
          .eq('user_id', _userId!)
          .eq('status', 'pending')
          .count();

      final soldListings = await _client
          .from('car_listings')
          .select('id')
          .eq('user_id', _userId!)
          .eq('status', 'sold')
          .count();

      // Toplam görüntülenme
      final viewsResult = await _client
          .from('car_listings')
          .select('view_count')
          .eq('user_id', _userId!)
          .eq('status', 'active');

      int totalViews = 0;
      for (var item in viewsResult) {
        totalViews += (item['view_count'] as int? ?? 0);
      }

      // Aktif promosyonlar
      final activePromotions = await _client
          .from('car_listing_promotions')
          .select('id')
          .eq('user_id', _userId!)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .count();

      // Bugünkü mesajlar
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final todayMessages = await _client
          .from('car_contact_requests')
          .select('id')
          .inFilter('listing_id',
            (await _client.from('car_listings').select('id').eq('user_id', _userId!))
                .map((e) => e['id'] as String).toList())
          .gte('created_at', todayStart.toIso8601String())
          .count();

      return {
        'active_listings': activeListings.count,
        'pending_listings': pendingListings.count,
        'sold_listings': soldListings.count,
        'total_views': totalViews,
        'active_promotions': activePromotions.count,
        'today_messages': todayMessages.count,
      };
    } catch (e, st) {
      LogService.error('Dashboard istatistikleri alınamadı', error: e, stackTrace: st, source: 'DealerService:getDashboardStats');
      return _emptyStats();
    }
  }

  Map<String, dynamic> _emptyStats() {
    return {
      'active_listings': 0,
      'pending_listings': 0,
      'sold_listings': 0,
      'total_views': 0,
      'active_promotions': 0,
      'today_messages': 0,
    };
  }

  // ==================== PROMOSYON İŞLEMLERİ ====================

  /// Promosyon fiyatlarını getir
  Future<List<PromotionPrice>> getPromotionPrices() async {
    try {
      final response = await _client
          .from('car_promotion_prices')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => PromotionPrice.fromJson(json))
          .toList();
    } catch (e, st) {
      LogService.error('Promosyon fiyatları alınamadı', error: e, stackTrace: st, source: 'DealerService:getPromotionPrices');
      return [];
    }
  }

  /// Aktif promosyonları getir
  Future<List<CarListingPromotion>> getActivePromotions() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('car_listing_promotions')
          .select('''
            *,
            car_listings:listing_id (*)
          ''')
          .eq('user_id', _userId!)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('expires_at', ascending: true);

      return (response as List)
          .map((json) => CarListingPromotion.fromJson(json))
          .toList();
    } catch (e, st) {
      LogService.error('Aktif promosyonlar alınamadı', error: e, stackTrace: st, source: 'DealerService:getActivePromotions');
      return [];
    }
  }

  /// Promosyon oluştur.
  /// [status] = 'pending_payment' → sadece kayıt oluşturur, ilanı aktifleştirmez.
  /// [status] = 'active' (varsayılan) → kayıt + anında aktivasyon.
  Future<CarListingPromotion?> createPromotion({
    required String listingId,
    String? priceId,
    String? promotionType,
    int? durationDays,
    double? amountPaid,
    String? paymentMethod,
    String? paymentReference,
    String status = 'active',
  }) async {
    if (_userId == null) return null;

    try {
      // PriceId varsa fiyat bilgilerini çek
      String finalPromotionType = promotionType ?? 'featured';
      int finalDurationDays = durationDays ?? 7;
      double finalAmountPaid = amountPaid ?? 0;

      if (priceId != null) {
        final priceData = await _client
            .from('car_promotion_prices')
            .select()
            .eq('id', priceId)
            .single();

        finalPromotionType = priceData['promotion_type'] as String;
        finalDurationDays = priceData['duration_days'] as int;
        finalAmountPaid = (priceData['discounted_price'] as num?)?.toDouble() ??
            (priceData['price'] as num).toDouble();
      }

      // İlanın mevcut kullanıcıya ait olduğunu doğrula
      final listing = await _client
          .from('car_listings')
          .select('view_count, favorite_count, contact_count, dealer_id, user_id')
          .eq('id', listingId)
          .single();

      if (listing['user_id'] != _userId) {
        throw Exception('Bu ilana promosyon ekleme yetkiniz yok');
      }

      final expiresAt = DateTime.now().add(Duration(days: finalDurationDays));

      final response = await _client
          .from('car_listing_promotions')
          .insert({
            'listing_id': listingId,
            'user_id': _userId,
            'promotion_type': finalPromotionType,
            'duration_days': finalDurationDays,
            'started_at': DateTime.now().toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
            'amount_paid': finalAmountPaid,
            'payment_method': paymentMethod,
            'payment_reference': paymentReference,
            'status': status,
            'payment_status': status == 'active' ? 'completed' : 'pending',
            'views_before': listing['view_count'] ?? 0,
            'contacts_before': listing['contact_count'] ?? 0,
          })
          .select()
          .single();

      // Sadece status 'active' ise ilanı hemen öne çıkar
      if (status == 'active') {
        await _client.from('car_listings').update({
          'is_featured': true,
          if (finalPromotionType == 'premium') 'is_premium': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', listingId);
      }

      return CarListingPromotion.fromJson(response);
    } catch (e, st) {
      LogService.error('Promosyon oluşturulamadı', error: e, stackTrace: st, source: 'DealerService:createPromotion');
      return null;
    }
  }

  /// Bekleyen bir promosyonu aktifleştirir (webhook güvenlik ağı ile birlikte kullanılır).
  Future<bool> activatePromotion(
    String promotionId,
    String listingId,
    String promotionType,
  ) async {
    try {
      await _client
          .from('car_listing_promotions')
          .update({'status': 'active', 'payment_status': 'completed'})
          .eq('id', promotionId);

      await _client.from('car_listings').update({
        'is_featured': true,
        if (promotionType == 'premium') 'is_premium': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', listingId);

      return true;
    } catch (e, st) {
      LogService.error('Promosyon aktifleştirilemedi', error: e, stackTrace: st, source: 'DealerService:activatePromotion');
      return false;
    }
  }

  /// Tüm promosyonları getir (tüm statuslar, ilan başlığı join'li)
  Future<List<CarListingPromotion>> getAllPromotions() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('car_listing_promotions')
          .select('''
            *,
            car_listings:listing_id (id, title, brand_name, model_name, year)
          ''')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => CarListingPromotion.fromJson(json))
          .toList();
    } catch (e, st) {
      LogService.error('Tüm promosyonlar alınamadı', error: e, stackTrace: st, source: 'DealerService:getAllPromotions');
      return [];
    }
  }

  /// Promosyonu iptal et
  Future<bool> cancelPromotion(String promotionId, {String? reason}) async {
    try {
      final promotion = await _client
          .from('car_listing_promotions')
          .select('listing_id, promotion_type')
          .eq('id', promotionId)
          .single();

      await _client
          .from('car_listing_promotions')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': reason,
          })
          .eq('id', promotionId);

      // İlanın promosyon durumunu güncelle
      await _updateListingPromotionStatus(promotion['listing_id'] as String);

      return true;
    } catch (e, st) {
      LogService.error('Promosyon iptal edilemedi', error: e, stackTrace: st, source: 'DealerService:cancelPromotion');
      return false;
    }
  }

  Future<void> _updateListingPromotionStatus(String listingId) async {
    try {
      // Aktif featured promosyon var mı?
      final featuredPromo = await _client
          .from('car_listing_promotions')
          .select('id')
          .eq('listing_id', listingId)
          .inFilter('promotion_type', ['featured', 'premium'])
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      // Aktif premium promosyon var mı?
      final premiumPromo = await _client
          .from('car_listing_promotions')
          .select('id')
          .eq('listing_id', listingId)
          .eq('promotion_type', 'premium')
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      await _client
          .from('car_listings')
          .update({
            'is_featured': featuredPromo != null,
            'is_premium': premiumPromo != null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listingId);
    } catch (e, st) {
      LogService.error('İlan promosyon durumu güncellenemedi', error: e, stackTrace: st, source: 'DealerService:_updateListingPromotionStatus');
    }
  }

  // ==================== PERFORMANS İSTATİSTİKLERİ ====================

  /// İlan bazlı performans istatistiklerini getir
  /// [days] - Kaç günlük veri çekilecek (7, 30, 90)
  Future<Map<String, dynamic>> getListingPerformanceStats({int days = 30}) async {
    if (_userId == null) {
      return {'listings': [], 'totals': {}, 'previousTotals': {}};
    }

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final previousStartDate = startDate.subtract(Duration(days: days));

    try {
      // Kullanıcının ilanlarını al
      final listingsResponse = await _client
          .from('car_listings')
          .select('id, title, images, brand_name, model_name, year, price, city, district, status, view_count, favorite_count, contact_count')
          .eq('user_id', _userId!)
          .eq('status', 'active');

      final listings = (listingsResponse as List).cast<Map<String, dynamic>>();

      if (listings.isEmpty) {
        return {'listings': [], 'totals': {}, 'previousTotals': {}};
      }

      final listingIds = listings.map((l) => l['id'] as String).toList();

      // Bu dönem görüntülenme sayıları (car_listing_views tablosundan)
      final viewsResponse = await _client
          .from('car_listing_views')
          .select('listing_id')
          .inFilter('listing_id', listingIds)
          .gte('viewed_at', startDate.toIso8601String());

      final viewsList = (viewsResponse as List).cast<Map<String, dynamic>>();

      // İlan bazlı görüntülenme sayısı
      final Map<String, int> viewsPerListing = {};
      for (var view in viewsList) {
        final listingId = view['listing_id'] as String;
        viewsPerListing[listingId] = (viewsPerListing[listingId] ?? 0) + 1;
      }

      // Önceki dönem görüntülenme sayıları
      final prevViewsResponse = await _client
          .from('car_listing_views')
          .select('listing_id')
          .inFilter('listing_id', listingIds)
          .gte('viewed_at', previousStartDate.toIso8601String())
          .lt('viewed_at', startDate.toIso8601String());

      final prevViewsList = (prevViewsResponse as List).cast<Map<String, dynamic>>();

      final Map<String, int> prevViewsPerListing = {};
      for (var view in prevViewsList) {
        final listingId = view['listing_id'] as String;
        prevViewsPerListing[listingId] = (prevViewsPerListing[listingId] ?? 0) + 1;
      }

      // Bu dönem iletişim talepleri (car_contact_requests tablosundan)
      final contactsResponse = await _client
          .from('car_contact_requests')
          .select('listing_id')
          .inFilter('listing_id', listingIds)
          .gte('created_at', startDate.toIso8601String());

      final contactsList = (contactsResponse as List).cast<Map<String, dynamic>>();

      final Map<String, int> contactsPerListing = {};
      for (var contact in contactsList) {
        final listingId = contact['listing_id'] as String;
        contactsPerListing[listingId] = (contactsPerListing[listingId] ?? 0) + 1;
      }

      // Önceki dönem iletişim talepleri
      final prevContactsResponse = await _client
          .from('car_contact_requests')
          .select('listing_id')
          .inFilter('listing_id', listingIds)
          .gte('created_at', previousStartDate.toIso8601String())
          .lt('created_at', startDate.toIso8601String());

      final prevContactsList = (prevContactsResponse as List).cast<Map<String, dynamic>>();

      final Map<String, int> prevContactsPerListing = {};
      for (var contact in prevContactsList) {
        final listingId = contact['listing_id'] as String;
        prevContactsPerListing[listingId] = (prevContactsPerListing[listingId] ?? 0) + 1;
      }

      // Günlük görüntülenme verileri (grafik için - son 7 gün)
      final dailyViewsResponse = await _client
          .from('car_listing_views')
          .select('listing_id, viewed_at')
          .inFilter('listing_id', listingIds)
          .gte('viewed_at', now.subtract(const Duration(days: 7)).toIso8601String())
          .order('viewed_at', ascending: true);

      final dailyViewsList = (dailyViewsResponse as List).cast<Map<String, dynamic>>();

      // İlan bazlı günlük görüntülenme
      final Map<String, Map<String, int>> dailyViewsPerListing = {};
      for (var view in dailyViewsList) {
        final listingId = view['listing_id'] as String;
        final viewedAt = DateTime.parse(view['viewed_at'] as String);
        final dayKey = '${viewedAt.year}-${viewedAt.month.toString().padLeft(2, '0')}-${viewedAt.day.toString().padLeft(2, '0')}';

        dailyViewsPerListing[listingId] ??= {};
        dailyViewsPerListing[listingId]![dayKey] = (dailyViewsPerListing[listingId]![dayKey] ?? 0) + 1;
      }

      // Tüm verileri birleştir
      final List<Map<String, dynamic>> listingStats = [];
      int totalViews = 0;
      int totalFavorites = 0;
      int totalContacts = 0;
      int prevTotalViews = 0;
      int prevTotalFavorites = 0;
      int prevTotalContacts = 0;

      for (var listing in listings) {
        final listingId = listing['id'] as String;
        // car_listing_views tablosundan veya view_count kolonundan al (hangisi büyükse)
        final viewsFromTable = viewsPerListing[listingId] ?? 0;
        final viewsFromColumn = listing['view_count'] as int? ?? 0;
        final views = viewsFromTable > 0 ? viewsFromTable : viewsFromColumn;
        final prevViews = prevViewsPerListing[listingId] ?? 0;
        final favorites = listing['favorite_count'] as int? ?? 0;
        final contacts = contactsPerListing[listingId] ?? 0;
        final prevContacts = prevContactsPerListing[listingId] ?? 0;

        totalViews += views;
        totalFavorites += favorites;
        totalContacts += contacts;
        prevTotalViews += prevViews;
        prevTotalContacts += prevContacts;

        // Son 7 günlük veriyi diziye çevir
        final List<int> last7DaysViews = [];
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          last7DaysViews.add(dailyViewsPerListing[listingId]?[dayKey] ?? 0);
        }

        listingStats.add({
          'id': listingId,
          'title': listing['title'],
          'images': listing['images'],
          'brand_name': listing['brand_name'],
          'model_name': listing['model_name'],
          'year': listing['year'],
          'price': listing['price'],
          'city': listing['city'],
          'district': listing['district'],
          'status': listing['status'],
          'views': views,
          'previousViews': prevViews,
          'favorites': favorites,
          'contacts': contacts,
          'previousContacts': prevContacts,
          'dailyViews': last7DaysViews,
        });
      }

      // Views'a göre sırala (en çok görüntülenen en üstte)
      listingStats.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));

      return {
        'listings': listingStats,
        'totals': {
          'views': totalViews,
          'favorites': totalFavorites,
          'contacts': totalContacts,
        },
        'previousTotals': {
          'views': prevTotalViews,
          'favorites': prevTotalFavorites,
          'contacts': prevTotalContacts,
        },
      };
    } catch (e, st) {
      LogService.error('Performans istatistikleri alınamadı', error: e, stackTrace: st, source: 'DealerService:getListingPerformanceStats');
      return {'listings': [], 'totals': {}, 'previousTotals': {}};
    }
  }

  // ==================== DEĞERLENDİRMELER ====================

  /// Galericinin değerlendirmelerini getir
  Future<List<CarDealerReview>> getDealerReviews({int limit = 50}) async {
    if (_userId == null) return [];

    try {
      final dealer = await _client
          .from('car_dealers')
          .select('id')
          .eq('user_id', _userId!)
          .maybeSingle();

      if (dealer == null) return [];

      final response = await _client
          .from('car_dealer_reviews')
          .select()
          .eq('dealer_id', dealer['id'] as String)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => CarDealerReview.fromJson(json))
          .toList();
    } catch (e, st) {
      LogService.error('Değerlendirmeler alınamadı', error: e, stackTrace: st, source: 'DealerService:getDealerReviews');
      return [];
    }
  }

  /// Değerlendirme istatistikleri
  Future<Map<String, dynamic>> getReviewStats() async {
    if (_userId == null) {
      return {'average': 0.0, 'total': 0, 'distribution': <int, int>{}};
    }

    try {
      final dealer = await _client
          .from('car_dealers')
          .select('id, average_rating, total_reviews')
          .eq('user_id', _userId!)
          .maybeSingle();

      if (dealer == null) {
        return {'average': 0.0, 'total': 0, 'distribution': <int, int>{}};
      }

      // Rating dağılımı
      final reviews = await _client
          .from('car_dealer_reviews')
          .select('rating')
          .eq('dealer_id', dealer['id'] as String);

      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var review in (reviews as List)) {
        final r = review['rating'] as int;
        distribution[r] = (distribution[r] ?? 0) + 1;
      }

      return {
        'average': (dealer['average_rating'] as num?)?.toDouble() ?? 0.0,
        'total': dealer['total_reviews'] as int? ?? 0,
        'distribution': distribution,
      };
    } catch (e, st) {
      LogService.error('Değerlendirme istatistikleri alınamadı', error: e, stackTrace: st, source: 'DealerService:getReviewStats');
      return {'average': 0.0, 'total': 0, 'distribution': <int, int>{}};
    }
  }

  // ==================== AUTH İŞLEMLERİ ====================

  /// Şifre sıfırlama e-postası gönder
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
