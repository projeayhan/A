import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/realtor_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../widgets/appointment_card.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  bool _isCalendarView = true;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? _listFilterStatus;
  bool _addDialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dashboard quick action'dan ?action=add ile gelince dialog aç
    final action = GoRouterState.of(context).uri.queryParameters['action'];
    if (action == 'add' && !_addDialogShown) {
      _addDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddAppointmentDialog(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appointmentsState = ref.watch(realtorAppointmentsProvider);

    return Column(
      children: [
        // Header bar
        Container(
          color: AppColors.card(isDark),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                'Randevular',
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),

              // Calendar/List toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background(isDark),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border(isDark)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleButton(
                      icon: Icons.calendar_month_rounded,
                      label: 'Takvim',
                      isSelected: _isCalendarView,
                      onTap: () => setState(() => _isCalendarView = true),
                      isDark: isDark,
                    ),
                    _buildToggleButton(
                      icon: Icons.list_rounded,
                      label: 'Liste',
                      isSelected: !_isCalendarView,
                      onTap: () => setState(() => _isCalendarView = false),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Add appointment button
              ElevatedButton.icon(
                onPressed: () => _showAddAppointmentDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Randevu Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: appointmentsState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : appointmentsState.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48,
                              color: AppColors.error.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'Randevular yuklenemedi',
                            style: TextStyle(
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => ref
                                .read(realtorAppointmentsProvider.notifier)
                                .loadAppointments(),
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    )
                  : _isCalendarView
                      ? _buildCalendarView(
                          appointmentsState.appointments, isDark)
                      : _buildListView(
                          appointmentsState.appointments, isDark),
        ),
      ],
    );
  }

  // ============================================
  // TOGGLE BUTTON
  // ============================================

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textMuted(isDark),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textMuted(isDark),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // CALENDAR VIEW
  // ============================================

  Widget _buildCalendarView(
      List<Map<String, dynamic>> appointments, bool isDark) {
    final selectedDayAppts = _getAppointmentsForDay(_selectedDay, appointments);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar
          Container(
            decoration: BoxDecoration(
              color: AppColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(isDark)),
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'tr_TR',
              eventLoader: (day) => _getAppointmentsForDay(day, appointments),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: AppColors.textSecondary(isDark),
                ),
                defaultTextStyle: TextStyle(
                  color: AppColors.textPrimary(isDark),
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                markerDecoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.card(isDark), width: 1),
                ),
                markerSize: 6,
                markersMaxCount: 3,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: AppColors.textSecondary(isDark),
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: AppColors.textMuted(isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                weekendStyle: TextStyle(
                  color: AppColors.textMuted(isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Selected day appointments
          Text(
            _formatSelectedDayTitle(),
            style: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          if (selectedDayAppts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Bu tarih icin randevu bulunmuyor',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...selectedDayAppts.map(
              (apt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppointmentCard(
                  appointment: apt,
                  onAction: (action) => _handleAppointmentAction(apt, action),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================
  // LIST VIEW
  // ============================================

  Widget _buildListView(
      List<Map<String, dynamic>> appointments, bool isDark) {
    // Filter chips
    final statusFilters = <(String?, String)>[
      (null, 'Tumu'),
      ('pending', 'Beklemede'),
      ('scheduled', 'Planlanmis'),
      ('confirmed', 'Onaylandi'),
      ('completed', 'Tamamlandi'),
      ('cancelled', 'Iptal'),
    ];

    final filteredAppointments = _listFilterStatus == null
        ? appointments
        : appointments
            .where((a) => a['status'] == _listFilterStatus)
            .toList();

    return Column(
      children: [
        // Status filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statusFilters.map((filter) {
                final filterValue = filter.$1;
                final filterLabel = filter.$2;
                final isSelected = _listFilterStatus == filterValue;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filterLabel),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _listFilterStatus = filterValue;
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary(isDark),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                    backgroundColor: AppColors.card(isDark),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.border(isDark),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Appointment list
        Expanded(
          child: filteredAppointments.isEmpty
              ? EmptyState(
                  message: 'Randevu bulunamadi',
                  icon: Icons.calendar_today_rounded,
                  buttonText: 'Randevu Ekle',
                  onPressed: () => _showAddAppointmentDialog(context),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredAppointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final apt = filteredAppointments[index];
                    return AppointmentCard(
                      appointment: apt,
                      onAction: (action) =>
                          _handleAppointmentAction(apt, action),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============================================
  // HELPERS
  // ============================================

  List<Map<String, dynamic>> _getAppointmentsForDay(
      DateTime day, List<Map<String, dynamic>> appointments) {
    return appointments.where((apt) {
      DateTime? aptDate;
      if (apt['scheduled_at'] != null) {
        aptDate = DateTime.parse(apt['scheduled_at'] as String);
      } else if (apt['appointment_date'] != null) {
        aptDate = DateTime.parse(apt['appointment_date'] as String);
      }
      if (aptDate == null) return false;
      return aptDate.year == day.year &&
          aptDate.month == day.month &&
          aptDate.day == day.day;
    }).toList();
  }

  String _formatSelectedDayTitle() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

    if (selected == today) {
      return 'Bugunun Randevulari';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (selected == tomorrow) {
      return 'Yarinin Randevulari';
    }
    return '${DateFormat('dd MMMM yyyy', 'tr').format(_selectedDay)} Randevulari';
  }

  Future<void> _handleAppointmentAction(
      Map<String, dynamic> appointment, String action) async {
    final id = appointment['id'] as String;
    final source = appointment['source'] as String? ?? 'customer';
    final notifier = ref.read(realtorAppointmentsProvider.notifier);

    switch (action) {
      case 'confirm':
        final confirmed = await _showConfirmDialog(
          title: 'Randevuyu Onayla',
          message: 'Bu randevuyu onaylamak istediginize emin misiniz?',
          confirmText: 'Onayla',
          confirmColor: AppColors.success,
        );
        if (confirmed == true) {
          final service = ref.read(realtorServiceProvider);
          await service.confirmAppointment(id, null, source: source);
          await notifier.loadAppointments();
        }
        break;

      case 'complete':
        final confirmed = await _showConfirmDialog(
          title: 'Randevuyu Tamamla',
          message: 'Bu randevuyu tamamlandi olarak isaretlemek istiyor musunuz?',
          confirmText: 'Tamamla',
          confirmColor: AppColors.success,
        );
        if (confirmed == true) {
          await notifier.completeAppointment(id, null, source: source);
        }
        break;

      case 'cancel':
        final confirmed = await _showConfirmDialog(
          title: 'Randevuyu Iptal Et',
          message: 'Bu randevuyu iptal etmek istediginize emin misiniz?',
          confirmText: 'Iptal Et',
          confirmColor: AppColors.error,
        );
        if (confirmed == true) {
          await notifier.cancelAppointment(id, null, source: source);
        }
        break;
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    Color? confirmColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondary(isDark),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Vazgec',
              style: TextStyle(color: AppColors.textMuted(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ADD APPOINTMENT DIALOG
  // ============================================

  void _showAddAppointmentDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'showing';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    int durationMinutes = 60;

    final typeOptions = [
      {'value': 'showing', 'label': 'Gosterim', 'icon': Icons.home_rounded},
      {'value': 'meeting', 'label': 'Toplanti', 'icon': Icons.groups_rounded},
      {
        'value': 'phone_call',
        'label': 'Telefon Gorusmesi',
        'icon': Icons.phone_rounded
      },
      {
        'value': 'video_call',
        'label': 'Video Gorusme',
        'icon': Icons.videocam_rounded
      },
      {'value': 'signing', 'label': 'Imza', 'icon': Icons.draw_rounded},
    ];

    final durationOptions = [
      {'value': 15, 'label': '15 dk'},
      {'value': 30, 'label': '30 dk'},
      {'value': 45, 'label': '45 dk'},
      {'value': 60, 'label': '1 saat'},
      {'value': 90, 'label': '1.5 saat'},
      {'value': 120, 'label': '2 saat'},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Yeni Randevu',
                    style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      _buildLabel('Baslik *', isDark),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: titleController,
                        hint: 'Randevu basligi',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // Type dropdown
                      _buildLabel('Randevu Turu', isDark),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.backgroundDark
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border(isDark)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedType,
                            isExpanded: true,
                            dropdownColor: AppColors.card(isDark),
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textMuted(isDark)),
                            items: typeOptions.map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt['value'] as String,
                                child: Row(
                                  children: [
                                    Icon(opt['icon'] as IconData,
                                        size: 18,
                                        color: AppColors.textSecondary(isDark)),
                                    const SizedBox(width: 8),
                                    Text(
                                      opt['label'] as String,
                                      style: TextStyle(
                                        color: AppColors.textPrimary(isDark),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedType = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date and Time row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Tarih *', isDark),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                    );
                                    if (date != null) {
                                      setDialogState(
                                          () => selectedDate = date);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.backgroundDark
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.border(isDark)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded,
                                            size: 16,
                                            color:
                                                AppColors.textMuted(isDark)),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(selectedDate),
                                          style: TextStyle(
                                            color: AppColors.textPrimary(
                                                isDark),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Saat *', isDark),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: selectedTime,
                                    );
                                    if (time != null) {
                                      setDialogState(
                                          () => selectedTime = time);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.backgroundDark
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.border(isDark)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time_rounded,
                                            size: 16,
                                            color:
                                                AppColors.textMuted(isDark)),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: AppColors.textPrimary(
                                                isDark),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Duration
                      _buildLabel('Sure', isDark),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.backgroundDark
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border(isDark)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: durationMinutes,
                            isExpanded: true,
                            dropdownColor: AppColors.card(isDark),
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textMuted(isDark)),
                            items: durationOptions.map((opt) {
                              return DropdownMenuItem<int>(
                                value: opt['value'] as int,
                                child: Text(
                                  opt['label'] as String,
                                  style: TextStyle(
                                    color: AppColors.textPrimary(isDark),
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(
                                    () => durationMinutes = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location
                      _buildLabel('Konum', isDark),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: locationController,
                        hint: 'Randevu konumu',
                        isDark: isDark,
                        prefixIcon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _buildLabel('Aciklama', isDark),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: descriptionController,
                        hint: 'Randevu hakkinda notlar...',
                        isDark: isDark,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Vazgec',
                    style: TextStyle(color: AppColors.textMuted(isDark)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lutfen bir baslik girin'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    final scheduledAt = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    Navigator.of(dialogContext).pop();

                    try {
                      await ref
                          .read(realtorAppointmentsProvider.notifier)
                          .addAppointment(
                            title: title,
                            scheduledAt: scheduledAt,
                            appointmentType: selectedType,
                            durationMinutes: durationMinutes,
                            location: locationController.text.trim().isNotEmpty
                                ? locationController.text.trim()
                                : null,
                            description:
                                descriptionController.text.trim().isNotEmpty
                                    ? descriptionController.text.trim()
                                    : null,
                          );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Randevu olusturuldu'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Olustur',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================
  // SHARED FORM WIDGETS
  // ============================================

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondary(isDark),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    IconData? prefixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: AppColors.textPrimary(isDark),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textMuted(isDark),
          fontSize: 14,
        ),
        filled: true,
        fillColor: isDark ? AppColors.backgroundDark : const Color(0xFFF1F5F9),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: AppColors.textMuted(isDark))
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
