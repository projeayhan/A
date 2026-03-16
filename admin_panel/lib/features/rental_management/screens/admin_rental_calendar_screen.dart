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
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
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

            // Status Legend
            _buildStatusLegend(),

            const SizedBox(height: 16),

            // Calendar Grid
            Expanded(
              child: bookingsAsync.when(
                data: (bookings) {
                  final filtered = _selectedCarFilter != null
                      ? bookings.where((b) => b['car_id'] == _selectedCarFilter).toList()
                      : bookings;
                  return _buildCalendarGrid(filtered);
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

  Widget _buildStatusLegend() {
    final items = [
      {'label': 'Beklemede', 'color': AppColors.warning},
      {'label': 'Onaylandı', 'color': AppColors.info},
      {'label': 'Aktif', 'color': AppColors.primary},
      {'label': 'Tamamlandı', 'color': AppColors.success},
      {'label': 'İptal', 'color': AppColors.error},
    ];

    return Row(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item['color'] as Color,
                  borderRadius: BorderRadius.circular(3),
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

  Widget _buildCalendarGrid(List<Map<String, dynamic>> bookings) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon

    // Map bookings to days
    final dayBookings = <int, List<Map<String, dynamic>>>{};
    for (final b in bookings) {
      final pickup = DateTime.tryParse(b['pickup_date'] as String? ?? '');
      final dropoff = DateTime.tryParse(b['dropoff_date'] as String? ?? '');
      if (pickup == null || dropoff == null) continue;

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

    final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

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
                childAspectRatio: 1.0,
              ),
              itemCount: ((firstWeekday - 1) + daysInMonth + (7 - ((firstWeekday - 1 + daysInMonth) % 7)) % 7),
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
                final isToday = DateTime.now().day == day &&
                    DateTime.now().month == _currentMonth.month &&
                    DateTime.now().year == _currentMonth.year;

                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.3), width: 0.5),
                    color: isToday ? AppColors.primary.withValues(alpha: 0.05) : null,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isToday ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ...dayData.take(3).map((b) {
                        final car = b['rental_cars'] as Map<String, dynamic>?;
                        final carLabel = car != null ? '${car['brand']} ${car['model']}' : '?';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(b['status'] as String? ?? '').withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              carLabel,
                              style: TextStyle(
                                color: _statusColor(b['status'] as String? ?? ''),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }),
                      if (dayData.length > 3)
                        Text(
                          '+${dayData.length - 3}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'confirmed': return AppColors.info;
      case 'active': return AppColors.primary;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textMuted;
    }
  }
}
