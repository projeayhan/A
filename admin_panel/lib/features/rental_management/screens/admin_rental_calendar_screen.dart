import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/rental_management_providers.dart';

class AdminRentalCalendarScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminRentalCalendarScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminRentalCalendarScreen> createState() => _AdminRentalCalendarScreenState();
}

class _AdminRentalCalendarScreenState extends ConsumerState<AdminRentalCalendarScreen> {
  late DateTime _currentMonth;
  String? _selectedCarFilter;
  int? _selectedDay;
  final _dateFormat = DateFormat('MMMM yyyy', 'tr_TR');

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  DateTime get _monthStart => _currentMonth;
  DateTime get _monthEnd => DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final calendarParams = (companyId: widget.companyId, start: _monthStart, end: _monthEnd);
    final bookingsAsync = ref.watch(rentalCalendarBookingsProvider(calendarParams));
    final carsAsync = ref.watch(rentalCompanyCarsProvider(widget.companyId));

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
                      'Rezervasyon Takvimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Aylık rezervasyon görünümü',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Car Filter
                    carsAsync.when(
                      data: (cars) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedCarFilter,
                            dropdownColor: AppColors.surface,
                            hint: const Text('Tüm Araçlar', style: TextStyle(color: AppColors.textSecondary)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Tüm Araçlar')),
                              ...cars.map((car) => DropdownMenuItem<String?>(
                                value: car['id'] as String,
                                child: Text('${car['brand']} ${car['model']}'),
                              )),
                            ],
                            onChanged: (value) => setState(() => _selectedCarFilter = value),
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(rentalCalendarBookingsProvider(calendarParams)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Month Navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                  ),
                  Text(
                    _dateFormat.format(_currentMonth).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Legend
            _buildLegend(),

            const SizedBox(height: 16),

            // Calendar Grid + Day Detail
            Expanded(
              child: bookingsAsync.when(
                data: (bookings) {
                  final filtered = _selectedCarFilter != null
                      ? bookings.where((b) => b['car_id'] == _selectedCarFilter).toList()
                      : bookings;
                  final totalCars = carsAsync.valueOrNull?.length ?? 1;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar
                      Expanded(
                        flex: 3,
                        child: _buildCalendarGrid(filtered, totalCars),
                      ),
                      // Day detail panel
                      if (_selectedDay != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _buildDayDetailPanel(filtered),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final items = [
      {'label': 'Müsait', 'color': AppColors.success},
      {'label': 'Kısmi Dolu', 'color': AppColors.warning},
      {'label': 'Tamamen Dolu', 'color': AppColors.error},
      {'label': 'Bugün', 'color': AppColors.primary},
    ];

    return Row(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: item['color'] as Color, width: 1.5),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item['label'] as String,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(List<Map<String, dynamic>> bookings, int totalCars) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon

    // Map bookings to days
    final dayBookings = <int, List<Map<String, dynamic>>>{};
    for (final b in bookings) {
      final pickup = DateTime.tryParse(b['pickup_date'] as String? ?? '');
      final dropoff = DateTime.tryParse(b['dropoff_date'] as String? ?? '');
      if (pickup == null || dropoff == null) {
        continue;
      }

      final startDay = pickup.month == _currentMonth.month && pickup.year == _currentMonth.year
          ? pickup.day
          : 1;
      final endDay = dropoff.month == _currentMonth.month && dropoff.year == _currentMonth.year
          ? dropoff.day
          : daysInMonth;

      for (int d = startDay; d <= endDay; d++) {
        dayBookings.putIfAbsent(d, () => []);
        dayBookings[d]!.add(b);
      }
    }

    final dayNames = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
    final totalCells = ((firstWeekday - 1) + daysInMonth);
    final rows = ((totalCells + 6) ~/ 7);
    final gridItemCount = rows * 7;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          // Day headers
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: dayNames.map((d) => Expanded(
                child: Center(
                  child: Text(d, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ),
          const Divider(color: AppColors.surfaceLight, height: 1),
          // Calendar cells
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.2,
              ),
              itemCount: gridItemCount,
              itemBuilder: (context, index) {
                final dayOffset = index - (firstWeekday - 1);
                if (dayOffset < 0 || dayOffset >= daysInMonth) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.3), width: 0.5),
                    ),
                  );
                }

                final day = dayOffset + 1;
                final dayData = dayBookings[day] ?? [];
                final bookingCount = dayData.length;
                final isToday = DateTime.now().day == day &&
                    DateTime.now().month == _currentMonth.month &&
                    DateTime.now().year == _currentMonth.year;
                final isSelected = _selectedDay == day;

                // Color coding based on availability
                Color dayColor;
                if (bookingCount == 0) {
                  dayColor = AppColors.success;
                } else if (bookingCount >= totalCars && totalCars > 0) {
                  dayColor = AppColors.error;
                } else {
                  dayColor = AppColors.warning;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceLight.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 0.5,
                      ),
                      color: isToday
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : isSelected
                              ? AppColors.primary.withValues(alpha: 0.05)
                              : null,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: isToday
                                  ? BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    )
                                  : null,
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  color: isToday ? Colors.white : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (bookingCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: dayColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$bookingCount',
                                  style: TextStyle(color: dayColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        // Color indicator bar
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: dayColor.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayDetailPanel(List<Map<String, dynamic>> allBookings) {
    final day = _selectedDay!;
    final dayBookings = allBookings.where((b) {
      final pickup = DateTime.tryParse(b['pickup_date'] as String? ?? '');
      final dropoff = DateTime.tryParse(b['dropoff_date'] as String? ?? '');
      if (pickup == null || dropoff == null) {
        return false;
      }
      final dayDate = DateTime(_currentMonth.year, _currentMonth.month, day);
      return !dayDate.isBefore(DateTime(pickup.year, pickup.month, pickup.day)) &&
          !dayDate.isAfter(DateTime(dropoff.year, dropoff.month, dropoff.day));
    }).toList();

    final dateStr = DateFormat('dd MMMM yyyy', 'tr_TR').format(
      DateTime(_currentMonth.year, _currentMonth.month, day),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(
                onPressed: () => setState(() => _selectedDay = null),
                icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${dayBookings.length} rezervasyon',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.surfaceLight),
          const SizedBox(height: 8),
          Expanded(
            child: dayBookings.isEmpty
                ? const Center(
                    child: Text('Bu gün için rezervasyon yok', style: TextStyle(color: AppColors.textMuted)),
                  )
                : ListView.separated(
                    itemCount: dayBookings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final b = dayBookings[index];
                      final car = b['rental_cars'] as Map<String, dynamic>?;
                      final carLabel = car != null ? '${car['brand']} ${car['model']}' : '?';
                      final customerName = b['customer_name'] as String? ?? '-';
                      final status = b['status'] as String? ?? '';
                      final pickupDate = DateTime.tryParse(b['pickup_date'] as String? ?? '');
                      final dropoffDate = DateTime.tryParse(b['dropoff_date'] as String? ?? '');

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _statusColor(status).withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(carLabel, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                                _buildMiniStatusBadge(status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(customerName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.date_range, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  pickupDate != null && dropoffDate != null
                                      ? '${DateFormat('dd.MM').format(pickupDate)} - ${DateFormat('dd.MM').format(dropoffDate)}'
                                      : '-',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.info;
      case 'active':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Bekleyen';
      case 'confirmed':
        return 'Onaylandı';
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      default:
        return status;
    }
  }
}
