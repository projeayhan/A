import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/jobs/job_data_models.dart';
import '../../services/jobs_service.dart';

// ============================================
// JOBS SERVICE PROVIDER
// ============================================

final jobsServiceProvider = Provider<JobsService>((ref) {
  return JobsService.instance;
});

// ============================================
// KATEGORİLER PROVIDER
// ============================================

final jobCategoriesProvider = FutureProvider<List<JobCategoryData>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getCategories();
});

// ============================================
// YETENEKLER PROVIDER
// ============================================

final jobSkillsProvider = FutureProvider<List<JobSkillData>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getSkills(popularOnly: true);
});

// ============================================
// YAN HAKLAR PROVIDER
// ============================================

final jobBenefitsProvider = FutureProvider<List<JobBenefitData>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getBenefits();
});

// ============================================
// DASHBOARD İSTATİSTİKLERİ PROVIDER
// ============================================

final jobsDashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getDashboardStats();
});

// ============================================
// İLAN FİLTRE STATE
// ============================================

class JobListFilter {
  final String? categoryId;
  final String? jobType;
  final String? workArrangement;
  final String? experienceLevel;
  final String? city;
  final double? minSalary;
  final double? maxSalary;
  final String? searchQuery;
  final bool featuredOnly;
  final bool urgentOnly;
  final bool premiumOnly;
  final String sortBy;

  const JobListFilter({
    this.categoryId,
    this.jobType,
    this.workArrangement,
    this.experienceLevel,
    this.city,
    this.minSalary,
    this.maxSalary,
    this.searchQuery,
    this.featuredOnly = false,
    this.urgentOnly = false,
    this.premiumOnly = false,
    this.sortBy = 'newest',
  });

  JobListFilter copyWith({
    String? categoryId,
    String? jobType,
    String? workArrangement,
    String? experienceLevel,
    String? city,
    double? minSalary,
    double? maxSalary,
    String? searchQuery,
    bool? featuredOnly,
    bool? urgentOnly,
    bool? premiumOnly,
    String? sortBy,
  }) {
    return JobListFilter(
      categoryId: categoryId ?? this.categoryId,
      jobType: jobType ?? this.jobType,
      workArrangement: workArrangement ?? this.workArrangement,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      city: city ?? this.city,
      minSalary: minSalary ?? this.minSalary,
      maxSalary: maxSalary ?? this.maxSalary,
      searchQuery: searchQuery ?? this.searchQuery,
      featuredOnly: featuredOnly ?? this.featuredOnly,
      urgentOnly: urgentOnly ?? this.urgentOnly,
      premiumOnly: premiumOnly ?? this.premiumOnly,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (categoryId != null) count++;
    if (jobType != null) count++;
    if (workArrangement != null) count++;
    if (experienceLevel != null) count++;
    if (city != null) count++;
    if (minSalary != null || maxSalary != null) count++;
    if (urgentOnly) count++;
    return count;
  }

  JobListFilter clear() {
    return const JobListFilter();
  }
}

// ============================================
// İLAN LİSTESİ STATE
// ============================================

class JobListState {
  final List<JobListingData> listings;
  final bool isLoading;
  final String? error;
  final JobListFilter filter;
  final bool hasMore;
  final int currentPage;

  const JobListState({
    this.listings = const [],
    this.isLoading = false,
    this.error,
    this.filter = const JobListFilter(),
    this.hasMore = true,
    this.currentPage = 0,
  });

