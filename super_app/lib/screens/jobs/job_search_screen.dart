import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/jobs/job_models.dart';
import '../../models/jobs/job_model_extensions.dart';
import '../../core/providers/jobs_provider.dart';
import 'job_detail_screen.dart';

class JobSearchScreen extends ConsumerStatefulWidget {
  const JobSearchScreen({super.key});

  @override
  ConsumerState<JobSearchScreen> createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends ConsumerState<JobSearchScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  String _searchQuery = '';
  final List<String> _recentSearches = [
    'Flutter Developer',
    'UI/UX Designer',
    'Remote',
    'Senior',
  ];
  bool _isSearching = false;
  bool _showFilters = false;

  // Filters
  final Set<String> _selectedCategories = {};
  final Set<JobType> _selectedJobTypes = {};
  final Set<WorkArrangement> _selectedWorkArrangements = {};
  final Set<ExperienceLevel> _selectedExperienceLevels = {};
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    if (query.isNotEmpty) {
      // Provider üzerinden arama yap
      ref.read(jobListProvider.notifier).search(query);
    } else {
      // Aramayı temizle
      ref.read(jobListProvider.notifier).clearFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCategories.clear();
      _selectedJobTypes.clear();
      _selectedWorkArrangements.clear();
      _selectedExperienceLevels.clear();
      _selectedCity = null;
    });
    _performSearch(_searchQuery);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategories.isNotEmpty) count++;
    if (_selectedJobTypes.isNotEmpty) count++;
    if (_selectedWorkArrangements.isNotEmpty) count++;
    if (_selectedExperienceLevels.isNotEmpty) count++;
    if (_selectedCity != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: JobsColors.background(isDark),
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchHeader(isDark),
              if (_showFilters) _buildFiltersSection(isDark),
              Expanded(
                child: _isSearching
                    ? _buildSearchResults(isDark)
                    : _buildRecentAndSuggestions(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: JobsColors.surface(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: JobsColors.textPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: JobsColors.surface(isDark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _searchFocusNode.hasFocus
                          ? JobsColors.primary
                          : JobsColors.border(isDark),
                      width: _searchFocusNode.hasFocus ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        Icons.search,
                        color: _searchFocusNode.hasFocus
                            ? JobsColors.primary
                            : JobsColors.textTertiary(isDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _performSearch,
                          style: TextStyle(
                            color: JobsColors.textPrimary(isDark),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Pozisyon, şirket veya anahtar kelime...',
                            hintStyle: TextStyle(
                              color: JobsColors.textTertiary(isDark),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.close,
                              color: JobsColors.textTertiary(isDark),
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() => _showFilters = !_showFilters);
                  HapticFeedback.selectionClick();
                },
                child: Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _showFilters
                            ? JobsColors.primary
                            : JobsColors.surface(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune,
                        color: _showFilters
                            ? Colors.white
                            : JobsColors.textPrimary(isDark),
                      ),
                    ),
                    if (_activeFilterCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: JobsColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$_activeFilterCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtreler',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_activeFilterCount > 0)
                GestureDetector(
                  onTap: _clearFilters,
                  child: Text(
                    'Temizle',
                    style: TextStyle(
                      color: JobsColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Job Type Filter
          Text(
            'Çalışma Şekli',
            style: TextStyle(
              color: JobsColors.textSecondary(isDark),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: JobType.values.take(5).map((type) {
              final isSelected = _selectedJobTypes.contains(type);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedJobTypes.remove(type);
                    } else {
                      _selectedJobTypes.add(type);
                    }
                  });
                  _performSearch(_searchQuery);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? type.color : JobsColors.card(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? type.color
                          : JobsColors.border(isDark),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type.icon,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : JobsColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        type.label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : JobsColors.textPrimary(isDark),
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Work Arrangement Filter
          Text(
            'Çalışma Modeli',
            style: TextStyle(
              color: JobsColors.textSecondary(isDark),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: WorkArrangement.values.map((arrangement) {
              final isSelected = _selectedWorkArrangements.contains(
                arrangement,
              );
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedWorkArrangements.remove(arrangement);
                      } else {
                        _selectedWorkArrangements.add(arrangement);
                      }
                    });
                    _performSearch(_searchQuery);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      right: arrangement != WorkArrangement.values.last ? 8 : 0,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? arrangement.color
                          : JobsColors.card(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? arrangement.color
                            : JobsColors.border(isDark),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          arrangement.icon,
                          color: isSelected ? Colors.white : arrangement.color,
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          arrangement.label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : JobsColors.textPrimary(isDark),
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAndSuggestions(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Son Aramalar',
                  style: TextStyle(
                    color: JobsColors.textPrimary(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _recentSearches.clear());
                  },
                  child: Text(
                    'Temizle',
                    style: TextStyle(
                      color: JobsColors.textTertiary(isDark),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _recentSearches.map((search) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = search;
                    _performSearch(search);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: JobsColors.card(isDark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: JobsColors.border(isDark)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 16,
                          color: JobsColors.textTertiary(isDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          search,
                          style: TextStyle(
                            color: JobsColors.textPrimary(isDark),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Popular Categories
          Text(
            'Popüler Kategoriler',
            style: TextStyle(
              color: JobsColors.textPrimary(isDark),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildPopularCategories(isDark),

          const SizedBox(height: 32),

          // Trending Skills
          Text(
            'Trend Yetenekler',
            style: TextStyle(
              color: JobsColors.textPrimary(isDark),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: JobSkill.popularSkills.take(12).map((skill) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = skill.name;
                  _performSearch(skill.name);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        JobsColors.secondary.withValues(alpha: 0.1),
                        JobsColors.secondary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: JobsColors.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 14,
                        color: JobsColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        skill.name,
                        style: TextStyle(
                          color: JobsColors.secondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    final jobListState = ref.watch(jobListProvider);
    final searchResults = jobListState.listings.toUIModels();

    if (jobListState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: JobsColors.surface(isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 40,
                color: JobsColors.textTertiary(isDark),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sonuç Bulunamadı',
              style: TextStyle(
                color: JobsColors.textPrimary(isDark),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"$_searchQuery" için sonuç bulunamadı.\nFarklı anahtar kelimeler deneyin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: JobsColors.textSecondary(isDark),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '${searchResults.length} sonuç bulundu',
            style: TextStyle(
              color: JobsColors.textSecondary(isDark),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final job = searchResults[index];
              return _buildSearchResultCard(job, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularCategories(bool isDark) {
    final categoriesAsync = ref.watch(jobCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        return Column(
          children: categories.take(6).map((category) {
            final categoryColor = _getCategoryColor(category.icon);
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategories.add(category.id);
                });
                _searchController.text = category.name;
                ref.read(jobListProvider.notifier).updateFilter(categoryId: category.id);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: JobsColors.card(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: JobsColors.border(isDark)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getCategoryIcon(category.icon), color: categoryColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          color: JobsColors.textPrimary(isDark),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: JobsColors.textTertiary(isDark),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'computer': return Icons.computer;
      case 'medical_services': return Icons.medical_services;
      case 'school': return Icons.school;
      case 'restaurant': return Icons.restaurant;
      case 'business': return Icons.business;
      case 'build': return Icons.build;
      case 'local_shipping': return Icons.local_shipping;
      case 'storefront': return Icons.storefront;
      case 'account_balance': return Icons.account_balance;
      case 'home_repair_service': return Icons.home_repair_service;
      case 'security': return Icons.security;
      case 'cleaning_services': return Icons.cleaning_services;
      default: return Icons.work;
    }
  }

  Color _getCategoryColor(String? iconName) {
    switch (iconName) {
      case 'computer': return const Color(0xFF3B82F6);
      case 'medical_services': return const Color(0xFFEF4444);
      case 'school': return const Color(0xFF8B5CF6);
      case 'restaurant': return const Color(0xFFF59E0B);
      case 'business': return const Color(0xFF6366F1);
      case 'build': return const Color(0xFF64748B);
      case 'local_shipping': return const Color(0xFF0EA5E9);
      case 'storefront': return const Color(0xFF10B981);
      case 'account_balance': return const Color(0xFF1E1B4B);
      case 'home_repair_service': return const Color(0xFF78716C);
      case 'security': return const Color(0xFF0F172A);
      case 'cleaning_services': return const Color(0xFF06B6D4);
      default: return JobsColors.primary;
    }
  }

  Widget _buildSearchResultCard(JobListing job, bool isDark) {
    return GestureDetector(
      onTap: () {
        // Add to recent searches
        if (!_recentSearches.contains(_searchQuery)) {
          setState(() {
            _recentSearches.insert(0, _searchQuery);
            if (_recentSearches.length > 5) {
              _recentSearches.removeLast();
            }
          });
        }
        _navigateToDetail(job);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(16),
          border: job.isPremiumListing
              ? Border.all(
                  color: JobsColors.secondary.withValues(alpha: 0.3),
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Logo
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: JobsColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JobsColors.border(isDark)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: job.companyLogo != null
                    ? CachedNetworkImage(
                        imageUrl: job.companyLogo!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            job.companyName.substring(0, 1),
                            style: TextStyle(
                              color: job.category.color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          job.companyName.substring(0, 1),
                          style: TextStyle(
                            color: job.category.color,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Job Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company & Badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job.companyName,
                          style: TextStyle(
                            color: JobsColors.textSecondary(isDark),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (job.isUrgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: JobsColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                size: 12,
                                color: JobsColors.accent,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Acil',
                                style: TextStyle(
                                  color: JobsColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    job.title,
                    style: TextStyle(
                      color: JobsColors.textPrimary(isDark),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Tags
                  Row(
                    children: [
                      _buildSmallTag(
                        isDark,
                        job.jobType.label,
                        job.jobType.color,
                      ),
                      const SizedBox(width: 6),
                      _buildSmallTag(
                        isDark,
                        job.location,
                        JobsColors.textSecondary(isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Bottom Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        job.timeAgo,
                        style: TextStyle(
                          color: JobsColors.textTertiary(isDark),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        job.salary.formatted,
                        style: TextStyle(
                          color: JobsColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallTag(bool isDark, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _navigateToDetail(JobListing job) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => JobDetailScreen(job: job),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
