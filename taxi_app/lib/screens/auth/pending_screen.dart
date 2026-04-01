import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/log_service.dart';
import '../../core/services/taxi_service.dart';
import '../../core/theme/app_theme.dart';

const _requiredDocuments = [
  {
    'type': 'id_card',
    'name': 'Kimlik',
    'description': 'Kimlik karti on ve arka yuzu',
    'icon': Icons.badge_outlined,
  },
  {
    'type': 'license',
    'name': 'Surucu Belgesi (Ehliyet)',
    'description': 'Gecerli surucu belgesi',
    'icon': Icons.card_membership_outlined,
  },
  {
    'type': 'registration',
    'name': 'Arac Ruhsati',
    'description': 'Arac tescil belgesi',
    'icon': Icons.directions_car_outlined,
  },
];

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = false;
  String? _uploadingType;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await TaxiService.getDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _getDocument(String type) {
    try {
      return _documents.firstWhere((d) => d['type'] == type);
    } catch (e, st) {
      LogService.error('getDocument error', error: e, stackTrace: st, source: 'PendingScreen:_getDocument');
      return null;
    }
  }

  Future<void> _uploadDocument(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploadingType = type);

    final success = await TaxiService.uploadDocument(
      type: type,
      bytes: file.bytes!,
      fileName: file.name,
    );

    if (mounted) {
      setState(() => _uploadingType = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Belge yuklendi' : 'Yukleme basarisiz'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Header
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Basvurunuz Inceleniyor',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'Belgelerinizi yukleyin ve onay icin bekleyin.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Status Steps
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildStatusStep(
                      context,
                      icon: Icons.check_circle,
                      title: 'Basvuru Alindi',
                      subtitle: 'Bilgileriniz basariyla kaydedildi',
                      isCompleted: true,
                      isActive: false,
                    ),
                    _buildDivider(),
                    _buildStatusStep(
                      context,
                      icon: Icons.upload_file,
                      title: 'Belge Yukleme',
                      subtitle: _getDocumentProgressText(),
                      isCompleted: _allDocumentsUploaded(),
                      isActive: !_allDocumentsUploaded(),
                    ),
                    _buildDivider(),
                    _buildStatusStep(
                      context,
                      icon: Icons.verified,
                      title: 'Onay',
                      subtitle: 'Hesabiniz aktif edilecek',
                      isCompleted: false,
                      isActive: _allDocumentsUploaded(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Documents Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Zorunlu Belgeler',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      ..._requiredDocuments.map((doc) {
                        final uploaded = _getDocument(doc['type'] as String);
                        return _buildDocumentItem(
                          type: doc['type'] as String,
                          name: doc['name'] as String,
                          description: doc['description'] as String,
                          icon: doc['icon'] as IconData,
                          uploaded: uploaded,
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Refresh Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).refreshProfile();
                    if (!mounted) return;
                    final status = ref.read(authProvider).status;
                    if (status == AuthStatus.authenticated) {
                      context.go('/');
                    } else {
                      _loadDocuments();
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Durumu Kontrol Et'),
                ),
              ),

              const SizedBox(height: 12),

              // Logout Button
              TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                },
                child: Text(
                  'Cikis Yap',
                  style: TextStyle(color: AppColors.error),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentItem({
    required String type,
    required String name,
    required String description,
    required IconData icon,
    Map<String, dynamic>? uploaded,
  }) {
    final status = uploaded?['status'] as String?;
    final isUploading = _uploadingType == type;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (uploaded == null) {
      statusColor = AppColors.textHint;
      statusText = 'Yuklenmedi';
      statusIcon = Icons.cloud_upload_outlined;
    } else if (status == 'approved') {
      statusColor = AppColors.success;
      statusText = 'Onaylandi';
      statusIcon = Icons.check_circle;
    } else if (status == 'rejected') {
      statusColor = AppColors.error;
      statusText = 'Reddedildi';
      statusIcon = Icons.cancel;
    } else {
      statusColor = AppColors.warning;
      statusText = 'Inceleniyor';
      statusIcon = Icons.hourglass_top;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'rejected' ? AppColors.error.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Rejection reason
          if (status == 'rejected' && uploaded?['rejection_reason'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      uploaded!['rejection_reason'] as String,
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              // View button (if uploaded)
              if (uploaded != null && uploaded['url'] != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final url = uploaded['url'] as String;
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Goruntule', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),

              if (uploaded != null && uploaded['url'] != null)
                const SizedBox(width: 8),

              // Upload/Re-upload button
              if (status != 'approved')
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isUploading ? null : () => _uploadDocument(type),
                    icon: isUploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            uploaded == null ? Icons.cloud_upload_outlined : Icons.refresh,
                            size: 16,
                          ),
                    label: Text(
                      isUploading
                          ? 'Yukleniyor...'
                          : uploaded == null
                              ? 'Yukle'
                              : 'Tekrar Yukle',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _allDocumentsUploaded() {
    return _requiredDocuments.every((doc) {
      final uploaded = _getDocument(doc['type'] as String);
      return uploaded != null;
    });
  }

  String _getDocumentProgressText() {
    final uploaded = _requiredDocuments.where((doc) {
      return _getDocument(doc['type'] as String) != null;
    }).length;
    return '$uploaded/${_requiredDocuments.length} belge yuklendi';
  }

  Widget _buildStatusStep(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
  }) {
    Color iconColor;
    Color bgColor;

    if (isCompleted) {
      iconColor = AppColors.success;
      bgColor = AppColors.success.withValues(alpha: 0.1);
    } else if (isActive) {
      iconColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.1);
    } else {
      iconColor = AppColors.textHint;
      bgColor = AppColors.divider;
    }

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCompleted || isActive ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 21),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: 2,
        height: 24,
        color: AppColors.border,
      ),
    );
  }
}