  JobListState copyWith({
    List<JobListingData>? listings,
    bool? isLoading,
    String? error,
    JobListFilter? filter,
    bool? hasMore,
    int? currentPage,
  }) {
    return JobListState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filter: filter ?? this.filter,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// ============================================
// İLAN LİSTESİ NOTIFIER
// ============================================

class JobListNotifier extends StateNotifier<JobListState> {
  final JobsService _service;
  static const int _pageSize = 20;

  JobListNotifier(this._service) : super(const JobListState()) {
    loadListings();
  }

  Future<void> loadListings({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: refresh ? 0 : state.currentPage,
      listings: refresh ? [] : state.listings,
    );

    try {
      final filter = state.filter;
      final listings = await _service.getActiveListings(
        categoryId: filter.categoryId,
        jobType: filter.jobType,
        workArrangement: filter.workArrangement,
        experienceLevel: filter.experienceLevel,
        city: filter.city,
        minSalary: filter.minSalary,
        maxSalary: filter.maxSalary,
        searchQuery: filter.searchQuery,
        featuredOnly: filter.featuredOnly,
        urgentOnly: filter.urgentOnly,
        premiumOnly: filter.premiumOnly,
        sortBy: filter.sortBy,
        limit: _pageSize,
        offset: refresh ? 0 : state.currentPage * _pageSize,
      );

      debugPrint('JobListNotifier.loadListings: Loaded ${listings.length} listings');
      state = state.copyWith(
        listings: refresh ? listings : [...state.listings, ...listings],
        isLoading: false,
        hasMore: listings.length >= _pageSize,
        currentPage: refresh ? 1 : state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadListings(refresh: true);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadListings();
  }

  void setFilter(JobListFilter filter) {
    state = state.copyWith(filter: filter);
    loadListings(refresh: true);
  }

  void updateFilter({
    String? categoryId,
    String? jobType,
    String? workArrangement,
    String? experienceLevel,
    String? city,
    double? minSalary,
    double? maxSalary,
    String? searchQuery,
    bool? featuredOnly,
    bool? urgentOnly,
    bool? premiumOnly,
    String? sortBy,
  }) {
    final newFilter = state.filter.copyWith(
      categoryId: categoryId,
      jobType: jobType,
      workArrangement: workArrangement,
      experienceLevel: experienceLevel,
      city: city,
      minSalary: minSalary,
      maxSalary: maxSalary,
      searchQuery: searchQuery,
      featuredOnly: featuredOnly,
      urgentOnly: urgentOnly,
      premiumOnly: premiumOnly,
      sortBy: sortBy,
    );
    setFilter(newFilter);
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(filter: state.filter.copyWith(sortBy: sortBy));
    loadListings(refresh: true);
  }

  void clearFilters() {
    state = state.copyWith(filter: const JobListFilter());
    loadListings(refresh: true);
  }

  void search(String query) {
    state = state.copyWith(
      filter: state.filter.copyWith(searchQuery: query.isEmpty ? null : query),
    );
    loadListings(refresh: true);
  }
}

final jobListProvider =
    StateNotifierProvider<JobListNotifier, JobListState>((ref) {
  final service = ref.watch(jobsServiceProvider);
  return JobListNotifier(service);
});

// ============================================
// ÖNE ÇIKAN İLANLAR PROVIDER
// ============================================

final featuredJobsProvider = FutureProvider<List<JobListingData>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getFeaturedListings(limit: 10);
});

// ============================================
// ACİL İLANLAR PROVIDER
// ============================================

final urgentJobsProvider = FutureProvider<List<JobListingData>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getUrgentListings(limit: 10);
});

// ============================================
// PREMİUM İLANLAR PROVIDER
// ============================================

final premiumJobsProvider = FutureProvider<List<JobListingData>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getPremiumListings(limit: 10);
});

// ============================================
// KATEGORİYE GÖRE İLANLAR PROVIDER
// ============================================

final jobsByCategoryProvider = FutureProvider.family<List<JobListingData>, String>((ref, categoryId) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getListingsByCategory(categoryId, limit: 20);
});

// ============================================
// İLAN DETAY PROVIDER
// ============================================

final jobDetailProvider = FutureProvider.family<JobListingData?, String>((ref, listingId) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getListing(listingId);
});

// ============================================
// İLAN YETENEKLERİ PROVIDER
// ============================================

final jobListingSkillsProvider = FutureProvider.family<List<JobSkillData>, String>((ref, listingId) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getListingSkills(listingId);
});

// ============================================
// İLAN YAN HAKLARI PROVIDER
// ============================================

