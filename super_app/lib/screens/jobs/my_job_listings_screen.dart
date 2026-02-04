import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/jobs/job_models.dart';
import '../../models/jobs/job_data_models.dart';
import '../../services/jobs_service.dart';
import '../../widgets/moderation_feedback_widget.dart';
import '../../core/utils/app_dialogs.dart';
import 'add_job_listing_screen.dart';

class MyJobListingsScreen extends StatefulWidget {
  const MyJobListingsScreen({super.key});

  @override
  State<MyJobListingsScreen> createState() => _MyJobListingsScreenState();
}

class _MyJobListingsScreenState extends State<MyJobListingsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;

  List<JobListingData> _activeListings = [];
  List<JobListingData> _pendingListings = [];
  List<JobListingData> _rejectedListings = [];
  List<JobListingData> _closedListings = [];

  // Loading state
  bool _isLoading = true;

  // Moderasyon bilgileri cache'i
  final Map<String, ModerationInfo> _moderationCache = {};

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    // Supabase'den ilanları yükle
    _loadUserListings();
  }

  Future<void> _loadUserListings() async {
    try {
      final jobsService = JobsService.instance;

      // Tüm kullanıcı ilanlarını çek
      final allListings = await jobsService.getUserListings();

      if (mounted) {
        setState(() {
          // Status'e göre ayır
          _activeListings = allListings.where((l) => l.status == 'active').toList();
          _pendingListings = allListings.where((l) => l.status == 'pending').toList();
          _rejectedListings = allListings.where((l) => l.status == 'rejected').toList();
          _closedListings = allListings.where((l) => l.status == 'closed' || l.status == 'expired').toList();
          _isLoading = false;
        });

        // Moderasyon bilgilerini yükle
        _loadModerationInfo();
      }
    } catch (e) {
      debugPrint('_loadUserListings error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadModerationInfo() async {
    final jobsService = JobsService.instance;

    // Pending ve rejected listelerindeki ilanlar için moderasyon bilgisi al
    for (final listing in [..._pendingListings, ..._rejectedListings]) {
      try {
        final result = await jobsService.getModerationResult(listing.id);
        if (result != null && mounted) {
          setState(() {
            _moderationCache[listing.id] = ModerationInfo(
              status: ModerationStatus.fromString(result.result),
              score: result.score,
              reason: result.reason,
              flags: result.flags,
            );
          });
        }
      } catch (e) {
        // Hata durumunda sessizce devam et
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  int get _totalListings =>
      _activeListings.length + _pendingListings.length + _rejectedListings.length + _closedListings.length;

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
              _buildHeader(isDark),
              _buildStatsCards(isDark),
              _buildTabBar(isDark),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListingsTab(_activeListings, isDark, 'active'),
                    _buildListingsTab(_pendingListings, isDark, 'pending'),
                    _buildListingsTab(_rejectedListings, isDark, 'rejected'),
                    _buildListingsTab(_closedListings, isDark, 'closed'),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFAB(isDark),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlanlarım',
                  style: TextStyle(
                    color: JobsColors.textPrimary(isDark),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_totalListings toplam ilan',
                  style: TextStyle(
                    color: JobsColors.textSecondary(isDark),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showOptionsMenu(isDark),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: JobsColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.more_vert,
                color: JobsColors.textPrimary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              isDark,
              Icons.visibility,
              '12.5K',
              'Görüntülenme',
              JobsColors.primaryGradient,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              isDark,
              Icons.people,
              '847',
              'Başvuru',
              JobsColors.techGradient,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              isDark,
              Icons.bookmark,
              '156',
              'Kaydeden',
              JobsColors.featuredGradient,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    bool isDark,
    IconData icon,
    String value,
    String label,
    List<Color> gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
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
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JobsColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: JobsColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: JobsColors.textSecondary(isDark),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Aktif'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_activeListings.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bekleyen'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_pendingListings.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Red'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rejectedListings.isNotEmpty
                        ? JobsColors.error.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_rejectedListings.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Kapalı'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_closedListings.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTab(List<JobListingData> listings, bool isDark, String type) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (listings.isEmpty) {
      return _buildEmptyState(isDark, type);
    }

    return RefreshIndicator(
      onRefresh: _loadUserListings,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: listings.length,
        itemBuilder: (context, index) {
          return _buildListingCard(listings[index], isDark, type, index);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String type) {
    String message;
    IconData icon;

    switch (type) {
      case 'active':
        message = 'Aktif ilanınız bulunmuyor';
        icon = Icons.work_outline;
        break;
      case 'pending':
        message = 'Onay bekleyen ilanınız yok';
        icon = Icons.hourglass_empty;
        break;
      case 'rejected':
        message = 'Reddedilen ilanınız yok';
        icon = Icons.cancel_outlined;
        break;
      case 'closed':
        message = 'Kapatılmış ilanınız yok';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'İlan bulunamadı';
        icon = Icons.inbox;
    }

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
              icon,
              size: 40,
              color: JobsColors.textTertiary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: JobsColors.textSecondary(isDark),
              fontSize: 16,
            ),
          ),
          if (type == 'active') ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _navigateToAddListing(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: JobsColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'İlan Oluştur',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListingCard(JobListingData job, bool isDark, String type, int index) {
    return Dismissible(
      key: Key(job.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: JobsColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Sil',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmationDialog(job, isDark);
      },
      onDismissed: (direction) {
        _deleteListing(job, type, index);
      },
      child: GestureDetector(
        onTap: () => _navigateToDetail(job),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: JobsColors.card(isDark),
            borderRadius: BorderRadius.circular(20),
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
                        // Job Type Icon (instead of category)
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: job.jobTypeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            job.jobTypeIcon,
                            color: job.jobTypeColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Job Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(type),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getStatusIcon(type),
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getStatusLabel(type),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    job.timeAgo,
                                    style: TextStyle(
                                      color: JobsColors.textTertiary(isDark),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
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

                        // Options Menu
                        GestureDetector(
                          onTap: () => _showListingOptions(job, isDark, type, index),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: JobsColors.surface(isDark),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.more_horiz,
                              color: JobsColors.textSecondary(isDark),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Stats Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JobsColors.surface(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildListingStatItem(
                            isDark,
                            Icons.visibility,
                            '${job.viewCount}',
                            'Görüntülenme',
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: JobsColors.border(isDark),
                          ),
                          _buildListingStatItem(
                            isDark,
                            Icons.people,
                            '${job.applicationCount}',
                            'Başvuru',
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: JobsColors.border(isDark),
                          ),
                          _buildListingStatItem(
                            isDark,
                            Icons.bookmark,
                            '${job.favoriteCount}',
                            'Kaydeden',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Moderasyon Feedback (sadece reddedilen veya bekleyen ilanlar için)
                    if ((type == 'rejected' || type == 'pending') && _moderationCache.containsKey(job.id)) ...[
                      _buildModerationFeedbackSection(isDark, job.id, type),
                      const SizedBox(height: 12),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Row(
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
                              if (job.deadline != null) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.timer,
                                  size: 14,
                                  color: JobsColors.textTertiary(isDark),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  job.deadlineText,
                                  style: TextStyle(
                                    color: JobsColors.textSecondary(isDark),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildActionButton(
                              isDark,
                              Icons.edit,
                              'Düzenle',
                              () => _editListing(job),
                            ),
                            const SizedBox(width: 8),
                            if (type == 'active')
                              _buildActionButton(
                                isDark,
                                Icons.pause_circle,
                                'Kapat',
                                () => _closeListing(job, index),
                                isWarning: true,
                              ),
                            if (type == 'rejected')
                              _buildActionButton(
                                isDark,
                                Icons.info_outline,
                                'Detay',
                                () => _showModerationDetails(job, isDark),
                                isWarning: true,
                              ),
                            if (type == 'closed')
                              _buildActionButton(
                                isDark,
                                Icons.play_circle,
                                'Yayınla',
                                () => _reopenListing(job, index),
                                isPrimary: true,
                              ),
                          ],
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
  }

  Widget _buildListingStatItem(
      bool isDark, IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: JobsColors.textSecondary(isDark)),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: JobsColors.textPrimary(isDark),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: JobsColors.textTertiary(isDark),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    bool isDark,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isPrimary = false,
    bool isWarning = false,
  }) {
    Color bgColor;
    Color textColor;

    if (isPrimary) {
      bgColor = JobsColors.success;
      textColor = Colors.white;
    } else if (isWarning) {
      bgColor = JobsColors.warning.withValues(alpha: 0.1);
      textColor = JobsColors.warning;
    } else {
      bgColor = JobsColors.surface(isDark);
      textColor = JobsColors.textSecondary(isDark);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: (isPrimary || isWarning)
              ? null
              : Border.all(color: JobsColors.border(isDark)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddListing,
      backgroundColor: JobsColors.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Yeni İlan',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String type) {
    switch (type) {
      case 'active':
        return JobsColors.success;
      case 'pending':
        return JobsColors.warning;
      case 'rejected':
        return JobsColors.error;
      case 'closed':
        return JobsColors.textTertiary(false);
      default:
        return JobsColors.primary;
    }
  }

  IconData _getStatusIcon(String type) {
    switch (type) {
      case 'active':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'rejected':
        return Icons.cancel;
      case 'closed':
        return Icons.pause_circle;
      default:
        return Icons.info;
    }
  }

  String _getStatusLabel(String type) {
    switch (type) {
      case 'active':
        return 'Aktif';
      case 'pending':
        return 'Onay Bekliyor';
      case 'rejected':
        return 'Reddedildi';
      case 'closed':
        return 'Kapatıldı';
      default:
        return '';
    }
  }

  Widget _buildModerationFeedbackSection(bool isDark, String jobId, String type) {
    final info = _moderationCache[jobId];
    if (info == null) return const SizedBox.shrink();

    final isRejected = type == 'rejected' || info.status == ModerationStatus.rejected;
    final color = isRejected ? JobsColors.error : JobsColors.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                isRejected ? 'Reddedilme Sebebi' : 'İnceleme Durumu',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (info.reason != null && info.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              info.reason!.length > 100 ? '${info.reason!.substring(0, 100)}...' : info.reason!,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (info.flags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: info.flags.take(3).map((flag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _translateFlag(flag),
                  style: TextStyle(color: color, fontSize: 10),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _translateFlag(String flag) {
    final translations = {
      'unrealistic_pricing': 'Fiyat sorunu',
      'unrealistic pricing': 'Fiyat sorunu',
      'missing_critical_information': 'Eksik bilgi',
      'missing critical information': 'Eksik bilgi',
      'incomplete': 'Eksik',
      'vague': 'Belirsiz',
      'spam': 'Spam',
      'misleading': 'Yanıltıcı',
      'blacklist_violation': 'Yasaklı kelime',
    };
    return translations[flag.toLowerCase()] ?? flag.replaceAll('_', ' ');
  }

  Future<void> _showModerationDetails(JobListingData job, bool isDark) async {
    // Önce cache'e bak
    var info = _moderationCache[job.id];

    // Cache'de yoksa Supabase'den çek
    if (info == null) {
      try {
        final result = await JobsService.instance.getModerationResult(job.id);
        if (result != null) {
          info = ModerationInfo(
            status: ModerationStatus.fromString(result.result),
            score: result.score,
            reason: result.reason,
            flags: result.flags,
          );
          // Cache'e kaydet
          _moderationCache[job.id] = info;
        }
      } catch (e) {
        debugPrint('Moderation details error: $e');
      }
    }

    if (!mounted) return;

    if (info == null) {
      AppDialogs.showWarning(context, 'Moderasyon bilgisi yüklenemedi');
      return;
    }

    showModerationFeedbackDialog(
      context,
      info: info,
      onEditPressed: () => _editListing(job),
    );
  }

  void _navigateToDetail(JobListingData job) {
    // TODO: JobDetailScreen needs to be updated to accept JobListingData
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${job.title} detayları açılıyor...'),
        backgroundColor: JobsColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToAddListing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddJobListingScreen(),
      ),
    );
  }

  void _editListing(JobListingData job) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddJobListingScreen(editingListing: job),
      ),
    ).then((_) {
      // Sayfa kapandığında listeyi yenile
      _loadUserListings();
    });
  }

  void _closeListing(JobListingData job, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: JobsColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: JobsColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pause_circle,
                color: JobsColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'İlanı Kapat',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '"${job.title}" ilanını kapatmak istediğinize emin misiniz?\n\nBu işlem ilanı "Kapatıldı" sekmesine taşıyacaktır.',
          style: TextStyle(color: JobsColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(color: JobsColors.textSecondary(isDark)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _activeListings.removeAt(index);
                _closedListings.insert(0, job);
              });
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(child: Text('İlan kapatıldı')),
                    ],
                  ),
                  backgroundColor: JobsColors.warning,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  action: SnackBarAction(
                    label: 'Geri Al',
                    textColor: Colors.white,
                    onPressed: () {
                      setState(() {
                        _closedListings.remove(job);
                        _activeListings.insert(
                            index.clamp(0, _activeListings.length), job);
                      });
                    },
                  ),
                ),
              );
              _tabController.animateTo(2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: JobsColors.warning,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.pause, color: Colors.white, size: 18),
            label: const Text('Kapat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _reopenListing(JobListingData job, int index) {
    setState(() {
      _closedListings.removeAt(index);
      _pendingListings.insert(0, job);
    });
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('İlan yeniden yayına gönderildi')),
          ],
        ),
        backgroundColor: JobsColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    _tabController.animateTo(1);
  }

  Future<bool> _showDeleteConfirmationDialog(JobListingData job, bool isDark) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: JobsColors.card(isDark),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: JobsColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: JobsColors.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'İlanı Sil',
                    style: TextStyle(
                      color: JobsColors.textPrimary(isDark),
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              '"${job.title}" ilanını silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz!',
              style: TextStyle(color: JobsColors.textSecondary(isDark)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'İptal',
                  style: TextStyle(color: JobsColors.textSecondary(isDark)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JobsColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                label: const Text('Sil', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _deleteListing(JobListingData job, String type, int index) {
    HapticFeedback.mediumImpact();

    late List<JobListingData> targetList;
    switch (type) {
      case 'active':
        targetList = _activeListings;
        break;
      case 'pending':
        targetList = _pendingListings;
        break;
      case 'closed':
        targetList = _closedListings;
        break;
    }

    setState(() {
      targetList.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('İlan silindi')),
          ],
        ),
        backgroundColor: JobsColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Geri Al',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              targetList.insert(index.clamp(0, targetList.length), job);
            });
          },
        ),
      ),
    );
  }

  void _showListingOptions(
      JobListingData job, bool isDark, String type, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: JobsColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: JobsColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: JobsColors.primary),
              ),
              title: Text(
                'İlanı Düzenle',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Bilgileri güncelle',
                style: TextStyle(color: JobsColors.textTertiary(isDark)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _editListing(job);
              },
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: JobsColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.people, color: JobsColors.secondary),
              ),
              title: Text(
                'Başvuruları Gör',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${job.applicationCount} başvuru',
                style: TextStyle(color: JobsColors.textTertiary(isDark)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Başvurular ekranı açılıyor...'),
                    backgroundColor: JobsColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: JobsColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share, color: JobsColors.primary),
              ),
              title: Text(
                'İlanı Paylaş',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Sosyal medyada paylaş',
                style: TextStyle(color: JobsColors.textTertiary(isDark)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Paylaşım linki kopyalandı'),
                    backgroundColor: JobsColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: JobsColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: JobsColors.error),
              ),
              title: const Text(
                'İlanı Sil',
                style: TextStyle(
                  color: JobsColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Kalıcı olarak kaldır',
                style: TextStyle(color: JobsColors.textTertiary(isDark)),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                final confirmed =
                    await _showDeleteConfirmationDialog(job, isDark);
                if (confirmed) {
                  _deleteListing(job, type, index);
                }
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: JobsColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.analytics, color: JobsColors.primary),
              title: Text(
                'İstatistikler',
                style: TextStyle(color: JobsColors.textPrimary(isDark)),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: JobsColors.primary),
              title: Text(
                'Ayarlar',
                style: TextStyle(color: JobsColors.textPrimary(isDark)),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.help, color: JobsColors.primary),
              title: Text(
                'Yardım',
                style: TextStyle(color: JobsColors.textPrimary(isDark)),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
