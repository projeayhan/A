import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_responsive.dart';
import '../../models/jobs/job_models.dart';
import '../../models/jobs/job_model_extensions.dart';
import '../../core/providers/jobs_provider.dart';
import '../../core/providers/banner_provider.dart';
import '../../widgets/common/generic_banner_carousel.dart';
import 'job_detail_screen.dart';
import 'add_job_listing_screen.dart';
import 'my_job_listings_screen.dart';
import 'job_search_screen.dart';
import 'job_conversations_screen.dart';
import '../../core/providers/job_chat_provider.dart';

class JobsHomeScreen extends ConsumerStatefulWidget {
  const JobsHomeScreen({super.key});

  @override
  ConsumerState<JobsHomeScreen> createState() => _JobsHomeScreenState();
}

class _JobsHomeScreenState extends ConsumerState<JobsHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  final ScrollController _scrollController = ScrollController();
  String? _selectedCategoryId; // null = Tümü
  String? _selectedListingType; // null = Tümü, 'hiring', 'seeking'
  int _currentShowcaseIndex = 0;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );

    _headerController.forward();

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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GenericBannerCarousel(
                      bannerProvider: jobsBannersProvider,
                      height: 130,
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

                // Listing Type Filter Tabs
                SliverToBoxAdapter(
                  child: _buildListingTypeTabs(isDark),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
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
                      // Messages Button
                      _buildMessagesIconButton(),
                      const SizedBox(width: 8),
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

  Widget _buildMessagesIconButton() {
    return Consumer(
      builder: (context, ref, _) {
        final unreadAsync = ref.watch(jobUnreadCountProvider);
        final unread = unreadAsync.valueOrNull ?? 0;

        return GestureDetector(
          onTap: () => _navigateToMessages(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsBanner(bool isDark) {
    final statsAsync = ref.watch(jobsDashboardStatsProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              fontSize: 15,
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
          height: 260,
          margin: const EdgeInsets.only(top: 10),
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
        height: 260,
        margin: const EdgeInsets.only(top: 10),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildShowcaseCard(JobListing job, bool isDark, int index) {
    return GestureDetector(
      onTap: () => _navigateToDetail(job),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
                  : JobsColors.primary).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header badges
              Row(
                children: [
                  // Listing type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(job.listingType.icon, color: Colors.white, size: 12),
                        const SizedBox(width: 3),
                        Text(job.listingType.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (job.isPremiumListing) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: JobsColors.featuredGradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 12),
                          SizedBox(width: 3),
                          Text('PREMIUM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  if (job.isUrgent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: JobsColors.urgentGradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: Colors.white, size: 12),
                          SizedBox(width: 3),
                          Text('ACİL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.bookmark_border, color: Colors.white.withValues(alpha: 0.8), size: 20),
                ],
              ),
              const SizedBox(height: 10),
              // Company Info
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: job.companyLogo != null
                          ? CachedNetworkImage(
                              imageUrl: job.companyLogo!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Center(
                                child: Text(job.companyName.substring(0, 1),
                                  style: TextStyle(color: JobsColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            )
                          : Center(
                              child: Text(job.companyName.substring(0, 1),
                                style: TextStyle(color: JobsColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.companyName,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.white.withValues(alpha: 0.7), size: 12),
                            const SizedBox(width: 3),
                            Text(job.location, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Job Title
              Text(job.title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
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
              const SizedBox(height: 8),
              // Salary & Apply
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(job.salary.formatted,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          job.listingType == ListingType.seeking ? Icons.phone : Icons.send,
                          color: job.listingType.color,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          job.listingType == ListingType.seeking ? 'İletişim' : 'Başvur',
                          style: TextStyle(color: job.listingType.color, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
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
          const SizedBox(width: 10),
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
          const SizedBox(width: 10),
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              Icons.forum_outlined,
              'Mesajlar',
              'Sohbetler',
              [const Color(0xFF0EA5E9), const Color(0xFF2563EB)],
              () => _navigateToMessages(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              Icons.bookmark_outline,
              'Kayıtlı',
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingTypeTabs(bool isDark) {
    final tabs = [
      {'value': null, 'label': 'Tümü', 'icon': Icons.apps},
      {'value': 'hiring', 'label': 'Eleman Arıyorum', 'icon': Icons.business_center},
      {'value': 'seeking', 'label': 'İş Arıyorum', 'icon': Icons.person_search},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: tabs.map((tab) {
          final value = tab['value'] as String?;
          final label = tab['label'] as String;
          final icon = tab['icon'] as IconData;
          final isSelected = _selectedListingType == value;

          Color tabColor;
          if (value == 'hiring') {
            tabColor = const Color(0xFF3B82F6);
          } else if (value == 'seeking') {
            tabColor = const Color(0xFF10B981);
          } else {
            tabColor = JobsColors.primary;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedListingType = value);
                ref.read(jobListProvider.notifier).setListingType(value);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? tabColor : JobsColors.card(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? tabColor : JobsColors.border(isDark),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: tabColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected ? Colors.white : tabColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : JobsColors.textPrimary(isDark),
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategories(bool isDark) {
    final categoriesAsync = ref.watch(jobCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            'Kategoriler',
            style: TextStyle(
              color: JobsColors.textPrimary(isDark),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 86,
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
                        setState(() {
                          _selectedCategoryId = null;
                          _selectedListingType = null;
                        });
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                  fontSize: 15,
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
          height: 160,
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
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildUrgentJobCard(JobListing job, bool isDark) {
    return GestureDetector(
      onTap: () => _navigateToDetail(job),
      child: Container(
        width: 260,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: JobsColors.urgentGradient,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: JobsColors.accent.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: job.isPremiumListing
                ? JobsColors.secondary.withValues(alpha: 0.4)
                : JobsColors.border(isDark),
            width: job.isPremiumListing ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Company info + bookmark
            Row(
              children: [
                // Company Logo
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: job.category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: job.companyLogo != null
                        ? CachedNetworkImage(
                            imageUrl: job.companyLogo!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Center(
                              child: Text(
                                job.companyName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: job.category.color,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Text(
                                job.companyName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: job.category.color,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              job.companyName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: job.category.color,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Company name + listing type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.companyName,
                        style: TextStyle(
                          color: JobsColors.textSecondary(isDark),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Listing type inline
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: job.listingType.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  job.listingType.icon,
                                  color: job.listingType.color,
                                  size: 10,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  job.listingType.label,
                                  style: TextStyle(
                                    color: job.listingType.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (job.isPremiumListing) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: JobsColors.featuredGradient,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: Colors.white, size: 10),
                                  SizedBox(width: 2),
                                  Text(
                                    'Premium',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (job.isUrgent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: JobsColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, color: JobsColors.accent, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Acil',
                                    style: TextStyle(
                                      color: JobsColors.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Bookmark
                GestureDetector(
                  onTap: () {}, // TODO: save job
                  child: Icon(
                    Icons.bookmark_border_rounded,
                    color: JobsColors.textTertiary(isDark),
                    size: 22,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2: Job Title
            Text(
              job.title,
              style: TextStyle(
                color: JobsColors.textPrimary(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Row 3: Tags
            Row(
              children: [
                _buildJobTag(isDark, job.jobType.label, job.jobType.icon, job.jobType.color),
                const SizedBox(width: 8),
                _buildJobTag(isDark, job.workArrangement.label, job.workArrangement.icon, job.workArrangement.color),
                const SizedBox(width: 8),
                _buildJobTag(isDark, job.experienceLevel.label, Icons.trending_up, JobsColors.textSecondary(isDark)),
              ],
            ),

            const SizedBox(height: 12),

            // Row 4: Location + Time | Salary
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: JobsColors.textTertiary(isDark),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    job.location,
                    style: TextStyle(
                      color: JobsColors.textSecondary(isDark),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: JobsColors.textTertiary(isDark),
                ),
                const SizedBox(width: 3),
                Text(
                  job.timeAgo,
                  style: TextStyle(
                    color: JobsColors.textTertiary(isDark),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  job.salary.formatted,
                  style: TextStyle(
                    color: JobsColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
      right: 16,
      bottom: 100,
      child: FloatingActionButton(
        onPressed: _navigateToAddListing,
        backgroundColor: JobsColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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

  void _navigateToMessages() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const JobConversationsScreen(),
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