final jobListingBenefitsProvider = FutureProvider.family<List<JobBenefitData>, String>((ref, listingId) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getListingBenefits(listingId);
});

// ============================================
// KULLANICININ İLANLARI PROVIDER
// ============================================

class UserJobListingsState {
  final List<JobListingData> listings;
  final bool isLoading;
  final String? error;

  const UserJobListingsState({
    this.listings = const [],
    this.isLoading = false,
    this.error,
  });

  UserJobListingsState copyWith({
    List<JobListingData>? listings,
    bool? isLoading,
    String? error,
  }) {
    return UserJobListingsState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserJobListingsNotifier extends StateNotifier<UserJobListingsState> {
  final JobsService _service;

  UserJobListingsNotifier(this._service) : super(const UserJobListingsState()) {
    loadListings();
  }

  Future<void> loadListings({String? status}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final listings = await _service.getUserListings(status: status);
      state = state.copyWith(
        listings: listings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(listings: []);
    await loadListings();
  }

  Future<bool> deleteListing(String listingId) async {
    final success = await _service.deleteListing(listingId);
    if (success) {
      state = state.copyWith(
        listings: state.listings.where((l) => l.id != listingId).toList(),
      );
    }
    return success;
  }
}

final userJobListingsProvider =
    StateNotifierProvider<UserJobListingsNotifier, UserJobListingsState>((ref) {
  final service = ref.watch(jobsServiceProvider);
  return UserJobListingsNotifier(service);
});

// ============================================
// BAŞVURULAR PROVIDER
// ============================================

final userApplicationsProvider = FutureProvider<List<JobApplicationData>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getUserApplications();
});

final listingApplicationsProvider = FutureProvider.family<List<JobApplicationData>, String>((ref, listingId) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getListingApplications(listingId);
});

// ============================================
// FAVORİLER PROVIDER
// ============================================

class JobFavoritesState {
  final Set<String> favoriteIds;
  final List<JobListingData> favorites;
  final bool isLoading;

  const JobFavoritesState({
    this.favoriteIds = const {},
    this.favorites = const [],
    this.isLoading = false,
  });

