import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==================== MODELS ====================

class JobCategory {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final int listingCount;
  final List<JobSubcategory> subcategories;

  JobCategory({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.listingCount = 0,
    this.subcategories = const [],
  });

  factory JobCategory.fromJson(Map<String, dynamic> json) {
    return JobCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      listingCount: json['listing_count'] as int? ?? 0,
      subcategories: json['subcategories'] != null
          ? (json['subcategories'] as List)
              .map((s) => JobSubcategory.fromJson(s))
              .toList()
          : [],
    );
  }

  String get iconName => icon ?? 'work';
  String get colorHex => color ?? '#6366F1';

  IconData get iconData {
    const iconMap = {
      'work': Icons.work,
      'computer': Icons.computer,
      'health_and_safety': Icons.health_and_safety,
      'school': Icons.school,
      'restaurant': Icons.restaurant,
      'shopping_cart': Icons.shopping_cart,
      'build': Icons.build,
      'local_shipping': Icons.local_shipping,
      'account_balance': Icons.account_balance,
      'engineering': Icons.engineering,
      'design_services': Icons.design_services,
      'campaign': Icons.campaign,
    };
    return iconMap[icon] ?? Icons.work;
  }

  Color get colorValue {
    if (color == null) return const Color(0xFF6366F1);
    try {
      return Color(int.parse(color!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}

class JobSubcategory {
  final String id;
  final String categoryId;
  final String name;
  final int sortOrder;
  final bool isActive;

  JobSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory JobSubcategory.fromJson(Map<String, dynamic> json) {
    return JobSubcategory(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class JobSkill {
  final String id;
  final String name;
  final String? category;
  final bool isPopular;
  final bool isActive;
  final int sortOrder;
  final int usageCount;
  final DateTime? createdAt;

  JobSkill({
    required this.id,
    required this.name,
    this.category,
    this.isPopular = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.usageCount = 0,
    this.createdAt,
  });

  factory JobSkill.fromJson(Map<String, dynamic> json) {
    return JobSkill(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      isPopular: json['is_popular'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      usageCount: json['usage_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

class JobBenefit {
  final String id;
  final String name;
  final String? iconName;
  final String? category;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;

  JobBenefit({
    required this.id,
    required this.name,
    this.iconName,
    this.category,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory JobBenefit.fromJson(Map<String, dynamic> json) {
    return JobBenefit(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['icon'] as String?,
      category: json['category'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  IconData get icon {
    const iconMap = {
      'card_giftcard': Icons.card_giftcard,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'health_and_safety': Icons.health_and_safety,
      'fitness_center': Icons.fitness_center,
      'school': Icons.school,
      'child_care': Icons.child_care,
      'home': Icons.home,
      'phone_android': Icons.phone_android,
      'laptop': Icons.laptop,
      'flight': Icons.flight,
      'local_cafe': Icons.local_cafe,
      'sports_esports': Icons.sports_esports,
      'spa': Icons.spa,
      'attach_money': Icons.attach_money,
      'event': Icons.event,
    };
    return iconMap[iconName] ?? Icons.card_giftcard;
  }
}

class JobListing {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? categoryId;
  final String? categoryName;
  final String jobType;
  final String workArrangement;
  final String experienceLevel;
  final String city;
  final double? salaryMin;
  final double? salaryMax;
  final String status;
  final bool isFeatured;
  final bool isPremium;
  final bool isUrgent;
  final int viewCount;
  final int applicationCount;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final String? companyName;
  final String? posterName;

  JobListing({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.categoryId,
    this.categoryName,
    required this.jobType,
    required this.workArrangement,
    required this.experienceLevel,
    required this.city,
    this.salaryMin,
    this.salaryMax,
    required this.status,
    this.isFeatured = false,
    this.isPremium = false,
    this.isUrgent = false,
    this.viewCount = 0,
    this.applicationCount = 0,
    required this.createdAt,
    this.publishedAt,
    this.companyName,
    this.posterName,
  });

  factory JobListing.fromJson(Map<String, dynamic> json) {
    return JobListing(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: json['category']?['name'] as String?,
      jobType: json['job_type'] as String? ?? 'full_time',
      workArrangement: json['work_arrangement'] as String? ?? 'onsite',
      experienceLevel: json['experience_level'] as String? ?? 'mid_level',
      city: json['city'] as String,
      salaryMin: (json['salary_min'] as num?)?.toDouble(),
      salaryMax: (json['salary_max'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      isFeatured: json['is_featured'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      isUrgent: json['is_urgent'] as bool? ?? false,
      viewCount: json['view_count'] as int? ?? 0,
      applicationCount: json['application_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      companyName: json['company']?['name'] as String?,
      posterName: json['poster']?['name'] as String?,
    );
  }

  String get jobTypeLabel {
    const labels = {
      'full_time': 'Tam Zamanlı',
      'part_time': 'Yarı Zamanlı',
      'contract': 'Sözleşmeli',
      'internship': 'Staj',
      'freelance': 'Freelance',
      'remote': 'Uzaktan',
      'temporary': 'Geçici',
    };
    return labels[jobType] ?? jobType;
  }

  String get statusLabel {
    const labels = {
      'pending': 'Onay Bekliyor',
      'active': 'Aktif',
      'closed': 'Kapatıldı',
      'filled': 'Dolduruldu',
      'expired': 'Süresi Doldu',
      'rejected': 'Reddedildi',
    };
    return labels[status] ?? status;
  }
}

class Company {
  final String id;
  final String name;
  final String? logoUrl;
  final String? industry;
  final String? city;
  final String status;
  final bool isVerified;
  final bool isPremium;
  final int activeListings;
  final DateTime createdAt;

  Company({
    required this.id,
    required this.name,
    this.logoUrl,
    this.industry,
    this.city,
    required this.status,
    this.isVerified = false,
    this.isPremium = false,
    this.activeListings = 0,
    required this.createdAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      industry: json['industry'] as String?,
      city: json['city'] as String?,
      status: json['status'] as String? ?? 'pending',
      isVerified: json['is_verified'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      activeListings: json['active_listings'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class JobPromotionPrice {
  final String id;
  final String promotionType;
  final int durationDays;
  final double price;
  final double? discountedPrice;
  final bool isActive;

  JobPromotionPrice({
    required this.id,
    required this.promotionType,
    required this.durationDays,
    required this.price,
    this.discountedPrice,
    this.isActive = true,
  });

  factory JobPromotionPrice.fromJson(Map<String, dynamic> json) {
    return JobPromotionPrice(
      id: json['id'] as String,
      promotionType: json['promotion_type'] as String,
      durationDays: json['duration_days'] as int,
      price: (json['price'] as num).toDouble(),
      discountedPrice: (json['discounted_price'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get promotionTypeLabel {
    const labels = {
      'featured': 'Öne Çıkarma',
      'premium': 'Premium',
      'urgent': 'Acil',
    };
    return labels[promotionType] ?? promotionType;
  }
}

class JobSetting {
  final String id;
  final String key;
  final String value;
  final String? description;

  JobSetting({
    required this.id,
    required this.key,
    required this.value,
    this.description,
  });

  factory JobSetting.fromJson(Map<String, dynamic> json) {
    return JobSetting(
      id: json['id'] as String,
      key: json['key'] as String,
      value: json['value'] as String,
      description: json['description'] as String?,
    );
  }
}

class JobDashboardStats {
  final int totalListings;
  final int activeListings;
  final int pendingListings;
  final int totalCompanies;
  final int activeCompanies;
  final int pendingCompanies;
  final int totalCategories;
  final int totalSkills;
  final int totalBenefits;
  final int totalApplications;

  JobDashboardStats({
    this.totalListings = 0,
    this.activeListings = 0,
    this.pendingListings = 0,
    this.totalCompanies = 0,
    this.activeCompanies = 0,
    this.pendingCompanies = 0,
    this.totalCategories = 0,
    this.totalSkills = 0,
    this.totalBenefits = 0,
    this.totalApplications = 0,
  });
}

// ==================== SERVICE ====================

class JobListingsAdminService {
  final SupabaseClient _client;

  JobListingsAdminService(this._client);

  // ==================== KATEGORİLER ====================

  Future<List<JobCategory>> getCategories() async {
    try {
      final response = await _client
          .from('job_categories')
          .select('''
            *,
            subcategories:job_subcategories(*)
          ''')
          .order('sort_order');

      return (response as List)
          .map((json) => JobCategory.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getCategories error: $e');
      return [];
    }
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    await _client.from('job_categories').insert(data);
  }

  Future<void> updateCategory(String categoryId, Map<String, dynamic> data) async {
    await _client
        .from('job_categories')
        .update(data)
        .eq('id', categoryId);
  }

  Future<void> deleteCategory(String categoryId) async {
    await _client.from('job_categories').delete().eq('id', categoryId);
  }

  // ==================== ALT KATEGORİLER ====================

  Future<List<JobSubcategory>> getSubcategories(String categoryId) async {
    try {
      final response = await _client
          .from('job_subcategories')
          .select()
          .eq('category_id', categoryId)
          .order('sort_order');

      return (response as List)
          .map((json) => JobSubcategory.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getSubcategories error: $e');
      return [];
    }
  }

  Future<void> createSubcategory(Map<String, dynamic> data) async {
    await _client.from('job_subcategories').insert(data);
  }

  Future<void> updateSubcategory(String subcategoryId, Map<String, dynamic> data) async {
    await _client
        .from('job_subcategories')
        .update(data)
        .eq('id', subcategoryId);
  }

  Future<void> deleteSubcategory(String subcategoryId) async {
    await _client.from('job_subcategories').delete().eq('id', subcategoryId);
  }

  // ==================== YETENEKLER ====================

  Future<List<JobSkill>> getSkills() async {
    try {
      final response = await _client
          .from('job_skills')
          .select()
          .order('usage_count', ascending: false);

      return (response as List)
          .map((json) => JobSkill.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getSkills error: $e');
      return [];
    }
  }

  Future<void> createSkill(Map<String, dynamic> data) async {
    await _client.from('job_skills').insert(data);
  }

  Future<void> updateSkill(String skillId, Map<String, dynamic> data) async {
    await _client
        .from('job_skills')
        .update(data)
        .eq('id', skillId);
  }

  Future<void> deleteSkill(String skillId) async {
    await _client.from('job_skills').delete().eq('id', skillId);
  }

  // ==================== YAN HAKLAR ====================

  Future<List<JobBenefit>> getBenefits() async {
    try {
      final response = await _client
          .from('job_benefits')
          .select()
          .order('sort_order');

      return (response as List)
          .map((json) => JobBenefit.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getBenefits error: $e');
      return [];
    }
  }

  Future<void> createBenefit(Map<String, dynamic> data) async {
    await _client.from('job_benefits').insert(data);
  }

  Future<void> updateBenefit(String benefitId, Map<String, dynamic> data) async {
    await _client
        .from('job_benefits')
        .update(data)
        .eq('id', benefitId);
  }

  Future<void> deleteBenefit(String benefitId) async {
    await _client.from('job_benefits').delete().eq('id', benefitId);
  }

  // ==================== İLANLAR ====================

  Future<List<JobListing>> getListings({String? status}) async {
    try {
      var query = _client
          .from('job_listings')
          .select('''
            *,
            category:category_id(name),
            company:company_id(name),
            poster:poster_id(name)
          ''');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => JobListing.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getListings error: $e');
      return [];
    }
  }

  Future<void> updateListingStatus(String listingId, String status) async {
    final updates = <String, dynamic>{'status': status};

    if (status == 'active') {
      updates['published_at'] = DateTime.now().toIso8601String();
    }

    await _client
        .from('job_listings')
        .update(updates)
        .eq('id', listingId);
  }

  Future<void> toggleListingFeatured(String listingId, bool isFeatured) async {
    await _client
        .from('job_listings')
        .update({'is_featured': isFeatured})
        .eq('id', listingId);
  }

  Future<void> toggleListingPremium(String listingId, bool isPremium) async {
    await _client
        .from('job_listings')
        .update({'is_premium': isPremium})
        .eq('id', listingId);
  }

  Future<void> toggleListingUrgent(String listingId, bool isUrgent) async {
    await _client
        .from('job_listings')
        .update({'is_urgent': isUrgent})
        .eq('id', listingId);
  }

  Future<void> updateListing(String listingId, Map<String, dynamic> data) async {
    if (data['status'] == 'active' && !data.containsKey('published_at')) {
      data['published_at'] = DateTime.now().toIso8601String();
    }
    await _client
        .from('job_listings')
        .update(data)
        .eq('id', listingId);
  }

  Future<void> deleteListing(String listingId) async {
    await _client.from('job_listings').delete().eq('id', listingId);
  }

  // ==================== ŞİRKETLER ====================

  Future<List<Company>> getCompanies({String? status}) async {
    try {
      var query = _client.from('companies').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => Company.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getCompanies error: $e');
      return [];
    }
  }

  Future<void> updateCompanyStatus(String companyId, String status) async {
    await _client
        .from('companies')
        .update({'status': status})
        .eq('id', companyId);
  }

  Future<void> toggleCompanyVerified(String companyId, bool isVerified) async {
    await _client
        .from('companies')
        .update({'is_verified': isVerified})
        .eq('id', companyId);
  }

  Future<void> toggleCompanyPremium(String companyId, bool isPremium) async {
    await _client
        .from('companies')
        .update({'is_premium': isPremium})
        .eq('id', companyId);
  }

  // ==================== PROMOSYON FİYATLARI ====================

  Future<List<JobPromotionPrice>> getPromotionPrices() async {
    try {
      final response = await _client
          .from('job_promotion_prices')
          .select()
          .order('promotion_type')
          .order('duration_days');

      return (response as List)
          .map((json) => JobPromotionPrice.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getPromotionPrices error: $e');
      return [];
    }
  }

  Future<void> updatePromotionPrice(String priceId, Map<String, dynamic> data) async {
    await _client
        .from('job_promotion_prices')
        .update(data)
        .eq('id', priceId);
  }

  // ==================== AYARLAR ====================

  Future<List<JobSetting>> getSettings() async {
    try {
      final response = await _client
          .from('job_settings')
          .select()
          .order('key');

      return (response as List)
          .map((json) => JobSetting.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getSettings error: $e');
      return [];
    }
  }

  Future<void> updateSetting(String settingId, String value) async {
    await _client
        .from('job_settings')
        .update({'value': value})
        .eq('id', settingId);
  }

  // ==================== İSTATİSTİKLER ====================

  Future<JobDashboardStats> getDashboardStats() async {
    try {
      // Toplam ve aktif ilanlar
      final allListings = await _client
          .from('job_listings')
          .select('id, status');

      final activeListings = (allListings as List)
          .where((l) => l['status'] == 'active')
          .length;
      final pendingListings = (allListings)
          .where((l) => l['status'] == 'pending')
          .length;

      // Şirketler
      final allCompanies = await _client
          .from('companies')
          .select('id, status');

      final activeCompanies = (allCompanies as List)
          .where((c) => c['status'] == 'active')
          .length;
      final pendingCompanies = (allCompanies)
          .where((c) => c['status'] == 'pending')
          .length;

      // Kategoriler
      final categories = await _client
          .from('job_categories')
          .select('id');

      // Yetenekler
      final skills = await _client
          .from('job_skills')
          .select('id');

      // Yan haklar
      final benefits = await _client
          .from('job_benefits')
          .select('id');

      // Başvurular
      final applications = await _client
          .from('job_applications')
          .select('id');

      return JobDashboardStats(
        totalListings: (allListings).length,
        activeListings: activeListings,
        pendingListings: pendingListings,
        totalCompanies: (allCompanies).length,
        activeCompanies: activeCompanies,
        pendingCompanies: pendingCompanies,
        totalCategories: (categories as List).length,
        totalSkills: (skills as List).length,
        totalBenefits: (benefits as List).length,
        totalApplications: (applications as List).length,
      );
    } catch (e) {
      debugPrint('getDashboardStats error: $e');
      return JobDashboardStats();
    }
  }
}

// ==================== PROVIDERS ====================

final jobListingsAdminServiceProvider = Provider<JobListingsAdminService>((ref) {
  return JobListingsAdminService(Supabase.instance.client);
});

// Kategoriler
final jobCategoriesProvider = FutureProvider<List<JobCategory>>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getCategories();
});

// Yetenekler
final jobSkillsProvider = FutureProvider<List<JobSkill>>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getSkills();
});

// Yan haklar
final jobBenefitsProvider = FutureProvider<List<JobBenefit>>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getBenefits();
});

// Tüm ilanlar
final jobListingsProvider = FutureProvider<List<JobListing>>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getListings();
});

// İlanlar (status'a göre filtrelenmiş)
final jobListingsByStatusProvider = FutureProvider.family<List<JobListing>, String?>((ref, status) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getListings(status: status);
});

// Bekleyen ilanlar (sidebar badge için)
final pendingJobListingsProvider = FutureProvider<List<JobListing>>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getListings(status: 'pending');
});

// Şirketler
final companiesProvider = FutureProvider.family<List<Company>, String?>((ref, status) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getCompanies(status: status);
});

// Bekleyen şirketler
final pendingCompaniesProvider = FutureProvider<List<Company>>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getCompanies(status: 'pending');
});

// Promosyon fiyatları
final jobPromotionPricesProvider = FutureProvider<List<JobPromotionPrice>>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getPromotionPrices();
});

// Ayarlar
final jobSettingsProvider = FutureProvider<List<JobSetting>>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getSettings();
});

// Dashboard istatistikleri
final jobDashboardStatsProvider = FutureProvider<JobDashboardStats>((ref) async {
  final service = ref.watch(jobListingsAdminServiceProvider);
  return service.getDashboardStats();
});
