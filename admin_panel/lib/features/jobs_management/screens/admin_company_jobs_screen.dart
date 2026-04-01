import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/jobs_management_providers.dart';

class AdminCompanyJobsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminCompanyJobsScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminCompanyJobsScreen> createState() =>
      _AdminCompanyJobsScreenState();
}

class _AdminCompanyJobsScreenState
    extends ConsumerState<AdminCompanyJobsScreen>
    with SingleTickerProviderStateMixin {
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');
  final _currencyFormat =
      NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 0);
  final _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';

  static const _tabs = [
    (label: 'Tümü', value: 'all'),
    (label: 'Aktif', value: 'active'),
    (label: 'Beklemede', value: 'pending'),
    (label: 'Pasif', value: 'inactive'),
    (label: 'Süresi Dolmuş', value: 'expired'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentStatus => _tabs[_tabController.index].value;

  List<Map<String, dynamic>> _filterJobs(List<Map<String, dynamic>> jobs) {
    if (_searchQuery.isEmpty) {
      return jobs;
    }
    return jobs.where((j) {
      final title = (j['title'] ?? '').toString().toLowerCase();
      final loc = (j['city'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery) || loc.contains(_searchQuery);
    }).toList();
  }

  Map<String, int> _computeTabCounts(List<Map<String, dynamic>> allJobs) {
    final counts = <String, int>{
      'all': allJobs.length,
      'active': 0,
      'pending': 0,
      'inactive': 0,
      'expired': 0,
    };
    for (final job in allJobs) {
      final status = job['status'] as String? ?? '';
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(
      companyJobsProvider(
          (companyId: widget.companyId, status: _currentStatus)),
    );
    final allJobsAsync = ref.watch(
      companyJobsProvider(
          (companyId: widget.companyId, status: 'all')),
    );

    final tabCounts = allJobsAsync.whenOrNull(data: _computeTabCounts) ??
        <String, int>{};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('İlanlar',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Şirketin iş ilanlarını görüntüleyin ve yönetin.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                  onPressed: () => ref.invalidate(companyJobsProvider),
                  tooltip: 'Yenile',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Başlık veya lokasyon ile arayın...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
            const SizedBox(height: 20),

            // Status tabs with counts
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: _tabs.map((t) {
                  final count = tabCounts[t.value];
                  final countStr =
                      count != null ? ' ($count)' : '';
                  return Tab(text: '${t.label}$countStr');
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Job cards grid
            Expanded(
              child: jobsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
                error: (_, _) => const Center(
                    child: Text('Veriler yüklenirken hata oluştu.',
                        style: TextStyle(color: AppColors.textSecondary))),
                data: (jobs) {
                  final filtered = _filterJobs(jobs);

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_off_outlined,
                              size: 64, color: AppColors.textSecondary),
                          SizedBox(height: 16),
                          Text('İlan bulunamadı.',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 1200
                          ? 3
                          : constraints.maxWidth > 800
                              ? 2
                              : 1;
                      return GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.45,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildJobCard(filtered[index]);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final title = job['title'] ?? '-';
    final category = job['job_categories']?['name'] ?? '-';
    final location = [job['city'], job['district']].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    final salaryMin = (job['salary_min'] as num?)?.toDouble();
    final salaryMax = (job['salary_max'] as num?)?.toDouble();
    final salary = salaryMin != null && salaryMax != null
        ? '${_currencyFormat.format(salaryMin)} - ${_currencyFormat.format(salaryMax)}'
        : salaryMin != null
            ? '${_currencyFormat.format(salaryMin)}+'
            : 'Belirtilmemiş';
    final createdAt = job['created_at'] != null
        ? _dateFormat.format(DateTime.parse(job['created_at']).toLocal())
        : '-';
    final status = job['status'] ?? 'unknown';
    final employmentType = job['job_type'] ?? '';
    final experienceLevel = job['experience_level'] ?? '';
    final applicationCount = job['application_count'] ?? 0;

    return InkWell(
      onTap: () => _showJobDetailDialog(job),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: title + status
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 10),

            // Category badge + employment type + experience
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildBadge(category, AppColors.info),
                if (employmentType.isNotEmpty) ...[
                  _buildBadge(
                      _employmentTypeLabel(employmentType), AppColors.primary),
                ],
                if (experienceLevel.isNotEmpty) ...[
                  _buildBadge(experienceLevel, AppColors.warning),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Salary
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(salary,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const Spacer(),

            // Bottom row: date, applications, actions
            const Divider(color: AppColors.surfaceLight, height: 20),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(createdAt,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: applicationCount > 0
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 13,
                          color: applicationCount > 0
                              ? AppColors.primary
                              : AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('$applicationCount başvuru',
                          style: TextStyle(
                              color: applicationCount > 0
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                if (status == 'pending') ...[
                  _buildSmallActionButton(
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    tooltip: 'Onayla',
                    onPressed: () => _approveRejectDialog(job['id'], true),
                  ),
                  const SizedBox(width: 4),
                  _buildSmallActionButton(
                    icon: Icons.cancel,
                    color: AppColors.error,
                    tooltip: 'Reddet',
                    onPressed: () => _approveRejectDialog(job['id'], false),
                  ),
                ] else if (status == 'active' || status == 'inactive') ...[
                  _buildSmallActionButton(
                    icon: status == 'active'
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color:
                        status == 'active' ? AppColors.warning : AppColors.success,
                    tooltip: status == 'active' ? 'Pasife Al' : 'Aktif Et',
                    onPressed: () => _updateJobStatus(
                      job['id'],
                      status == 'active' ? 'inactive' : 'active',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        label = 'Aktif';
      case 'inactive':
        bgColor = AppColors.textMuted.withValues(alpha: 0.2);
        textColor = AppColors.textMuted;
        label = 'Pasif';
      case 'pending':
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        label = 'Beklemede';
      case 'expired':
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        label = 'Süresi Dolmuş';
      case 'filled':
        bgColor = AppColors.info.withValues(alpha: 0.15);
        textColor = AppColors.info;
        label = 'Dolduruldu';
      case 'rejected':
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        label = 'Reddedildi';
      default:
        bgColor = AppColors.textMuted.withValues(alpha: 0.2);
        textColor = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }

  String _employmentTypeLabel(String type) {
    switch (type) {
      case 'full_time':
        return 'Tam Zamanlı';
      case 'part_time':
        return 'Yarı Zamanlı';
      case 'contract':
        return 'Sözleşmeli';
      case 'internship':
        return 'Staj';
      default:
        return type;
    }
  }

  void _showJobDetailDialog(Map<String, dynamic> job) {
    final title = job['title'] ?? '-';
    final description = job['description'] ?? 'Açıklama yok.';
    final requirements = job['qualifications'];
    final benefits = job['manual_benefits'];
    final category = job['job_categories']?['name'] ?? '-';
    final locationParts = [job['city'], job['district']].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    final location = locationParts.isNotEmpty ? locationParts : '-';
    final salaryMin = (job['salary_min'] as num?)?.toDouble();
    final salaryMax = (job['salary_max'] as num?)?.toDouble();
    final salary = salaryMin != null && salaryMax != null
        ? '${_currencyFormat.format(salaryMin)} - ${_currencyFormat.format(salaryMax)}'
        : salaryMin != null
            ? '${_currencyFormat.format(salaryMin)}+'
            : 'Belirtilmemiş';
    final employmentType = job['job_type'] ?? '-';
    final experienceLevel = job['experience_level'] ?? '-';
    final status = job['status'] ?? 'unknown';
    final applicationCount = job['application_count'] ?? 0;
    final viewCount = job['view_count'] ?? 0;
    final createdAt = job['created_at'] != null
        ? _dateFormat.format(DateTime.parse(job['created_at']).toLocal())
        : '-';
    final expiresAt = job['expires_at'] != null
        ? _dateFormat.format(DateTime.parse(job['expires_at']).toLocal())
        : '-';

    List<String> requirementsList = [];
    if (requirements is List) {
      requirementsList = requirements.map((e) => e.toString()).toList();
    } else if (requirements is String && requirements.isNotEmpty) {
      requirementsList =
          requirements.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }

    List<String> benefitsList = [];
    if (benefits is List) {
      benefitsList = benefits.map((e) => e.toString()).toList();
    } else if (benefits is String && benefits.isNotEmpty) {
      benefitsList =
          benefits.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Employment type + experience chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildBadge(category, AppColors.info),
                      _buildBadge(
                          _employmentTypeLabel(employmentType), AppColors.primary),
                      if (experienceLevel != '-') ...[
                        _buildBadge(experienceLevel, AppColors.warning),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Row(
                      children: [
                        _statItem(Icons.people_outline, '$applicationCount',
                            'Başvuru'),
                        _verticalDivider(),
                        _statItem(Icons.visibility_outlined, '$viewCount',
                            'Görüntülenme'),
                        _verticalDivider(),
                        _statItem(
                            Icons.calendar_today, createdAt, 'Yayın Tarihi'),
                        _verticalDivider(),
                        _statItem(Icons.event_busy, expiresAt, 'Son Tarih'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info grid
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _detailItem(
                          Icons.location_on_outlined, 'Lokasyon', location),
                      _detailItem(Icons.payments_outlined, 'Maaş Aralığı', salary),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.surfaceLight),
                  const SizedBox(height: 16),

                  // Description
                  const Text('Açıklama',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(description,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5)),

                  if (requirementsList.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Gereksinimler',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    ...requirementsList.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('  \u2022  ',
                                  style: TextStyle(
                                      color: AppColors.primary, fontSize: 13)),
                              Expanded(
                                child: Text(r.trim(),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        )),
                  ],

                  if (benefitsList.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Yan Haklar',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    ...benefitsList.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('  \u2022  ',
                                  style: TextStyle(
                                      color: AppColors.success, fontSize: 13)),
                              Expanded(
                                child: Text(b.trim(),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        )),
                  ],

                  const SizedBox(height: 24),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (status == 'pending') ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _approveRejectDialog(job['id'], true);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Onayla'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _approveRejectDialog(job['id'], false);
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reddet'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (status == 'active' || status == 'inactive') ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _updateJobStatus(
                              job['id'],
                              status == 'active' ? 'inactive' : 'active',
                            );
                          },
                          icon: Icon(
                            status == 'active'
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 18,
                          ),
                          label: Text(
                              status == 'active' ? 'Pasife Al' : 'Aktif Et'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status == 'active'
                                ? AppColors.warning
                                : AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Kapat',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.surfaceLight,
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  void _approveRejectDialog(String jobId, bool isApprove) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isApprove ? 'İlanı Onayla' : 'İlanı Reddet',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isApprove
                  ? 'Bu ilanı onaylamak istediğinize emin misiniz?'
                  : 'Reddetme nedenini belirtiniz.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (!isApprove) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Red nedeni...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.surfaceLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateJobStatus(
                jobId,
                isApprove ? 'active' : 'rejected',
                reason: reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isApprove ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isApprove ? 'Onayla' : 'Reddet'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateJobStatus(String jobId, String newStatus,
      {String? reason}) async {
    try {
      final client = ref.read(supabaseProvider);
      final updateData = <String, dynamic>{'status': newStatus};
      await client
          .from('job_listings')
          .update(updateData)
          .eq('id', jobId);
      ref.invalidate(companyJobsProvider);
      if (mounted) {
        final statusLabel = {
          'active': 'Aktif',
          'inactive': 'Pasif',
          'rejected': 'Reddedildi',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'İlan durumu güncellendi: ${statusLabel[newStatus] ?? newStatus}'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }
}
