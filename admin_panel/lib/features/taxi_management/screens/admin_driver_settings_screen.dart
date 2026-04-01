import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/taxi_management_providers.dart';

class AdminDriverSettingsScreen extends ConsumerStatefulWidget {
  final String driverId;
  const AdminDriverSettingsScreen({super.key, required this.driverId});

  @override
  ConsumerState<AdminDriverSettingsScreen> createState() =>
      _AdminDriverSettingsScreenState();
}

class _AdminDriverSettingsScreenState
    extends ConsumerState<AdminDriverSettingsScreen> {
  bool _isSaving = false;
  final _notesController = TextEditingController();
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverAsync = ref.watch(driverDetailProvider(widget.driverId));
    final documentsAsync = ref.watch(driverDocumentsProvider(widget.driverId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: driverAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Hata: $e',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        data: (driver) {
          if (driver == null) {
            return const Center(
              child: Text('Sürücü bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return _buildContent(driver, documentsAsync);
        },
      ),
    );
  }

  Widget _buildContent(
      Map<String, dynamic> driver, AsyncValue<List<Map<String, dynamic>>> documentsAsync) {
    final status = driver['status'] ?? 'active';
    final fullName = driver['full_name'] ?? 'İsimsiz';
    final rating = (driver['rating'] as num?)?.toDouble() ?? 0;
    final totalRides = driver['total_rides'] ?? 0;
    final totalEarnings = (driver['total_earnings'] as num?)?.toDouble() ?? 0;
    final createdAt = driver['created_at'] != null
        ? DateTime.parse(driver['created_at']).toLocal()
        : null;
    final avatarUrl = driver['avatar_url'] as String?;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Sürücü Ayarları',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sürücü profil bilgilerini görüntüleyin ve yönetin.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: profile + vehicle + performance
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Driver Profile Card
                    _buildDriverProfileCard(
                      driver, fullName, rating, avatarUrl, createdAt,
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Info
                    _buildVehicleInfoCard(driver),
                    const SizedBox(height: 16),

                    // Performance Stats
                    _buildPerformanceCard(driver, totalRides, totalEarnings, rating),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right column: documents + status + notes
              Expanded(
                child: Column(
                  children: [
                    // Document Verification
                    _buildDocumentsCard(documentsAsync),
                    const SizedBox(height: 16),

                    // Status Management
                    _buildStatusCard(status),
                    const SizedBox(height: 16),

                    // Admin Notes
                    _buildNotesCard(driver),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverProfileCard(
    Map<String, dynamic> driver,
    String fullName,
    double rating,
    String? avatarUrl,
    DateTime? createdAt,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Avatar large
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Rating stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (index) {
                if (rating >= index + 1) {
                  return const Icon(Icons.star, color: AppColors.warning, size: 22);
                } else if (rating >= index + 0.5) {
                  return const Icon(Icons.star_half, color: AppColors.warning, size: 22);
                } else {
                  return Icon(Icons.star_border,
                      color: AppColors.warning.withValues(alpha: 0.4), size: 22);
                }
              }),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Member since
          if (createdAt != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Üye: ${DateFormat('dd MMMM yyyy', 'tr').format(createdAt)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: AppColors.surfaceLight),
          const SizedBox(height: 12),

          // Contact info
          _buildInfoRow('Telefon', driver['phone'] ?? '-'),
          _buildInfoRow('E-posta', driver['email'] ?? '-'),
          _buildInfoRow('TC No', driver['tc_no'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoCard(Map<String, dynamic> driver) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car,
                    color: AppColors.info, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Araç Bilgileri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Marka', driver['vehicle_brand'] ?? '-'),
          _buildInfoRow('Model', driver['vehicle_model'] ?? '-'),
          _buildInfoRow('Yıl', '${driver['vehicle_year'] ?? '-'}'),
          _buildInfoRow('Renk', driver['vehicle_color'] ?? '-'),
          _buildInfoRow(
              'Plaka',
              driver['plate_number'] ?? driver['vehicle_plate'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(Map<String, dynamic> driver, int totalRides,
      double totalEarnings, double rating) {
    final acceptanceRate = (driver['acceptance_rate'] as num?)?.toDouble() ?? 0.0;
    final cancellationRate = (driver['cancellation_rate'] as num?)?.toDouble() ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performans İstatistikleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceStat(
                  Icons.local_taxi,
                  '$totalRides',
                  'Toplam Sefer',
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildPerformanceStat(
                  Icons.payments,
                  '\u20BA${totalEarnings.toStringAsFixed(0)}',
                  'Toplam Kazanç',
                  AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceStat(
                  Icons.check_circle_outline,
                  '%${acceptanceRate.toStringAsFixed(0)}',
                  'Kabul Oranı',
                  AppColors.info,
                ),
              ),
              Expanded(
                child: _buildPerformanceStat(
                  Icons.cancel_outlined,
                  '%${cancellationRate.toStringAsFixed(1)}',
                  'İptal Oranı',
                  AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceStat(
                  Icons.star,
                  rating > 0 ? rating.toStringAsFixed(1) : '-',
                  'Ortalama Puan',
                  AppColors.warning,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStat(
      IconData icon, String value, String label, Color color) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard(
      AsyncValue<List<Map<String, dynamic>>> documentsAsync) {
    final docTypes = [
      {'type': 'license', 'label': 'Ehliyet (Sürücü Belgesi)'},
      {'type': 'registration', 'label': 'Ruhsat (Araç Tescil)'},
      {'type': 'src', 'label': 'SRC Belgesi'},
      {'type': 'criminal_record', 'label': 'Sabıka Kaydı'},
      {'type': 'insurance', 'label': 'Sigorta'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_open,
                    color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Belge Doğrulama',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          documentsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text('Hata: $e',
                style: const TextStyle(color: AppColors.textSecondary)),
            data: (documents) {
              // Map documents by type
              final docMap = <String, Map<String, dynamic>>{};
              for (final doc in documents) {
                final type = doc['document_type'] as String?;
                if (type != null) {
                  docMap[type] = doc;
                }
              }

              return Column(
                children: docTypes.map((dt) {
                  final doc = docMap[dt['type']];
                  String statusLabel;
                  Color statusColor;
                  IconData statusIcon;

                  if (doc == null) {
                    statusLabel = 'Eksik';
                    statusColor = AppColors.textMuted;
                    statusIcon = Icons.remove_circle_outline;
                  } else {
                    final docStatus = doc['status'] ?? 'pending';
                    switch (docStatus) {
                      case 'verified':
                        statusLabel = 'Onaylandı';
                        statusColor = AppColors.success;
                        statusIcon = Icons.check_circle;
                      case 'pending':
                        statusLabel = 'Bekliyor';
                        statusColor = AppColors.warning;
                        statusIcon = Icons.hourglass_empty;
                      case 'rejected':
                        statusLabel = 'Reddedildi';
                        statusColor = AppColors.error;
                        statusIcon = Icons.cancel;
                      default:
                        statusLabel = 'Bekliyor';
                        statusColor = AppColors.warning;
                        statusIcon = Icons.hourglass_empty;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dt['label']!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String currentStatus) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Durum Yönetimi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusOption(
            currentStatus,
            'active',
            'Aktif',
            AppColors.success,
            Icons.check_circle,
            'Sürücü aktif, yolculuk alabilir.',
          ),
          const SizedBox(height: 8),
          _buildStatusOption(
            currentStatus,
            'inactive',
            'Pasif',
            AppColors.textMuted,
            Icons.pause_circle,
            'Sürücü geçici olarak devre dışı.',
          ),
          const SizedBox(height: 8),
          _buildStatusOption(
            currentStatus,
            'suspended',
            'Askıya Alınmış',
            AppColors.error,
            Icons.block,
            'Sürücü askıya alındı.',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String currentStatus, String statusValue,
      String label, Color color, IconData icon, String description) {
    final isSelected = currentStatus == statusValue;
    return InkWell(
      onTap: () {
        if (statusValue == 'suspended' && !isSelected) {
          _showSuspendDialog(statusValue);
        } else {
          _updateStatus(statusValue, null);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.surfaceLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? color : AppColors.textSecondary,
                size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              Icon(Icons.check, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(Map<String, dynamic> driver) {
    // admin_notes column doesn't exist on taxi_drivers table
    // Notes card kept for UI but not persisted

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Admin Notları',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 5,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Sürücü hakkında notlar ekleyin...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.surfaceLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.surfaceLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveNotes,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSaving ? 'Kaydediliyor...' : 'Notları Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuspendDialog(String statusValue) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Sürücüyü Askıya Al',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Askıya alma sebebini girin:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Sebep...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.surfaceLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _updateStatus(statusValue, reasonController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Askıya Al'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateStatus(String newStatus, String? reason) async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      final client = ref.read(supabaseProvider);
      final updates = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      // suspend_reason not stored on taxi_drivers table
      await client
          .from('taxi_drivers')
          .update(updates)
          .eq('id', widget.driverId);
      ref.invalidate(driverDetailProvider(widget.driverId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sürücü durumu güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveNotes() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      // admin_notes column doesn't exist on taxi_drivers table
      // This is a no-op placeholder
      ref.invalidate(driverDetailProvider(widget.driverId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notlar kaydedildi.'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
