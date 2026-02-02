import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Emlakçı Başvuru Modeli
class RealtorApplication {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String email;
  final String? companyName;
  final String? licenseNumber;
  final String? taxNumber;
  final int experienceYears;
  final List<String> specialization;
  final List<String> workingCities;
  final String status;
  final String? rejectionReason;
  final String? adminNotes;
  final String? applicantMessage;
  final DateTime createdAt;

  RealtorApplication({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.email,
    this.companyName,
    this.licenseNumber,
    this.taxNumber,
    this.experienceYears = 0,
    this.specialization = const [],
    this.workingCities = const [],
    required this.status,
    this.rejectionReason,
    this.adminNotes,
    this.applicantMessage,
    required this.createdAt,
  });

  factory RealtorApplication.fromJson(Map<String, dynamic> json) {
    return RealtorApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      companyName: json['company_name'] as String?,
      licenseNumber: json['license_number'] as String?,
      taxNumber: json['tax_number'] as String?,
      experienceYears: json['experience_years'] as int? ?? 0,
      specialization: (json['specialization'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      workingCities: (json['working_cities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      adminNotes: json['admin_notes'] as String?,
      applicantMessage: json['applicant_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Başvuru Servisi
class RealtorApplicationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<RealtorApplication>> getApplications({String? status}) async {
    var query = _client.from('realtor_applications').select();

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((json) => RealtorApplication.fromJson(json))
        .toList();
  }

  Future<void> approveApplication(String applicationId, String userId) async {
    final adminId = _client.auth.currentUser?.id;

    // Başvuruyu onayla
    await _client.from('realtor_applications').update({
      'status': 'approved',
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', applicationId);

    // Başvuru bilgilerini al
    final application = await _client
        .from('realtor_applications')
        .select()
        .eq('id', applicationId)
        .single();

    // Emlakçı profili oluştur
    await _client.from('realtors').insert({
      'user_id': userId,
      'company_name': application['company_name'],
      'license_number': application['license_number'],
      'tax_number': application['tax_number'],
      'phone': application['phone'],
      'email': application['email'],
      'status': 'approved',
      'approved_at': DateTime.now().toIso8601String(),
      'approved_by': adminId,
    });
  }

  Future<void> rejectApplication(
      String applicationId, String rejectionReason) async {
    final adminId = _client.auth.currentUser?.id;

    await _client.from('realtor_applications').update({
      'status': 'rejected',
      'rejection_reason': rejectionReason,
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', applicationId);
  }

  Future<void> updateAdminNotes(String applicationId, String notes) async {
    await _client.from('realtor_applications').update({
      'admin_notes': notes,
    }).eq('id', applicationId);
  }

  Future<int> getPendingCount() async {
    final response = await _client
        .from('realtor_applications')
        .select('id')
        .eq('status', 'pending')
        .count();
    return response.count;
  }
}

/// Provider
final realtorApplicationServiceProvider =
    Provider<RealtorApplicationService>((ref) {
  return RealtorApplicationService();
});

final realtorApplicationsProvider =
    FutureProvider.family<List<RealtorApplication>, String?>((ref, status) async {
  final service = ref.watch(realtorApplicationServiceProvider);
  return service.getApplications(status: status);
});

final pendingApplicationsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(realtorApplicationServiceProvider);
  return service.getPendingCount();
});

/// Emlakçı Başvuruları Ekranı
class EmlakRealtorApplicationsScreen extends ConsumerStatefulWidget {
  const EmlakRealtorApplicationsScreen({super.key});

  @override
  ConsumerState<EmlakRealtorApplicationsScreen> createState() =>
      _EmlakRealtorApplicationsScreenState();
}

class _EmlakRealtorApplicationsScreenState
    extends ConsumerState<EmlakRealtorApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = RealtorApplicationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Emlakçı Başvuruları',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF10B981),
          tabs: [
            _buildTabWithBadge('Bekleyen', 'pending'),
            const Tab(text: 'İnceleme'),
            const Tab(text: 'Onaylanan'),
            const Tab(text: 'Reddedilen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplicationsList('pending'),
          _buildApplicationsList('under_review'),
          _buildApplicationsList('approved'),
          _buildApplicationsList('rejected'),
        ],
      ),
    );
  }

  Widget _buildTabWithBadge(String label, String status) {
    final countAsync = ref.watch(pendingApplicationsCountProvider);

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          countAsync.when(
            data: (count) => count > 0
                ? Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList(String status) {
    final applicationsAsync = ref.watch(realtorApplicationsProvider(status));

    return applicationsAsync.when(
      data: (applications) {
        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Başvuru bulunamadı',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(realtorApplicationsProvider(status));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              return _buildApplicationCard(applications[index]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Hata: $error'),
      ),
    );
  }

  Widget _buildApplicationCard(RealtorApplication application) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                  child: Text(
                    application.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        application.email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(application.status),
              ],
            ),
            const Divider(height: 24),

            // Details
            _buildDetailRow(Icons.phone, application.phone),
            if (application.companyName != null)
              _buildDetailRow(Icons.business, application.companyName!),
            if (application.licenseNumber != null)
              _buildDetailRow(Icons.badge, 'Lisans: ${application.licenseNumber}'),
            _buildDetailRow(
                Icons.work_history, '${application.experienceYears} yıl deneyim'),

            // Specializations
            if (application.specialization.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: application.specialization
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.grey[100],
                        ))
                    .toList(),
              ),
            ],

            // Cities
            if (application.workingCities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      application.workingCities.join(', '),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Applicant Message
            if (application.applicantMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Başvuru Notu:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.applicantMessage!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Admin Notes
            if (application.adminNotes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Notu:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.adminNotes!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            // Rejection Reason
            if (application.status == 'rejected' &&
                application.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Red Sebebi:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.rejectionReason!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Başvuru: ${DateFormat('dd.MM.yyyy HH:mm').format(application.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Actions
            if (application.status == 'pending' ||
                application.status == 'under_review') ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(application),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reddet'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(application),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Onayla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = Colors.amber[100]!;
        textColor = Colors.amber[800]!;
        label = 'Bekliyor';
        break;
      case 'under_review':
        bgColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        label = 'İnceleniyor';
        break;
      case 'approved':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        label = 'Onaylandı';
        break;
      case 'rejected':
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        label = 'Reddedildi';
        break;
      default:
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showApproveDialog(RealtorApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Başvuruyu Onayla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${application.fullName} adlı kullanıcının emlakçı başvurusunu onaylamak istediğinize emin misiniz?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Onaylandığında kullanıcı emlakçı paneline erişebilecek.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _approveApplication(application);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(RealtorApplication application) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Başvuruyu Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${application.fullName} adlı kullanıcının emlakçı başvurusunu reddetmek istediğinize emin misiniz?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Red Sebebi',
                hintText: 'Başvurunun neden reddedildiğini açıklayın...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen red sebebi girin')),
                );
                return;
              }
              Navigator.pop(context);
              await _rejectApplication(application, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveApplication(RealtorApplication application) async {
    try {
      await _service.approveApplication(application.id, application.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başvuru onaylandı'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        ref.invalidate(realtorApplicationsProvider('pending'));
        ref.invalidate(realtorApplicationsProvider('approved'));
        ref.invalidate(pendingApplicationsCountProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectApplication(
      RealtorApplication application, String reason) async {
    try {
      await _service.rejectApplication(application.id, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başvuru reddedildi'),
            backgroundColor: Colors.orange,
          ),
        );
        ref.invalidate(realtorApplicationsProvider('pending'));
        ref.invalidate(realtorApplicationsProvider('rejected'));
        ref.invalidate(pendingApplicationsCountProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
