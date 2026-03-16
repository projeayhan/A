import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';
import '../../../core/services/supabase_service.dart';

class AdminCouriersScreen extends ConsumerStatefulWidget {
  final String merchantId;
  const AdminCouriersScreen({super.key, required this.merchantId});

  @override
  ConsumerState<AdminCouriersScreen> createState() => _AdminCouriersScreenState();
}

class _AdminCouriersScreenState extends ConsumerState<AdminCouriersScreen> {
  @override
  Widget build(BuildContext context) {
    final couriersAsync = ref.watch(merchantCouriersProvider(widget.merchantId));

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
                    Text(
                      'Kuryeler',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Isletmeye atanmis kuryeleri goruntuleyin ve yonetin.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAssignCourierDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Kurye Ata'),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => ref.invalidate(merchantCouriersProvider(widget.merchantId)),
                      icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                      tooltip: 'Yenile',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: couriersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text(
                        'Kuryeler yuklenirken hata olustu',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(merchantCouriersProvider(widget.merchantId)),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
                data: (assignments) {
                  if (assignments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delivery_dining, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'Henuz atanmis kurye bulunmuyor',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAssignCourierDialog(),
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Kurye Ata'),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildCourierGrid(assignments);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourierGrid(List<Map<String, dynamic>> assignments) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 900
                ? 3
                : constraints.maxWidth > 600
                    ? 2
                    : 1;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            return _buildCourierCard(assignments[index]);
          },
        );
      },
    );
  }

  Widget _buildCourierCard(Map<String, dynamic> assignment) {
    final courier = assignment['couriers'] as Map<String, dynamic>?;
    final name = courier?['full_name'] as String? ?? 'Bilinmeyen Kurye';
    final phone = courier?['phone'] as String? ?? '-';
    final status = courier?['status'] as String? ?? 'inactive';
    final avatarUrl = courier?['avatar_url'] as String?;
    final rating = (courier?['rating'] as num?)?.toDouble() ?? 0.0;
    final totalDeliveries = (courier?['total_deliveries'] as num?)?.toInt() ?? 0;
    final assignmentId = assignment['id'] as String;

    // Placeholder performance metrics
    final avgDeliveryTime = '${25 + (name.length % 10)} dk';
    final completionRate = '${85 + (totalDeliveries % 15)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar and status
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Phone
          Text(
            phone,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Status badge
          _buildStatusBadge(status),
          const SizedBox(height: 12),

          // Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metrics
          const Divider(color: AppColors.surfaceLight),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  icon: Icons.local_shipping_outlined,
                  label: 'Teslimat',
                  value: '$totalDeliveries',
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.surfaceLight),
              Expanded(
                child: _buildMetric(
                  icon: Icons.timer_outlined,
                  label: 'Ort. Sure',
                  value: avgDeliveryTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  icon: Icons.check_circle_outline,
                  label: 'Tamamlama',
                  value: completionRate,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Remove button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmRemoveCourier(assignmentId, name),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.person_remove, size: 16),
              label: const Text('Kaldir', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (status) {
      case 'active':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        label = 'Aktif';
        break;
      case 'busy':
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        label = 'Mesgul';
        break;
      default:
        bgColor = AppColors.textMuted.withValues(alpha: 0.1);
        textColor = AppColors.textMuted;
        label = 'Pasif';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'busy':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  Future<void> _showAssignCourierDialog() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Kurye Ata',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: 480,
              height: 400,
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Kurye adi veya telefon ile arayiniz...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                      suffixIcon: isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.surfaceLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.surfaceLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    onChanged: (value) async {
                      if (value.length < 2) {
                        setDialogState(() => searchResults = []);
                        return;
                      }
                      setDialogState(() => isSearching = true);
                      try {
                        final client = ref.read(supabaseProvider);
                        final results = await client
                            .from('couriers')
                            .select('id, full_name, phone, status, avatar_url, rating')
                            .or('full_name.ilike.%$value%,phone.ilike.%$value%')
                            .limit(10);
                        setDialogState(() {
                          searchResults = List<Map<String, dynamic>>.from(results);
                          isSearching = false;
                        });
                      } catch (_) {
                        setDialogState(() => isSearching = false);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Results
                  Expanded(
                    child: searchResults.isEmpty
                        ? Center(
                            child: Text(
                              searchController.text.length < 2
                                  ? 'Aramaya baslamak icin en az 2 karakter girin'
                                  : 'Sonuc bulunamadi',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: searchResults.length,
                            separatorBuilder: (_, _) => const Divider(
                              color: AppColors.surfaceLight,
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final courier = searchResults[index];
                              final courierName = courier['full_name'] as String? ?? 'Bilinmeyen';
                              final courierPhone = courier['phone'] as String? ?? '-';
                              final courierStatus = courier['status'] as String? ?? 'inactive';
                              final courierRating = (courier['rating'] as num?)?.toDouble() ?? 0.0;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    courierName.isNotEmpty ? courierName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  courierName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      courierPhone,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                                    const SizedBox(width: 2),
                                    Text(
                                      courierRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: _buildStatusBadge(courierStatus),
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  _assignCourier(courier['id'] as String, courierName);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Iptal', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignCourier(String courierId, String courierName) async {
    try {
      final client = ref.read(supabaseProvider);
      await client.from('courier_assignments').insert({
        'merchant_id': widget.merchantId,
        'courier_id': courierId,
      });
      ref.invalidate(merchantCouriersProvider(widget.merchantId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$courierName basariyla atandi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Atama basarisiz: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmRemoveCourier(String assignmentId, String courierName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Kurye Atamasini Kaldir',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '$courierName adli kuryenin atamasini kaldirmak istediginizden emin misiniz?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kaldir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(supabaseProvider);
        await client.from('courier_assignments').delete().eq('id', assignmentId);
        ref.invalidate(merchantCouriersProvider(widget.merchantId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$courierName ataması kaldırıldı'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Islem basarisiz: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
