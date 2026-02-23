import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback? onTap;
  final Function(String action)? onAction;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
    this.onAction,
  });

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'showing':
        return Icons.home_rounded;
      case 'meeting':
        return Icons.groups_rounded;
      case 'phone_call':
        return Icons.phone_rounded;
      case 'video_call':
        return Icons.videocam_rounded;
      case 'signing':
        return Icons.draw_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'showing':
        return AppColors.primary;
      case 'meeting':
        return AppColors.secondary;
      case 'phone_call':
        return const Color(0xFF8B5CF6);
      case 'video_call':
        return const Color(0xFFEC4899);
      case 'signing':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'showing':
        return 'Gosterim';
      case 'meeting':
        return 'Toplanti';
      case 'phone_call':
        return 'Telefon';
      case 'video_call':
        return 'Video';
      case 'signing':
        return 'Imza';
      default:
        return 'Randevu';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
      case 'scheduled':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'confirmed':
        return 'Onaylandi';
      case 'scheduled':
        return 'Planlanmis';
      case 'completed':
        return 'Tamamlandi';
      case 'cancelled':
        return 'Iptal';
      default:
        return 'Beklemede';
    }
  }

  String _formatDateTime(Map<String, dynamic> apt) {
    // Support both appointment_date/time and scheduled_at formats
    if (apt['scheduled_at'] != null) {
      final dt = DateTime.parse(apt['scheduled_at'] as String);
      return DateFormat('dd MMM yyyy HH:mm', 'tr').format(dt);
    }
    if (apt['appointment_date'] != null) {
      final date = apt['appointment_date'] as String;
      final time = apt['appointment_time'] as String? ?? '';
      final dt = DateTime.parse(date);
      final formattedDate = DateFormat('dd MMM yyyy', 'tr').format(dt);
      final formattedTime =
          time.length >= 5 ? time.substring(0, 5) : time;
      return '$formattedDate $formattedTime';
    }
    return '';
  }

  String? _getRequesterName(Map<String, dynamic> apt) {
    final requester = apt['requester'] as Map<String, dynamic>?;
    if (requester != null) {
      return requester['full_name'] as String?;
    }
    return apt['client_name'] as String?;
  }

  String? _getTitle(Map<String, dynamic> apt) {
    if (apt['title'] != null) return apt['title'] as String;
    final property = apt['properties'] as Map<String, dynamic>?;
    if (property != null) return property['title'] as String?;
    return null;
  }

  String? _getLocation(Map<String, dynamic> apt) {
    if (apt['location'] != null) return apt['location'] as String;
    final property = apt['properties'] as Map<String, dynamic>?;
    if (property != null) {
      final city = property['city'] as String? ?? '';
      final district = property['district'] as String? ?? '';
      if (city.isNotEmpty || district.isNotEmpty) {
        return [district, city].where((s) => s.isNotEmpty).join(', ');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = appointment['status'] as String?;
    final type = appointment['appointment_type'] as String?;
    final title = _getTitle(appointment);
    final requesterName = _getRequesterName(appointment);
    final dateTime = _formatDateTime(appointment);
    final location = _getLocation(appointment);
    final typeColor = _getTypeColor(type);
    final isActionable =
        status == 'pending' || status == 'confirmed' || status == 'scheduled';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(isDark)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: typeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title ?? 'Randevu',
                            style: TextStyle(
                              color: AppColors.textPrimary(isDark),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: _getStatusLabel(status),
                          color: _getStatusColor(status),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Type label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTypeLabel(type),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Requester
                    if (requesterName != null && requesterName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: AppColors.textMuted(isDark),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              requesterName,
                              style: TextStyle(
                                color: AppColors.textSecondary(isDark),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Date/Time
                    if (dateTime.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppColors.textMuted(isDark),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateTime,
                              style: TextStyle(
                                color: AppColors.textSecondary(isDark),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Location
                    if (location != null && location.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textMuted(isDark),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                color: AppColors.textSecondary(isDark),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Action menu
              if (isActionable && onAction != null)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textMuted(isDark),
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  offset: const Offset(0, 40),
                  itemBuilder: (context) => [
                    if (status == 'pending')
                      const PopupMenuItem(
                        value: 'confirm',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 20, color: AppColors.success),
                            SizedBox(width: 12),
                            Text('Onayla'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'complete',
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded,
                              size: 20, color: AppColors.success),
                          SizedBox(width: 12),
                          Text('Tamamla'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined,
                              size: 20, color: AppColors.error),
                          SizedBox(width: 12),
                          Text('Iptal Et'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (action) => onAction?.call(action),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