  JobFavoritesState copyWith({
    Set<String>? favoriteIds,
    List<JobListingData>? favorites,
    bool? isLoading,
  }) {
    return JobFavoritesState(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class JobFavoritesNotifier extends StateNotifier<JobFavoritesState> {
  final JobsService _service;

  JobFavoritesNotifier(this._service) : super(const JobFavoritesState()) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true);

    try {
      final favorites = await _service.getFavoriteListings();
      state = state.copyWith(
        favorites: favorites,
        favoriteIds: favorites.map((f) => f.id).toSet(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  bool isFavorite(String listingId) {
    return state.favoriteIds.contains(listingId);
  }

  Future<void> toggleFavorite(String listingId) async {
    final isFav = isFavorite(listingId);

    // Optimistic update
    if (isFav) {
      state = state.copyWith(
        favoriteIds: {...state.favoriteIds}..remove(listingId),
        favorites: state.favorites.where((f) => f.id != listingId).toList(),
      );
      await _service.removeFromFavorites(listingId);
    } else {
      state = state.copyWith(
        favoriteIds: {...state.favoriteIds, listingId},
      );
      await _service.addToFavorites(listingId);
    }
  }
}

final jobFavoritesProvider =
    StateNotifierProvider<JobFavoritesNotifier, JobFavoritesState>((ref) {
  final service = ref.watch(jobsServiceProvider);
  return JobFavoritesNotifier(service);
});

// ============================================
// BAŞVURU DURUMU PROVIDER
// ============================================

final hasAppliedProvider = FutureProvider.family<bool, String>((ref, listingId) async {
  final service = ref.watch(jobsServiceProvider);
  return service.hasApplied(listingId);
});

// ============================================
// PROMOSYON FİYATLARI PROVIDER
// ============================================

final jobPromotionPricesProvider = FutureProvider<List<JobPromotionPrice>>((ref) async {
  final service = ref.watch(jobsServiceProvider);
  return service.getPromotionPrices();
});

// ============================================
// İLAN OLUŞTURMA PROVIDER
// ============================================

class CreateJobListingState {
  final bool isLoading;
  final String? error;
  final JobListingData? createdListing;

  const CreateJobListingState({
    this.isLoading = false,
    this.error,
    this.createdListing,
  });

  CreateJobListingState copyWith({
    bool? isLoading,
    String? error,
    JobListingData? createdListing,
  }) {
    return CreateJobListingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      createdListing: createdListing,
    );
  }
}

class CreateJobListingNotifier extends StateNotifier<CreateJobListingState> {
  final JobsService _service;

  CreateJobListingNotifier(this._service) : super(const CreateJobListingState());

  Future<JobListingData?> createListing({
    required String title,
    required String description,
    String? categoryId,
    String? subcategory,
    required String jobType,
    required String workArrangement,
    required String experienceLevel,
    required String educationLevel,
    double? salaryMin,
    double? salaryMax,
    String salaryCurrency = 'TRY',
    String salaryPeriod = 'monthly',
    bool isSalaryHidden = false,
    bool isSalaryNegotiable = false,
    required String city,
    String? district,
    String? address,
    int positions = 1,
    List<String>? responsibilities,
    List<String>? qualifications,
    DateTime? deadline,
    List<String>? skillIds,
    List<String>? requiredSkillIds,
    List<String>? benefitIds,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final listing = await _service.createListing({
        'title': title,
        'description': description,
        'category_id': categoryId,
        'subcategory': subcategory,
        'job_type': jobType,
        'work_arrangement': workArrangement,
        'experience_level': experienceLevel,
        'education_level': educationLevel,
        'salary_min': salaryMin,
        'salary_max': salaryMax,
        'salary_currency': salaryCurrency,
        'salary_period': salaryPeriod,
        'is_salary_hidden': isSalaryHidden,
        'is_salary_negotiable': isSalaryNegotiable,
        'city': city,
        'district': district,
        'address': address,
        'positions': positions,
        'responsibilities': responsibilities,
        'qualifications': qualifications,
        'deadline': deadline?.toIso8601String(),
      });

      if (listing != null) {
        // Yetenekleri kaydet
        if (skillIds != null && skillIds.isNotEmpty) {
          await _service.saveListingSkills(
            listing.id,
            skillIds,
            requiredSkillIds: requiredSkillIds,
          );
        }

        // Yan hakları kaydet
        if (benefitIds != null && benefitIds.isNotEmpty) {
          await _service.saveListingBenefits(listing.id, benefitIds);
        }
      }

      state = state.copyWith(
        isLoading: false,
        createdListing: listing,
      );

      return listing;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const CreateJobListingState();
  }
}

final createJobListingProvider =
    StateNotifierProvider<CreateJobListingNotifier, CreateJobListingState>((ref) {
  final service = ref.watch(jobsServiceProvider);
  return CreateJobListingNotifier(service);
});

// ============================================
// BAŞVURU YAPMA PROVIDER
// ============================================

class ApplyToJobState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const ApplyToJobState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  ApplyToJobState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return ApplyToJobState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class ApplyToJobNotifier extends StateNotifier<ApplyToJobState> {
  final JobsService _service;

  ApplyToJobNotifier(this._service) : super(const ApplyToJobState());

  Future<bool> apply({
    required String listingId,
    required String name,
    required String email,
    String? phone,
    String? coverLetter,
    String? resumeUrl,
    List<String>? portfolioLinks,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final application = await _service.applyToListing(
        listingId: listingId,
        name: name,
        email: email,
        phone: phone,
        coverLetter: coverLetter,
        resumeUrl: resumeUrl,
        portfolioLinks: portfolioLinks,
      );

      if (application != null) {
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Başvuru yapılamadı. Daha önce başvurmuş olabilirsiniz.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const ApplyToJobState();
  }
}

final applyToJobProvider =
    StateNotifierProvider<ApplyToJobNotifier, ApplyToJobState>((ref) {
  final service = ref.watch(jobsServiceProvider);
  return ApplyToJobNotifier(service);
});
