import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/jobs_management_providers.dart';

class AdminJobApplicantsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminJobApplicantsScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminJobApplicantsScreen> createState() =>
      _AdminJobApplicantsScreenState();
}

class _AdminJobApplicantsScreenState
    extends ConsumerState<AdminJobApplicantsScreen>
    with SingleTickerProviderStateMixin {
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');
  final _timeFormat = DateFormat('HH:mm', 'tr');
  late TabController _tabController;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  static const _tabs = [
    (label: 'Tümü', value: 'all'),
    (label: 'Bekleyen', value: 'pending'),
    (label: 'İnceleniyor', value: 'reviewing'),
    (label: 'Kabul', value: 'accepted'),
    (label: 'Red', value: 'rejected'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentStatus => _tabs[_tabController.index].value;

  String _timeAgo(String? dateStr) {
    if (dateStr == null) {
      return '-';
    }
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 30) {
      return _dateFormat.format(date);
    } else if (diff.inDays > 0) {
      return '${diff.inDays} gün önce';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} saat önce';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  Map<String, int> _computeTabCounts(List<Map<String, dynamic>> all) {
    final counts = <String, int>{
      'all': all.length,
      'pending': 0,
      'reviewing': 0,
      'accepted': 0,
      'rejected': 0,
    };
    for (final app in all) {
      final status = app['status'] as String? ?? '';
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final applicantsAsync = ref.watch(
      jobApplicantsProvider(
          (companyId: widget.companyId, jobId: null, status: _currentStatus)),
    );
    final allApplicantsAsync = ref.watch(
      jobApplicantsProvider(
          (companyId: widget.companyId, jobId: null, status: 'all')),
    );

    final tabCounts =
        allApplicantsAsync.whenOrNull(data: _computeTabCounts) ??
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
                    Text('Başvurular',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('İlanlara yapılan başvuruları yönetin.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    if (_isSelectionMode && _selectedIds.isNotEmpty) ...[
                      Text('${_selectedIds.length} seçili',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(width: 12),
                      _buildBulkActionButton(
                        'İnceleniyor',
                        AppColors.info,
                        () => _bulkUpdateStatus('reviewing'),
                      ),
                      const SizedBox(width: 8),
                      _buildBulkActionButton(
                        'Kabul Et',
                        AppColors.success,
                        () => _bulkUpdateStatus('accepted'),
                      ),
                      const SizedBox(width: 8),
                      _buildBulkActionButton(
                        'Reddet',
                        AppColors.error,
                        () => _bulkUpdateStatus('rejected'),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          setState(() {
                            _selectedIds.clear();
                            _isSelectionMode = false;
                          });
                        },
                        tooltip: 'Seçimi İptal',
                      ),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = !_isSelectionMode;
                            _selectedIds.clear();
                          });
                        },
                        icon: Icon(
                          _isSelectionMode
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        label: const Text('Toplu İşlem',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          color: AppColors.textSecondary),
                      onPressed: () =>
                          ref.invalidate(jobApplicantsProvider),
                      tooltip: 'Yenile',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pipeline tabs with counts
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
                  final countStr = count != null ? ' ($count)' : '';
                  return Tab(text: '${t.label}$countStr');
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Applicant cards
            Expanded(
              child: applicantsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
                error: (_, _) => const Center(
                    child: Text('Veriler yüklenirken hata oluştu.',
                        style: TextStyle(color: AppColors.textSecondary))),
                data: (applicants) {
                  if (applicants.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 64, color: AppColors.textSecondary),
                          SizedBox(height: 16),
                          Text('Başvuru bulunamadı.',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: applicants.length,
                    itemBuilder: (context, index) {
                      return _buildApplicantCard(applicants[index]);
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

  Widget _buildBulkActionButton(
      String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> app) {
    final id = app['id'] as String? ?? '';
    final job = app['job_listings'] as Map<String, dynamic>?;
    final status = app['status'] ?? 'pending';
    final applicantName = app['applicant_name'] ?? 'İsimsiz';
    final applicantEmail = app['applicant_email'] ?? '-';
    final applicantPhone = app['applicant_phone'] ?? '';
    final coverLetter = app['cover_letter'] ?? '';
    final resumeUrl = app['resume_url'] ?? '';
    final createdAt = app['applied_at'] ?? app['created_at'];
    final isSelected = _selectedIds.contains(id);

    // Generate initials
    final nameParts = applicantName.split(' ');
    final initials = nameParts.length >= 2
        ? '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase()
        : applicantName.isNotEmpty
            ? applicantName[0].toUpperCase()
            : '?';

    final timeAgoStr = _timeAgo(createdAt as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(id);
              } else {
                _selectedIds.add(id);
              }
            });
          } else {
            _showApplicantDetailDialog(app);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection checkbox
              if (_isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedIds.add(id);
                      } else {
                        _selectedIds.remove(id);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                  checkColor: Colors.white,
                  side: const BorderSide(color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
              ],

              // Avatar with initials
              CircleAvatar(
                radius: 26,
                backgroundColor: _avatarColor(applicantName),
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(applicantName,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Job title
                    Row(
                      children: [
                        const Icon(Icons.work_outline,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(job?['title'] ?? '-',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Contact info row
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _infoChip(Icons.email_outlined, applicantEmail),
                        if (applicantPhone.isNotEmpty) ...[
                          _infoChip(Icons.phone_outlined, applicantPhone),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Date + tags
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(timeAgoStr,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(width: 12),
                        if (resumeUrl.isNotEmpty) ...[
                          _tagBadge('CV Mevcut', AppColors.info),
                          const SizedBox(width: 6),
                        ],
                        if (coverLetter.isNotEmpty) ...[
                          _tagBadge('Ön Yazı', AppColors.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Actions
              if (!_isSelectionMode &&
                  (status == 'pending' || status == 'reviewing')) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton(
                      Icons.check_circle,
                      AppColors.success,
                      'Kabul Et',
                      () => _showNoteDialog(id, 'accepted'),
                    ),
                    const SizedBox(height: 4),
                    _actionButton(
                      Icons.cancel,
                      AppColors.error,
                      'Reddet',
                      () => _showNoteDialog(id, 'rejected'),
                    ),
                    if (status == 'pending') ...[
                      const SizedBox(height: 4),
                      _actionButton(
                        Icons.rate_review_outlined,
                        AppColors.info,
                        'İncelemeye Al',
                        () => _updateApplicationStatus(id, 'reviewing'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
      IconData icon, Color color, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _tagBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.info,
      AppColors.warning,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        label = 'Bekleyen';
      case 'reviewing':
        bgColor = AppColors.info.withValues(alpha: 0.15);
        textColor = AppColors.info;
        label = 'İnceleniyor';
      case 'accepted':
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        label = 'Kabul Edildi';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  void _showApplicantDetailDialog(Map<String, dynamic> app) {
    final applicantName = app['applicant_name'] ?? 'İsimsiz';
    final applicantEmail = app['applicant_email'] ?? '-';
    final applicantPhone = app['applicant_phone'] ?? '-';
    final coverLetter = app['cover_letter'] ?? '';
    final resumeUrl = app['resume_url'] ?? '';
    final notes = app['notes'] ?? '';
    final status = app['status'] ?? 'pending';
    final job = app['job_listings'] as Map<String, dynamic>?;
    final createdAt = app['applied_at'] ?? app['created_at'];
    final dateStr = createdAt != null
        ? _dateFormat.format(DateTime.parse(createdAt).toLocal())
        : '-';
    final timeStr = createdAt != null
        ? _timeFormat.format(DateTime.parse(createdAt).toLocal())
        : '';
    final timeAgoStr = _timeAgo(createdAt as String?);

    final nameParts = applicantName.split(' ');
    final initials = nameParts.length >= 2
        ? '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase()
        : applicantName.isNotEmpty
            ? applicantName[0].toUpperCase()
            : '?';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with avatar
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: _avatarColor(applicantName),
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 18)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(applicantName,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildStatusChip(status),
                                const SizedBox(width: 10),
                                Icon(Icons.access_time,
                                    size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(timeAgoStr,
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.surfaceLight),
                  const SizedBox(height: 16),

                  // Contact info section
                  const Text('İletişim Bilgileri',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  _detailRow(
                      Icons.email_outlined, 'E-posta', applicantEmail),
                  _detailRow(
                      Icons.phone_outlined, 'Telefon', applicantPhone),
                  _detailRow(Icons.work_outline, 'Başvurulan Pozisyon',
                      job?['title'] ?? '-'),
                  _detailRow(Icons.calendar_today, 'Başvuru Tarihi',
                      '$dateStr $timeStr'),
                  if (resumeUrl.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        const Text('CV/Özgeçmiş: ',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                        Expanded(
                          child: Text(resumeUrl,
                              style: const TextStyle(
                                  color: AppColors.info,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],

                  if (coverLetter.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.surfaceLight),
                    const SizedBox(height: 16),
                    const Text('Ön Yazı',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Text(coverLetter,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5)),
                    ),
                  ],

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.surfaceLight),
                    const SizedBox(height: 16),
                    const Text('Notlar',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Text(notes,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5)),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (status == 'pending' ||
                          status == 'reviewing') ...[
                        if (status == 'pending') ...[
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _updateApplicationStatus(
                                  app['id'], 'reviewing');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('İncelemeye Al'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showNoteDialog(app['id'], 'accepted');
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Kabul Et'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showNoteDialog(app['id'], 'rejected');
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reddet'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Kapat',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showNoteDialog(String applicationId, String newStatus) {
    final noteController = TextEditingController();
    final isAccept = newStatus == 'accepted';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isAccept ? 'Başvuruyu Kabul Et' : 'Başvuruyu Reddet',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAccept
                  ? 'Bir not eklemek ister misiniz? (isteğe bağlı)'
                  : 'Red nedenini belirtiniz.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:
                    isAccept ? 'Not (isteğe bağlı)...' : 'Red nedeni...',
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
              _updateApplicationStatus(
                applicationId,
                newStatus,
                note: noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isAccept ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isAccept ? 'Kabul Et' : 'Reddet'),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkUpdateStatus(String newStatus) async {
    if (_selectedIds.isEmpty) {
      return;
    }
    final count = _selectedIds.length;
    try {
      final client = ref.read(supabaseProvider);
      for (final id in _selectedIds) {
        await client
            .from('job_applications')
            .update({'status': newStatus})
            .eq('id', id);
      }
      ref.invalidate(jobApplicantsProvider);
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$count başvuru güncellendi.'),
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

  Future<void> _updateApplicationStatus(
      String applicationId, String newStatus,
      {String? note}) async {
    try {
      final client = ref.read(supabaseProvider);
      final updateData = <String, dynamic>{'status': newStatus};
      if (note != null) {
        updateData['notes'] = note;
      }
      await client
          .from('job_applications')
          .update(updateData)
          .eq('id', applicationId);
      ref.invalidate(jobApplicantsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Başvuru durumu güncellendi.'),
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
