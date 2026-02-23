import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/realtor_provider.dart';

/// Card displaying today's appointments on the dashboard
class TodayAppointmentsCard extends ConsumerWidget {
  const TodayAppointmentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appointmentsState = ref.watch(realtorAppointmentsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bugunku Randevular',
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/appointments'),
                child: const Text('Tumunu Gor'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (appointmentsState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (appointmentsState.todayAppointments.isEmpty)
            _buildEmpty(isDark)
          else
            ...appointmentsState.todayAppointments
                .take(3)
                .map((apt) => _AppointmentItem(appointment: apt)),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: AppColors.textMuted(isDark),
          ),
          const SizedBox(height: 12),
          Text(
            'Bugun randevunuz yok',
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single appointment row item
class _AppointmentItem extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const _AppointmentItem({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = appointment['status'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background(isDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.access_time,
              color: AppColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment['properties']?['title'] ??
                      appointment['title'] ??
                      'Randevu',
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(appointment),
                  style: TextStyle(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(status: status),
        ],
      ),
    );
  }

  String _formatTime(Map<String, dynamic> apt) {
    if (apt['appointment_time'] != null) {
      return (apt['appointment_time'] as String).substring(0, 5);
    }
    if (apt['scheduled_at'] != null) {
      return DateTime.parse(apt['scheduled_at']).toString().substring(11, 16);
    }
    return '';
  }
}

/// Colored status badge
class _StatusBadge extends StatelessWidget {
  final String? status;

  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final label = _statusLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (status) {
      case 'scheduled':
        return AppColors.info;
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return const Color(0xFF64748B);
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'scheduled':
        return 'Planlandi';
      case 'pending':
        return 'Beklemede';
      case 'confirmed':
        return 'Onaylandi';
      case 'completed':
        return 'Tamamlandi';
      case 'cancelled':
        return 'Iptal';
      default:
        return status ?? '';
    }
  }
}
