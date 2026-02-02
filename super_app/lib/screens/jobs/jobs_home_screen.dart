import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../core/theme/app_responsive.dart';
import '../../models/jobs/job_models.dart';
import '../../models/jobs/job_data_models.dart';
import '../../models/jobs/job_model_extensions.dart';
import '../../core/providers/jobs_provider.dart';
import '../../core/providers/banner_provider.dart';
import '../../widgets/common/generic_banner_carousel.dart';
import 'job_detail_screen.dart';
import 'add_job_listing_screen.dart';
import 'my_job_listings_screen.dart';
import 'job_search_screen.dart';

class JobsHomeScreen extends ConsumerStatefulWidget {
  const JobsHomeScreen({super.key});

  @override
  ConsumerState<JobsHomeScreen> createState() => _JobsHomeScreenState();
}

class _JobsHomeScreenState extends ConsumerState<JobsHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _headerAnimation;
  late Animation<double> _pulseAnimation;

  final ScrollController _scrollController = ScrollController();
  String? _selectedCategoryId; // null = Tümü
  int _currentShowcaseIndex = 0;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutBack,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _headerController.forward();

    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });

    // Auto-scroll showcase
    Future.delayed(const Duration(seconds: 5), _autoScrollShowcase);
  }

  void _autoScrollShowcase() {
    if (!mounted) return;
    final featuredJobs = ref.read(featuredJobsProvider).valueOrNull ?? [];
    if (featuredJobs.isEmpty) {
      Future.delayed(const Duration(seconds: 5), _autoScrollShowcase);
      return;
    }
    setState(() {
      _currentShowcaseIndex = (_currentShowcaseIndex + 1) % featuredJobs.length;
    });
    Future.delayed(const Duration(seconds: 5), _autoScrollShowcase);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: JobsColors.background(isDark),
        body: Stack(
          children: [
            // Background gradient animation
            _buildAnimatedBackground(isDark, size),

            // Main content
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Animated App Bar
                _buildSliverAppBar(isDark, size),

                // Stats Banner
                SliverToBoxAdapter(
                  child: _buildStatsBanner(isDark),
                ),

                // Banner Carousel
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: GenericBannerCarousel(
                      bannerProvider: jobsBannersProvider,
                      height: 160,
                      primaryColor: Colors.indigo,
                      defaultTitle: 'Kariyer Fırsatları',
                      defaultSubtitle: 'Hayalinizdeki işe ulaşın!',
                    ),
                  ),
                ),

                // Featured Jobs Showcase
                SliverToBoxAdapter(
                  child: _buildFeaturedShowcase(isDark, size),
                ),

                // Quick Actions
                SliverToBoxAdapter(
                  child: _buildQuickActions(isDark),
                ),

                // Categories
                SliverToBoxAdapter(
                  child: _buildCategories(isDark),
                ),

                // Urgent Jobs
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    isDark,
                    'Acil Pozisyonlar',
                    'Tümünü Gör',
                    () {},
                    icon: Icons.bolt,
                    iconColor: JobsColors.accent,
                  ),
                ),

                SliverToBoxAdapter(
                  child: _buildUrgentJobs(isDark),
                ),

                // Recent Jobs
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    isDark,
                    'Son Eklenen İlanlar',
                    'Tümünü Gör',
                    () {},
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: _buildRecentJobs(isDark),
                ),

                // Bottom spacing
                SliverToBoxAdapter(
                  child: SizedBox(height: context.bottomNavPadding),
                ),
              ],
            ),

            // Floating Add Button
            _buildFloatingAddButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(bool isDark, Size size) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return CustomPaint(
            painter: _BackgroundPainter(
              isDark: isDark,
              animationValue: _shimmerController.value,
              scrollOffset: _scrollOffset,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, Size size) {
    final collapsedHeight = 60.0 + MediaQuery.of(context).padding.top;

    return SliverAppBar(
      expandedHeight: 120,
      collapsedHeight: collapsedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                  : JobsColors.primaryGradient,
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _headerAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(_headerAnimation),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      // Logo & Title
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'İş İlanları',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, _) {
                                final stats = ref.watch(jobsDashboardStatsProvider);
                                return Text(
                                  stats.when(
                                    data: (s) => '${s['active_listings'] ?? 0} aktif ilan',
                                    loading: () => 'Yükleniyor...',
                                    error: (_, __) => '0 aktif ilan',
                                  ),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Search Button
                      _buildIconButton(
                        Icons.search,
                        () => _navigateToSearch(),
                      ),
                      const SizedBox(width: 8),
                      // Filter Button
                      _buildIconButton(
                        Icons.tune,
                        () => _showFilterSheet(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildStatsBanner(bool isDark) {
    final statsAsync = ref.watch(jobsDashboardStatsProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF334155)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: JobsColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: statsAsync.when(
        data: (stats) => Row(
          children: [
            _buildStatItem(
              isDark,
              Icons.work,
              '${stats['active_listings'] ?? 0}',
              'Aktif İlan',
            ),
            Container(
              width: 1,
              height: 40,
              color: JobsColors.border(isDark),
            ),
            _buildStatItem(
              isDark,
              Icons.business,
              '${stats['companies'] ?? 0}',
              'Şirket',
            ),
            Container(
              width: 1,
              height: 40,
              color: JobsColors.border(isDark),
            ),
            _buildStatItem(
              isDark,
              Icons.category,
              '${stats['categories'] ?? 0}',
              'Kategori',
            ),
            Container(
              width: 1,
              height: 40,
              color: JobsColors.border(isDark),
            ),
            _buildStatItem(
              isDark,
              Icons.bolt,
              '${stats['urgent_listings'] ?? 0}',
              'Acil',
            ),
          ],
        ),
        loading: () => const Center(
          child: SizedBox(
            height: 40,
            width: 40,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) => Row(
          children: [
            _buildStatItem(isDark, Icons.work, '0', 'Aktif İlan'),
            Container(width: 1, height: 40, color: JobsColors.border(isDark)),
            _buildStatItem(isDark, Icons.business, '0', 'Şirket'),
            Container(width: 1, height: 40, color: JobsColors.border(isDark)),
            _buildStatItem(isDark, Icons.category, '0', 'Kategori'),
            Container(width: 1, height: 40, color: JobsColors.border(isDark)),
            _buildStatItem(isDark, Icons.bolt, '0', 'Acil'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(bool isDark, IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: JobsColors.primary,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: JobsColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: JobsColors.textSecondary(isDark),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedShowcase(bool isDark, Size size) {
    final featuredJobsAsync = ref.watch(featuredJobsProvider);

    return featuredJobsAsync.when(
      data: (featuredJobsData) {
        if (featuredJobsData.isEmpty) return const SizedBox.shrink();

        final featuredJobs = featuredJobsData.toUIModels();

        return Container(
          height: 310,
          margin: const EdgeInsets.only(top: 16),
          child: Stack(
            children: [
              PageView.builder(
                itemCount: featuredJobs.length,
                onPageChanged: (index) {
                  setState(() => _currentShowcaseIndex = index);
                },
                itemBuilder: (context, index) {
                  final job = featuredJobs[index];
                  return _buildShowcaseCard(job, isDark, index);
                },
              ),

              // Page Indicators
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(featuredJobs.length, (index) {
                    final isActive = index == _currentShowcaseIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? JobsColors.primary
                            : JobsColors.textTertiary(isDark),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 310,
        margin: const EdgeInsets.only(top: 16),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildShowcaseCard(JobListing job, bool isDark, int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = index == _currentShowcaseIndex
            ? _pulseAnimation.value
            : 1.0;

        return Transform.scale(
          scale: scale * 0.95,
          child: GestureDetector(
            onTap: () => _navigateToDetail(job),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: job.isPremiumListing
                      ? JobsColors.premiumGradient
                      : JobsColors.primaryGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (job.isPremiumListing
                        ? const Color(0xFF1E1B4B)
                        : JobsColors.primary).withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background Pattern
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CustomPaint(
                        painter: _CardPatternPainter(),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Badges
                            Row(
                              children: [
                                if (job.isPremiumListing)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: JobsColors.featuredGradient,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'PREMIUM',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (job.isUrgent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: JobsColors.urgentGradient,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.bolt,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'ACİL',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Save Button
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.bookmark_border,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 18,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Company Info
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: job.companyLogo != null
                                    ? Image.network(
                                        job.companyLogo!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            job.companyName.substring(0, 1),
                                            style: TextStyle(
                                              color: JobsColors.primary,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          job.companyName.substring(0, 1),
                                          style: TextStyle(
                                            color: JobsColors.primary,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.companyName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.white.withValues(alpha: 0.7),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        job.location,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Job Title
                        Text(
                          job.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        // Tags
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildShowcaseTag(job.jobType.label, job.jobType.icon),
                            _buildShowcaseTag(job.workArrangement.label, job.workArrangement.icon),
                            _buildShowcaseTag(job.experienceLevel.label, Icons.trending_up),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Salary & Apply
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                job.salary.formatted,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.send,
                                    color: JobsColors.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Başvur',
                                    style: TextStyle(
                                      color: JobsColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
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
          ),
        );
      },
    );
  }

  Widget _buildShowcaseTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              Icons.add_circle_outline,
              'İlan Ver',
              'Pozisyon aç',
              JobsColors.primaryGradient,
              () => _navigateToAddListing(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              Icons.list_alt,
              'İlanlarım',
              'Yönet',
              JobsColors.techGradient,
              () => _navigateToMyListings(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              Icons.bookmark_outline,
              'Kaydedilenler',
              'Favoriler',
              JobsColors.featuredGradient,
              () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(bool isDark) {
    final categoriesAsync = ref.watch(jobCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Kategoriler',
            style: TextStyle(
              color: JobsColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: categoriesAsync.when(
            data: (dbCategories) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: dbCategories.length + 1, // +1 for "Tümü"
                itemBuilder: (context, index) {
                  // İlk item: Tümü butonu
                  if (index == 0) {
                    final isSelected = _selectedCategoryId == null;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategoryId = null);
                        ref.read(jobListProvider.notifier).clearFilters();
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 90,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? JobsColors.primary
                              : JobsColors.card(isDark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? JobsColors.primary
                                : JobsColors.border(isDark),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: JobsColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ] : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.apps,
                              color: isSelected ? Colors.white : JobsColors.primary,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tümü',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : JobsColors.textPrimary(isDark),
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Diğer kategoriler
                  final category = dbCategories[index - 1];
                  final isSelected = _selectedCategoryId == category.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategoryId = category.id);
                      ref.read(jobListProvider.notifier).updateFilter(categoryId: category.id);
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 90,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getCategoryColor(category.icon)
                            : JobsColors.card(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? _getCategoryColor(category.icon)
                              : JobsColors.border(isDark),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: _getCategoryColor(category.icon).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getCategoryIcon(category.icon),
                            color: isSelected
                                ? Colors.white
                                : _getCategoryColor(category.icon),
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : JobsColors.textPrimary(isDark),
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Kategoriler yüklenemedi')),
          ),
        ),
      ],
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

  Widget _buildSectionHeader(
    bool isDark,
    String title,
    String actionText,
    VoidCallback onAction, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: iconColor ?? JobsColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: onAction,
            child: Row(
              children: [
                Text(
                  actionText,
                  style: const TextStyle(
                    color: JobsColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: JobsColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentJobs(bool isDark) {
    final urgentJobsAsync = ref.watch(urgentJobsProvider);

    return urgentJobsAsync.when(
      data: (urgentJobsData) {
        if (urgentJobsData.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'Acil pozisyon yok',
                style: TextStyle(
                  color: JobsColors.textSecondary(isDark),
                ),
              ),
            ),
          );
        }

        final urgentJobs = urgentJobsData.toUIModels();

        return SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: urgentJobs.length,
            itemBuilder: (context, index) {
              final job = urgentJobs[index];
              return _buildUrgentJobCard(job, isDark);
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildUrgentJobCard(JobListing job, bool isDark) {
    return GestureDetector(
      onTap: () => _navigateToDetail(job),
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: JobsColors.urgentGradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: JobsColors.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Pattern
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: _CardPatternPainter(),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'ACİL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        job.deadlineText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Company
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            job.companyName.substring(0, 1),
                            style: TextStyle(
                              color: JobsColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          job.companyName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Title
                  Text(
                    job.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Bottom
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            job.city,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        job.salary.formatted,
                        style: const TextStyle(
                          color: Colors.white,
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

  Widget _buildRecentJobs(bool isDark) {
    final jobListState = ref.watch(jobListProvider);

    if (jobListState.isLoading && jobListState.listings.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (jobListState.listings.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.work_off_outlined,
                size: 48,
                color: JobsColors.textTertiary(isDark),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedCategoryId != null
                    ? 'Bu kategoride ilan bulunamadı'
                    : 'Henüz ilan yok',
                style: TextStyle(
                  color: JobsColors.textSecondary(isDark),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final listings = jobListState.listings.toUIModels();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final job = listings[index];
          return _buildJobCard(job, isDark);
        },
        childCount: listings.length,
      ),
    );
  }

  Widget _buildJobCard(JobListing job, bool isDark) {
    return GestureDetector(
      onTap: () => _navigateToDetail(job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(20),
          border: job.isPremiumListing
              ? Border.all(
                  color: JobsColors.secondary.withValues(alpha: 0.3),
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Logo
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: JobsColors.surface(isDark),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: JobsColors.border(isDark),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: job.companyLogo != null
                              ? Image.network(
                                  job.companyLogo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      job.companyName.substring(0, 1),
                                      style: TextStyle(
                                        color: job.category.color,
                                        fontSize: 22,
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
                                      fontSize: 22,
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
                            // Badges
                            Row(
                              children: [
                                if (job.isPremiumListing)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: JobsColors.featuredGradient,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'P',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (job.isUrgent)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: JobsColors.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.bolt,
                                          color: JobsColors.accent,
                                          size: 12,
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
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Title
                            Text(
                              job.title,
                              style: TextStyle(
                                color: JobsColors.textPrimary(isDark),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Save Button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: JobsColors.surface(isDark),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.bookmark_border,
                          color: JobsColors.textSecondary(isDark),
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Tags Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildJobTag(
                        isDark,
                        job.jobType.label,
                        job.jobType.icon,
                        job.jobType.color,
                      ),
                      _buildJobTag(
                        isDark,
                        job.workArrangement.label,
                        job.workArrangement.icon,
                        job.workArrangement.color,
                      ),
                      _buildJobTag(
                        isDark,
                        job.experienceLevel.label,
                        Icons.trending_up,
                        JobsColors.textSecondary(isDark),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Bottom Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Location & Time
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: JobsColors.textTertiary(isDark),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            job.location,
                            style: TextStyle(
                              color: JobsColors.textSecondary(isDark),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: JobsColors.textTertiary(isDark),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            job.timeAgo,
                            style: TextStyle(
                              color: JobsColors.textTertiary(isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Salary
                      Text(
                        job.salary.formatted,
                        style: TextStyle(
                          color: JobsColors.primary,
                          fontSize: 15,
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

  Widget _buildJobTag(bool isDark, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAddButton(bool isDark) {
    return Positioned(
      right: 20,
      bottom: 100,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: GestureDetector(
              onTap: _navigateToAddListing,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: JobsColors.primaryGradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: JobsColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Navigation methods
  void _navigateToSearch() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const JobSearchScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
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
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToAddListing() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const AddJobListingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToMyListings() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const MyJobListingsScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: JobsColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const Center(child: Text('Filter Sheet - Coming Soon')),
        );
      },
    );
  }
}

// Custom painters
class _BackgroundPainter extends CustomPainter {
  final bool isDark;
  final double animationValue;
  final double scrollOffset;

  _BackgroundPainter({
    required this.isDark,
    required this.animationValue,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Animated circles in background
    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + i * 0.33) % 1.0;
      final x = size.width * (0.1 + 0.8 * math.sin(progress * math.pi * 2 + i));
      final y = (size.height * 0.2 - scrollOffset * 0.1).clamp(0, size.height * 0.5);
      final radius = 100.0 + 50 * math.sin(progress * math.pi * 2);

      paint.color = (isDark
          ? JobsColors.primary
          : JobsColors.primaryLight).withValues(alpha: 0.05);

      canvas.drawCircle(Offset(x, y + i * 100), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        scrollOffset != oldDelegate.scrollOffset;
  }
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw grid pattern
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
