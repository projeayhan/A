import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/emlak_management_providers.dart';

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  final String realtorId;
  const AdminAppointmentsScreen({super.key, required this.realtorId});

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');

  String _statusFilter = 'all';
  bool _showCalendar = false;
  DateTime _calendarMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync =
        ref.watch(realtorAppointmentsProvider(widget.realtorId));

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
                      'Randevular',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Emlakci randevularini yonetin ve takip edin',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // View toggle
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Row(
                        children: [
                          _buildViewToggle(
                            icon: Icons.list,
                            label: 'Liste',
                            isSelected: !_showCalendar,
                            onTap: () =>
                                setState(() => _showCalendar = false),
                          ),
                          _buildViewToggle(
                            icon: Icons.calendar_month,
                            label: 'Takvim',
                            isSelected: _showCalendar,
                            onTap: () =>
                                setState(() => _showCalendar = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(
                        realtorAppointmentsProvider(widget.realtorId),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            appointmentsAsync.when(
              data: (appointments) {
                final pendingCount = appointments
                    .where((a) => a['status'] == 'pending')
                    .length;
                final confirmedCount = appointments
                    .where((a) => a['status'] == 'confirmed')
                    .length;
                final completedCount = appointments
                    .where((a) => a['status'] == 'completed')
                    .length;
                final cancelledCount = appointments
                    .where((a) => a['status'] == 'cancelled')
                    .length;
                final todayCount = _countTodayAppointments(appointments);

                return Row(
                  children: [
                    _buildStatCard(
                      'Toplam',
                      appointments.length.toString(),
                      Icons.event,
                      AppColors.primary,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      'Bugün',
                      todayCount.toString(),
                      Icons.today,
                      todayCount > 0 ? AppColors.info : AppColors.textMuted,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      'Beklemede',
                      pendingCount.toString(),
                      Icons.pending,
                      AppColors.warning,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      'Onaylandı',
                      confirmedCount.toString(),
                      Icons.event_available,
                      AppColors.success,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      'Tamamlandı',
                      completedCount.toString(),
                      Icons.check_circle,
                      AppColors.info,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      'İptal',
                      cancelledCount.toString(),
                      Icons.event_busy,
                      AppColors.error,
                    ),
                  ],
                );
              },
              loading: () => Row(
                children: List.generate(
                  6,
                  (_) => Expanded(
                    child: Container(
                      height: 80,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Status filter chips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  const Text(
                    'Durum:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ..._buildFilterChips(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Content
            Expanded(
              child: appointmentsAsync.when(
                data: (appointments) {
                  final filtered = _statusFilter == 'all'
                      ? appointments
                      : appointments
                          .where((a) => a['status'] == _statusFilter)
                          .toList();

                  if (_showCalendar) {
                    return _buildCalendarView(filtered);
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.event,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Randevu bulunamadı',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          if (_statusFilter != 'all')
                            TextButton(
                              onPressed: () =>
                                  setState(() => _statusFilter = 'all'),
                              child: const Text('Filtreleri Temizle'),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildAppointmentCard(filtered[index]),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Hata: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countTodayAppointments(List<Map<String, dynamic>> appointments) {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return appointments.where((a) {
      final dateStr = a['appointment_date'] as String?;
      if (dateStr == null) return false;
      return dateStr.startsWith(todayStr);
    }).length;
  }

  bool _isToday(String? dateStr) {
    if (dateStr == null) return false;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return dateStr.startsWith(todayStr);
  }

  List<Widget> _buildFilterChips() {
    final filters = [
      ('all', 'Tümü'),
      ('pending', 'Beklemede'),
      ('confirmed', 'Onaylandı'),
      ('completed', 'Tamamlandı'),
      ('cancelled', 'İptal'),
    ];

    return filters.map((f) {
      final isSelected = _statusFilter == f.$1;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(f.$2),
          selected: isSelected,
          onSelected: (_) => setState(() => _statusFilter = f.$1),
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final status = appointment['status'] as String? ?? 'pending';
    final property = appointment['properties'] as Map<String, dynamic>?;
    final clientName =
        appointment['client_name'] as String? ?? 'Bilinmeyen';
    final clientPhone = appointment['client_phone'] as String?;
    final propertyImages = property?['images'] as List?;
    final imageUrl = propertyImages != null && propertyImages.isNotEmpty
        ? propertyImages[0] as String?
        : null;
    final appointmentDate = appointment['appointment_date'] as String?;
    final appointmentTime = appointment['appointment_time'] as String? ?? '';
    final isAppointmentToday = _isToday(appointmentDate);

    // Calculate time slot display
    String timeDisplay = '';
    if (appointmentTime.isNotEmpty) {
      final timePart = appointmentTime.length >= 5
          ? appointmentTime.substring(0, 5)
          : appointmentTime;
      // Show 1-hour slot
      final parts = timePart.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        if (hour != null) {
          final endHour = (hour + 1).toString().padLeft(2, '0');
          timeDisplay = '$timePart - $endHour:${parts[1]}';
        } else {
          timeDisplay = timePart;
        }
      } else {
        timeDisplay = timePart;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAppointmentToday
              ? AppColors.info.withValues(alpha: 0.4)
              : AppColors.surfaceLight,
          width: isAppointmentToday ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 90,
              height: 90,
              color: AppColors.surfaceLight,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.home,
                        color: AppColors.textMuted,
                        size: 28,
                      ),
                    )
                  : const Icon(
                      Icons.home,
                      color: AppColors.textMuted,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 20),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        property?['title'] ?? 'Bilinmeyen İlan',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _buildStatusBadge(status),
                    if (isAppointmentToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.today,
                              size: 12,
                              color: AppColors.info,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Bugün',
                              style: TextStyle(
                                color: AppColors.info,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                // Client info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clientName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (clientPhone != null) ...[
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.phone,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        clientPhone,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Date & time slot
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            appointmentDate != null
                                ? _dateFormat.format(
                                    DateTime.parse(appointmentDate))
                                : '-',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (timeDisplay.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              timeDisplay,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                // Notes
                if (appointment['note'] != null &&
                    (appointment['note'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Not: ${appointment['note']}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (appointment['response_note'] != null &&
                    (appointment['response_note'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Yanit: ${appointment['response_note']}',
                    style: const TextStyle(
                      color: AppColors.info,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Actions - status workflow
          Column(
            children: [
              if (status == 'pending') ...[
                _buildActionButton(
                  'Onayla',
                  Icons.check,
                  AppColors.success,
                  () => _updateStatus(appointment['id'], 'confirmed'),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  'İptal Et',
                  Icons.close,
                  AppColors.error,
                  () => _updateStatus(appointment['id'], 'cancelled'),
                ),
              ],
              if (status == 'confirmed') ...[
                _buildActionButton(
                  'Tamamla',
                  Icons.done_all,
                  AppColors.info,
                  () => _updateStatus(appointment['id'], 'completed'),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  'İptal Et',
                  Icons.close,
                  AppColors.error,
                  () => _updateStatus(appointment['id'], 'cancelled'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 120,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildCalendarView(List<Map<String, dynamic>> appointments) {
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon
    final monthName = DateFormat('MMMM yyyy', 'tr').format(_calendarMonth);

    // Group appointments by date
    final Map<int, List<Map<String, dynamic>>> appointmentsByDay = {};
    for (final a in appointments) {
      final dateStr = a['appointment_date'] as String?;
      if (dateStr == null) {
        continue;
      }
      final date = DateTime.tryParse(dateStr);
      if (date != null && date.year == year && date.month == month) {
        appointmentsByDay.putIfAbsent(date.day, () => []).add(a);
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(year, month - 1);
                }),
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                monthName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(year, month + 1);
                }),
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekday headers
          Row(
            children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
                .map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          Expanded(
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final dayOffset = index - (firstWeekday - 1);
                if (dayOffset < 0 || dayOffset >= daysInMonth) {
                  return const SizedBox.shrink();
                }
                final day = dayOffset + 1;
                final dayAppointments = appointmentsByDay[day] ?? [];
                final isToday = DateTime.now().year == year &&
                    DateTime.now().month == month &&
                    DateTime.now().day == day;

                return InkWell(
                  onTap: dayAppointments.isNotEmpty
                      ? () => _showDayAppointmentsDialog(
                            day,
                            month,
                            year,
                            dayAppointments,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : dayAppointments.isNotEmpty
                              ? AppColors.surfaceLight
                                  .withValues(alpha: 0.3)
                              : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(
                              color: AppColors.primary
                                  .withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isToday
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (dayAppointments.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children:
                                dayAppointments.take(4).map((a) {
                              return Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    a['status'] as String? ?? 'pending',
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
                          if (dayAppointments.length > 4) ...[
                            const SizedBox(height: 2),
                            Text(
                              '+${dayAppointments.length - 4}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Legend
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Beklemede', AppColors.warning),
              const SizedBox(width: 16),
              _buildLegendItem('Onaylandı', AppColors.success),
              const SizedBox(width: 16),
              _buildLegendItem('Tamamlandı', AppColors.info),
              const SizedBox(width: 16),
              _buildLegendItem('İptal', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  void _showDayAppointmentsDialog(
    int day,
    int month,
    int year,
    List<Map<String, dynamic>> appointments,
  ) {
    final dateStr = _dateFormat.format(DateTime(year, month, day));

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${appointments.length} randevu',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceLight),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: appointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final a = appointments[index];
                    final status =
                        a['status'] as String? ?? 'pending';
                    final property =
                        a['properties'] as Map<String, dynamic>?;
                    final time =
                        a['appointment_time'] as String? ?? '-';
                    final clientName =
                        a['client_name'] as String? ?? '-';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          // Time
                          Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                time.length >= 5
                                    ? time.substring(0, 5)
                                    : time,
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  property?['title'] ??
                                      'Bilinmeyen İlan',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  clientName,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.success;
      case 'completed':
        return AppColors.info;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'confirmed':
        return 'Onaylandı';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      default:
        return status;
    }
  }

  Future<void> _updateStatus(
    String appointmentId,
    String newStatus,
  ) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('appointments').update({
        'status': newStatus,
      }).eq('id', appointmentId);

      ref.invalidate(realtorAppointmentsProvider(widget.realtorId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Randevu ${_getStatusText(newStatus).toLowerCase()}'),
          backgroundColor: _getStatusColor(newStatus),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
