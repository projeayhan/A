import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/jobs/job_models.dart';
import '../../core/providers/unified_favorites_provider.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final JobListing job;

  const JobDetailScreen({super.key, required this.job});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late ScrollController _scrollController;

  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() => _scrollOffset = _scrollController.offset);
      });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final job = widget.job;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: JobsColors.background(isDark),
        body: Stack(
          children: [
            // Main content
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Hero Header
                SliverToBoxAdapter(child: _buildHeroHeader(isDark, size, job)),

                // Content
                SliverToBoxAdapter(child: _buildJobInfo(isDark, job)),

                SliverToBoxAdapter(child: _buildCompanySection(isDark, job)),

                SliverToBoxAdapter(
                  child: _buildDescriptionSection(isDark, job),
                ),

                if (job.responsibilities.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildListSection(
                      isDark,
                      'Sorumluluklar',
                      Icons.assignment,
                      job.responsibilities,
                    ),
                  ),

                if (job.qualifications.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildListSection(
                      isDark,
                      'Aranan Nitelikler',
                      Icons.checklist,
                      job.qualifications,
                    ),
                  ),

                SliverToBoxAdapter(child: _buildSkillsSection(isDark, job)),

                SliverToBoxAdapter(child: _buildBenefitsSection(isDark, job)),

                SliverToBoxAdapter(child: _buildContactSection(isDark, job)),

                // Bottom spacing
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 90 + MediaQuery.of(context).padding.bottom,
                  ),
                ),
              ],
            ),

            // Sticky Header
            _buildStickyHeader(isDark, job),

            // Bottom Apply Button
            _buildBottomApplyButton(isDark, job),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isDark, Size size, JobListing job) {
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: job.isPremiumListing
                      ? JobsColors.premiumGradient
                      : [
                          job.category.color,
                          job.category.color.withValues(alpha: 0.8),
                        ],
                ),
              ),
            ),
          ),

          // Pattern
          Positioned.fill(child: CustomPaint(painter: _HeroPatternPainter())),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges Row
                    const SizedBox(height: 48),
                    Row(
                      children: [
                        if (job.isPremiumListing)
                          _buildBadge(
                            Icons.star,
                            'PREMIUM',
                            JobsColors.featuredGradient,
                          ),
                        if (job.isUrgent) ...[
                          const SizedBox(width: 8),
                          _buildBadge(
                            Icons.bolt,
                            'ACİL',
                            JobsColors.urgentGradient,
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.visibility,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${job.viewCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Company Logo
                    Row(
                      children: [
                        Hero(
                          tag: 'job_logo_${job.id}',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: job.companyLogo != null
                                  ? Image.network(
                                      job.companyLogo!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildCompanyInitial(job),
                                    )
                                  : _buildCompanyInitial(job),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.companyName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    job.location,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Job Title
                    Text(
                      job.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    // Tags
                    Row(
                      children: [
                        _buildHeroTag(job.jobType.label, job.jobType.icon),
                        const SizedBox(width: 8),
                        _buildHeroTag(
                          job.workArrangement.label,
                          job.workArrangement.icon,
                        ),
                        const SizedBox(width: 8),
                        _buildHeroTag(
                          job.experienceLevel.label,
                          Icons.trending_up,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInitial(JobListing job) {
    return Center(
      child: Text(
        job.companyName.substring(0, 1),
        style: TextStyle(
          color: job.category.color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(bool isDark, JobListing job) {
    final opacity = (_scrollOffset / 200).clamp(0.0, 1.0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 12,
          right: 12,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: job.isPremiumListing
              ? JobsColors.premiumGradient.first.withValues(alpha: opacity)
              : job.category.color.withValues(alpha: opacity),
          boxShadow: opacity > 0.5
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: opacity > 0.5 ? 0.2 : 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: opacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      job.companyName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildHeaderSaveButton(opacity),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _shareJob(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: opacity > 0.5 ? 0.2 : 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobInfo(bool isDark, JobListing job) {
    return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Salary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maaş',
                      style: TextStyle(
                        color: JobsColors.textSecondary(isDark),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.salary.fullFormatted,
                      style: TextStyle(
                        color: JobsColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _applyJob,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: JobsColors.primaryGradient),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: JobsColors.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.send, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Hızlı Başvur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: JobsColors.border(isDark)),
            const SizedBox(height: 12),

            // Info Grid
            Row(
              children: [
                _buildInfoItem(
                  isDark,
                  Icons.work_outline,
                  'Pozisyon',
                  job.positions != null ? '${job.positions} Kişi' : '1 Kişi',
                ),
                _buildInfoItem(
                  isDark,
                  Icons.school_outlined,
                  'Eğitim',
                  job.educationLevel.label,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoItem(
                  isDark,
                  Icons.calendar_today_outlined,
                  'İlan Tarihi',
                  job.timeAgo,
                ),
                _buildInfoItem(
                  isDark,
                  Icons.timer_outlined,
                  'Son Başvuru',
                  job.deadline != null ? job.deadlineText : 'Belirtilmemiş',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoItem(
                  isDark,
                  Icons.people_outline,
                  'Başvuru',
                  '${job.applicationCount} Kişi',
                ),
                _buildInfoItem(
                  isDark,
                  Icons.bookmark_outline,
                  'Kaydeden',
                  '${job.saveCount} Kişi',
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildInfoItem(
    bool isDark,
    IconData icon,
    String label,
    String value,
  ) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: JobsColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: JobsColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: JobsColors.textTertiary(isDark),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: JobsColors.textPrimary(isDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySection(bool isDark, JobListing job) {
    if (job.company == null) return const SizedBox.shrink();

    final company = job.company!;

    return GestureDetector(
      onTap: () => _showCompanyDetails(company),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: JobsColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Şirket Hakkında',
                  style: TextStyle(
                    color: JobsColors.textPrimary(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Company Info Row
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: JobsColors.surface(isDark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: JobsColors.border(isDark)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: company.logoUrl != null
                        ? Image.network(
                            company.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                company.name.substring(0, 1),
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
                              company.name.substring(0, 1),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              company.name,
                              style: TextStyle(
                                color: JobsColors.textPrimary(isDark),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (company.isVerified) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.verified,
                              color: JobsColors.primary,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${company.industry} • ${company.size}',
                        style: TextStyle(
                          color: JobsColors.textSecondary(isDark),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (company.rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: JobsColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: JobsColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          company.rating.toString(),
                          style: const TextStyle(
                            color: JobsColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (company.description != null) ...[
              const SizedBox(height: 16),
              Text(
                company.description!,
                style: TextStyle(
                  color: JobsColors.textSecondary(isDark),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Company Stats
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: JobsColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompanyStat(
                    isDark,
                    company.reviewCount.toString(),
                    'Değerlendirme',
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: JobsColors.border(isDark),
                  ),
                  _buildCompanyStat(
                    isDark,
                    company.size.split(' ').first,
                    'Çalışan',
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: JobsColors.border(isDark),
                  ),
                  _buildCompanyStat(
                    isDark,
                    '${DateTime.now().year - company.foundedYear.year}',
                    'Yıllık',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompanyDetails(Company company) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: JobsColors.border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Header
                    Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: JobsColors.surface(isDark),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: JobsColors.border(isDark),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              company.name.substring(0, 1),
                              style: TextStyle(
                                color: JobsColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      company.name,
                                      style: TextStyle(
                                        color: JobsColors.textPrimary(isDark),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (company.isVerified) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.verified,
                                      color: JobsColors.primary,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                company.industry,
                                style: TextStyle(
                                  color: JobsColors.textSecondary(isDark),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats Row
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: JobsColors.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCompanyStatItem(
                            company.rating.toString(),
                            'Puan',
                            Icons.star,
                          ),
                          _buildCompanyStatItem(
                            company.reviewCount.toString(),
                            'Yorum',
                            Icons.chat,
                          ),
                          _buildCompanyStatItem(
                            company.size.split(' ').first,
                            'Çalışan',
                            Icons.people,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // About
                    Text(
                      'Hakkında',
                      style: TextStyle(
                        color: JobsColors.textPrimary(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      company.description ??
                          '${company.name}, ${company.industry} sektöründe faaliyet gösteren lider bir şirkettir.',
                      style: TextStyle(
                        color: JobsColors.textSecondary(isDark),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Info Items
                    _buildCompanyInfoRow(
                      isDark,
                      Icons.location_on,
                      'Konum',
                      company.location ?? 'İstanbul, Türkiye',
                    ),
                    _buildCompanyInfoRow(
                      isDark,
                      Icons.calendar_today,
                      'Kuruluş',
                      '${company.foundedYear.year}',
                    ),
                    _buildCompanyInfoRow(
                      isDark,
                      Icons.language,
                      'Website',
                      company.website ??
                          'www.${company.name.toLowerCase().replaceAll(' ', '')}.com',
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Şirket takip ediliyor'),
                                  backgroundColor: JobsColors.primary,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: JobsColors.primaryGradient,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Takip Et',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Şirket ilanları gösteriliyor',
                                ),
                                backgroundColor: JobsColors.primary,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: JobsColors.surface(isDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: JobsColors.border(isDark),
                              ),
                            ),
                            child: Icon(
                              Icons.work_outline,
                              color: JobsColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyInfoRow(
    bool isDark,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: JobsColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: JobsColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: JobsColors.textTertiary(isDark),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyStat(bool isDark, String value, String label) {
    return Column(
      children: [
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
            color: JobsColors.textTertiary(isDark),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(bool isDark, JobListing job) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: JobsColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'İlan Açıklaması',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            job.description,
            style: TextStyle(
              color: JobsColors.textSecondary(isDark),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(
    bool isDark,
    String title,
    IconData icon,
    List<String> items,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: JobsColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: JobsColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: JobsColors.textSecondary(isDark),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(bool isDark, JobListing job) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, color: JobsColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Gerekli Yetenekler',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: job.requiredSkills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: JobsColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: JobsColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                    color: JobsColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),

          if (job.preferredSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Tercih Edilen',
              style: TextStyle(
                color: JobsColors.textSecondary(isDark),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: job.preferredSkills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: JobsColors.surface(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: JobsColors.border(isDark)),
                  ),
                  child: Text(
                    skill,
                    style: TextStyle(
                      color: JobsColors.textSecondary(isDark),
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(bool isDark, JobListing job) {
    if (job.benefitIds.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, color: JobsColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Yan Haklar',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: job.benefits.map((benefit) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      JobsColors.success.withValues(alpha: 0.1),
                      JobsColors.success.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(benefit.icon, color: JobsColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      benefit.name,
                      style: TextStyle(
                        color: JobsColors.textPrimary(isDark),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(bool isDark, JobListing job) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: JobsColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'İlan Sahibi',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: JobsColors.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: job.poster.imageUrl != null
                      ? Image.network(
                          job.poster.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: JobsColors.surface(isDark),
                            child: Icon(
                              Icons.person,
                              color: JobsColors.textTertiary(isDark),
                            ),
                          ),
                        )
                      : Container(
                          color: JobsColors.surface(isDark),
                          child: Icon(
                            Icons.person,
                            color: JobsColors.textTertiary(isDark),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            job.poster.name,
                            style: TextStyle(
                              color: JobsColors.textPrimary(isDark),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (job.poster.isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            color: JobsColors.primary,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    if (job.poster.title != null)
                      Text(
                        job.poster.title!,
                        style: TextStyle(
                          color: JobsColors.textSecondary(isDark),
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      job.poster.membershipDuration,
                      style: TextStyle(
                        color: JobsColors.textTertiary(isDark),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: JobsColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '%${job.poster.responseRate.toInt()}',
                  style: const TextStyle(
                    color: JobsColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildContactButton(isDark, Icons.phone, 'Ara', () {}),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactButton(
                  isDark,
                  Icons.message,
                  'Mesaj',
                  () {},
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(
    bool isDark,
    IconData icon,
    String text,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? JobsColors.primary : JobsColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: JobsColors.border(isDark)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary
                  ? Colors.white
                  : JobsColors.textSecondary(isDark),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: isPrimary
                    ? Colors.white
                    : JobsColors.textPrimary(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomApplyButton(bool isDark, JobListing job) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Save Button
            _buildSaveButton(isDark),
            const SizedBox(width: 12),

            // Apply Button
            Expanded(
              child: GestureDetector(
                onTap: _applyJob,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: JobsColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: JobsColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Şimdi Başvur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSaveButton(double opacity) {
    final isSaved = ref.watch(isJobFavoriteProvider(widget.job.id));

    return GestureDetector(
      onTap: () => _toggleSave(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity > 0.5 ? 0.2 : 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_border,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    final isSaved = ref.watch(isJobFavoriteProvider(widget.job.id));

    return GestureDetector(
      onTap: _toggleSave,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isSaved
              ? JobsColors.primary.withValues(alpha: 0.1)
              : JobsColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSaved ? JobsColors.primary : JobsColors.border(isDark),
          ),
        ),
        child: Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_border,
          color: isSaved
              ? JobsColors.primary
              : JobsColors.textSecondary(isDark),
        ),
      ),
    );
  }

  void _toggleSave() {
    final job = widget.job;
    final isSaved = ref.read(isJobFavoriteProvider(job.id));

    final favoriteJob = FavoriteJob(
      id: job.id,
      title: job.title,
      companyName: job.company?.name ?? 'Şirket',
      companyLogo: job.company?.logoUrl ?? '',
      location: job.city,
      salary: job.salary.formatted,
      employmentType: job.jobType.label,
      tags: job.requiredSkills.take(3).toList(),
      addedAt: DateTime.now(),
    );
    ref.read(jobFavoriteProvider.notifier).toggleJob(favoriteJob);

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSaved ? 'Kayıttan kaldırıldı' : 'İlan kaydedildi'),
        backgroundColor: isSaved ? Colors.red : JobsColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareJob() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Paylaşım linki kopyalandı'),
        backgroundColor: JobsColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _applyJob() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildApplyBottomSheet(),
    );
  }

  Widget _buildApplyBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: JobsColors.border(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: JobsColors.primaryGradient,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Başvuru Yap',
                              style: TextStyle(
                                color: JobsColors.textPrimary(isDark),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.job.title,
                              style: TextStyle(
                                color: JobsColors.textSecondary(isDark),
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Quick Apply Option
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _showApplicationSuccessDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: JobsColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: JobsColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: JobsColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.bolt, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hızlı Başvuru',
                                  style: TextStyle(
                                    color: JobsColors.textPrimary(isDark),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Kayıtlı CV\'niz ile hemen başvurun',
                                  style: TextStyle(
                                    color: JobsColors.textSecondary(isDark),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: JobsColors.primary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Upload CV Option
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _showCVUploadDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: JobsColors.surface(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: JobsColors.border(isDark)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: JobsColors.secondary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.upload_file,
                              color: JobsColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CV Yükle',
                                  style: TextStyle(
                                    color: JobsColors.textPrimary(isDark),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'PDF, DOC formatlarında yükleyin',
                                  style: TextStyle(
                                    color: JobsColors.textSecondary(isDark),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: JobsColors.textTertiary(isDark),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _showApplicationSuccessDialog();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: JobsColors.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: JobsColors.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Başvuruyu Gönder',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicationSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: JobsColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [JobsColors.success, Color(0xFF34D399)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Başvuru Gönderildi!',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Başvurunuz başarıyla iletildi. İşveren en kısa sürede sizinle iletişime geçecektir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JobsColors.textSecondary(isDark),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: JobsColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Tamam',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCVUploadDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: JobsColors.border(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: JobsColors.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  color: JobsColors.secondary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'CV Yükle',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PDF veya DOC formatında CV\'nizi yükleyin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JobsColors.textSecondary(isDark),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  // Simüle edilen dosya yükleme
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _showApplicationSuccessDialog();
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: JobsColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.attach_file, color: JobsColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Dosya Seç',
                        style: TextStyle(
                          color: JobsColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Maksimum dosya boyutu: 5 MB',
                style: TextStyle(
                  color: JobsColors.textTertiary(isDark),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw circles
    for (int i = 0; i < 5; i++) {
      final radius = 50.0 + i * 60;
      canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.3),
        radius,
        paint,
      );
    }

    // Draw diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
