import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_config.dart';
import '../../core/theme.dart';
import '../bookings/bookings_screen.dart';

// Provider for selected week start date
final selectedWeekStartProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  // Start from Monday of current week
  return now.subtract(Duration(days: now.weekday - 1));
});

// Filter providers
final calendarSearchProvider = StateProvider<String>((ref) => '');
final calendarStatusFilterProvider = StateProvider<String?>((ref) => null); // null = all, 'booked', 'maintenance', 'available'
final showOnlyBookedProvider = StateProvider<bool>((ref) => false);

// Provider for all cars
final calendarCarsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  debugPrint('CalendarCarsProvider - companyId: $companyId');

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_cars')
      .select('id, brand, model, plate, status, daily_price')
      .eq('company_id', companyId)
      .eq('is_active', true)
      .order('brand');

  debugPrint('CalendarCarsProvider - loaded ${response.length} cars');
  return List<Map<String, dynamic>>.from(response);
});

// Provider for bookings in selected week range
final weekBookingsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);
  final weekStart = ref.watch(selectedWeekStartProvider);

  if (companyId == null) return <Map<String, dynamic>>[];

  final weekEnd = weekStart.add(const Duration(days: 7));

  final response = await client
      .from('rental_bookings')
      .select('id, car_id, customer_name, customer_phone, pickup_date, dropoff_date, status, total_amount, company_notes')
      .eq('company_id', companyId)
      .gte('dropoff_date', weekStart.toIso8601String().split('T')[0])
      .lte('pickup_date', weekEnd.toIso8601String().split('T')[0])
      .order('pickup_date');

  return List<Map<String, dynamic>>.from(response);
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  // Selection state - click based (first click = start, second click = end)
  String? _selectedCarId;
  DateTime? _selectionStartDate;
  DateTime? _selectionEndDate;
  bool _isSelectingEndDate = false; // true = waiting for end date click

  // Get normalized date range (start always before end)
  (DateTime, DateTime)? get _selectedRange {
    if (_selectionStartDate == null || _selectionEndDate == null || _selectedCarId == null) {
      return null;
    }
    if (_selectionStartDate!.isBefore(_selectionEndDate!)) {
      return (_selectionStartDate!, _selectionEndDate!);
    }
    return (_selectionEndDate!, _selectionStartDate!);
  }

  bool get _hasSelection => _selectedRange != null;

  bool _isDateInSelection(String carId, DateTime date) {
    if (_selectedCarId != carId) return false;

    // Highlight start date while waiting for end date
    if (_isSelectingEndDate && _selectionStartDate != null && _selectionEndDate == null) {
      return _isSameDay(date, _selectionStartDate!);
    }

    if (_selectedRange == null) return false;
    final (start, end) = _selectedRange!;
    return !date.isBefore(start) && !date.isAfter(end);
  }

  int get _selectedDaysCount {
    if (_selectedRange == null) return 0;
    final (start, end) = _selectedRange!;
    return end.difference(start).inDays + 1;
  }

  void _handleCellTap(String carId, DateTime day, bool canSelect, Map<String, dynamic>? dayBooking) {
    if (dayBooking != null) {
      // Navigate to booking detail page
      final bookingId = dayBooking['id'] as String;
      context.go('/bookings/$bookingId');
      return;
    }

    if (!canSelect) return;

    setState(() {
      if (!_isSelectingEndDate || _selectedCarId != carId) {
        // First click - set start date
        _selectedCarId = carId;
        _selectionStartDate = day;
        _selectionEndDate = null;
        _isSelectingEndDate = true;
      } else {
        // Second click - set end date
        _selectionEndDate = day;
        _isSelectingEndDate = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCarId = null;
      _selectionStartDate = null;
      _selectionEndDate = null;
      _isSelectingEndDate = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(calendarCarsProvider);
    final bookingsAsync = ref.watch(weekBookingsProvider);
    final weekStart = ref.watch(selectedWeekStartProvider);
    final searchQuery = ref.watch(calendarSearchProvider).toLowerCase();
    final statusFilter = ref.watch(calendarStatusFilterProvider);
    final showOnlyBooked = ref.watch(showOnlyBookedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header with week navigation
          _buildHeader(context, ref, weekStart),

          // Filters and stats bar
          _buildFiltersBar(context, ref),

          // Selection indicator (when selecting)
          if (_isSelectingEndDate && _selectionStartDate != null)
            _buildSelectionHint(carsAsync),

          // Selection indicator (when complete range selected)
          if (_hasSelection)
            _buildSelectionIndicator(carsAsync),

          // Timeline content
          Expanded(
            child: carsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (cars) => bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (bookings) {
                  // Apply filters
                  var filteredCars = cars.where((car) {
                    // Search filter
                    if (searchQuery.isNotEmpty) {
                      final carName = '${car['brand']} ${car['model']}'.toLowerCase();
                      final plate = (car['plate'] ?? '').toString().toLowerCase();
                      if (!carName.contains(searchQuery) && !plate.contains(searchQuery)) {
                        return false;
                      }
                    }

                    // Status filter
                    final carStatus = car['status'] ?? 'available';
                    if (statusFilter == 'maintenance' && carStatus != 'maintenance') {
                      return false;
                    }
                    if (statusFilter == 'available' && carStatus != 'available') {
                      return false;
                    }

                    // Show only booked filter
                    if (showOnlyBooked || statusFilter == 'booked') {
                      final hasBooking = bookings.any((b) => b['car_id'] == car['id']);
                      if (!hasBooking) return false;
                    }

                    return true;
                  }).toList();

                  debugPrint('Calendar filter state: showOnlyBooked=$showOnlyBooked, statusFilter=$statusFilter, searchQuery=$searchQuery');
                  debugPrint('Filtered cars: ${filteredCars.length} / ${cars.length}');
                  return _buildTimeline(context, ref, filteredCars, bookings, weekStart, cars.length);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHint(AsyncValue<List<Map<String, dynamic>>> carsAsync) {
    final dateFormat = DateFormat('d MMM', 'tr_TR');

    // Get car name
    String carName = '';
    carsAsync.whenData((cars) {
      final car = cars.firstWhere(
        (c) => c['id'] == _selectedCarId,
        orElse: () => <String, dynamic>{},
      );
      if (car.isNotEmpty) {
        carName = '${car['brand']} ${car['model']}';
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.touch_app, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text(
            '$carName • Başlangıç: ${dateFormat.format(_selectionStartDate!)} - Bitiş tarihini seçin',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('İptal'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionIndicator(AsyncValue<List<Map<String, dynamic>>> carsAsync) {
    final dateFormat = DateFormat('d MMM', 'tr_TR');
    final (start, end) = _selectedRange!;

    // Get car name
    String carName = '';
    carsAsync.whenData((cars) {
      final car = cars.firstWhere(
        (c) => c['id'] == _selectedCarId,
        orElse: () => <String, dynamic>{},
      );
      if (car.isNotEmpty) {
        carName = '${car['brand']} ${car['model']}';
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.date_range, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Seçilen: $carName • ${dateFormat.format(start)} - ${dateFormat.format(end)} ($_selectedDaysCount gün)',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('İptal'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showCreateBookingDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Rezervasyon Oluştur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(calendarStatusFilterProvider);
    final showOnlyBooked = ref.watch(showOnlyBookedProvider);
    final carsAsync = ref.watch(calendarCarsProvider);
    final bookingsAsync = ref.watch(weekBookingsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surfaceLight,
      child: Row(
        children: [
          // Search field
          SizedBox(
            width: 250,
            height: 38,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Araç ara (marka, model, plaka)',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (value) {
                ref.read(calendarSearchProvider.notifier).state = value;
              },
            ),
          ),

          const SizedBox(width: 16),

          // Status filter chips
          _buildFilterChip(
            label: 'Tümü',
            isSelected: statusFilter == null && !showOnlyBooked,
            onTap: () {
              ref.read(calendarStatusFilterProvider.notifier).state = null;
              ref.read(showOnlyBookedProvider.notifier).state = false;
              ref.read(calendarSearchProvider.notifier).state = '';
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Rezervasyonlu',
            isSelected: showOnlyBooked || statusFilter == 'booked',
            color: Colors.blue[400],
            onTap: () {
              ref.read(showOnlyBookedProvider.notifier).state = !showOnlyBooked;
              ref.read(calendarStatusFilterProvider.notifier).state = null;
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Bakımda',
            isSelected: statusFilter == 'maintenance',
            color: AppColors.warning,
            onTap: () {
              ref.read(calendarStatusFilterProvider.notifier).state =
                  statusFilter == 'maintenance' ? null : 'maintenance';
              ref.read(showOnlyBookedProvider.notifier).state = false;
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Müsait',
            isSelected: statusFilter == 'available',
            color: AppColors.success,
            onTap: () {
              ref.read(calendarStatusFilterProvider.notifier).state =
                  statusFilter == 'available' ? null : 'available';
              ref.read(showOnlyBookedProvider.notifier).state = false;
            },
          ),

          const Spacer(),

          // Stats
          carsAsync.when(
            loading: () => const Text('Yükleniyor...', style: TextStyle(color: AppColors.textMuted)),
            error: (e, __) => Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
            data: (cars) => bookingsAsync.when(
              loading: () => const SizedBox(),
              error: (e, s) => const SizedBox(),
              data: (bookings) {
                final totalCars = cars.length;
                final maintenanceCars = cars.where((c) => c['status'] == 'maintenance').length;
                final bookedCarIds = bookings.map((b) => b['car_id']).toSet();
                final bookedCars = bookedCarIds.length;
                final availableCars = totalCars - maintenanceCars - bookedCars;

                return Row(
                  children: [
                    _buildStatItem(Icons.directions_car, '$totalCars Araç', AppColors.textSecondary),
                    const SizedBox(width: 16),
                    _buildStatItem(Icons.event_busy, '$bookedCars Kirada', Colors.blue[400]!),
                    const SizedBox(width: 16),
                    _buildStatItem(Icons.build, '$maintenanceCars Bakımda', AppColors.warning),
                    const SizedBox(width: 16),
                    _buildStatItem(Icons.check_circle, '$availableCars Müsait', AppColors.success),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? AppColors.primary).withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? (color ?? AppColors.primary) : AppColors.textMuted,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? (color ?? AppColors.primary) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('d MMM', 'tr_TR');

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(selectedWeekStartProvider.notifier).state =
                  weekStart.subtract(const Duration(days: 7));
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(selectedWeekStartProvider.notifier).state =
                  weekStart.add(const Duration(days: 7));
            },
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {
              final now = DateTime.now();
              ref.read(selectedWeekStartProvider.notifier).state =
                  now.subtract(Duration(days: now.weekday - 1));
            },
            icon: const Icon(Icons.today, size: 18),
            label: const Text('Bugün'),
          ),
          const SizedBox(width: 24),
          // Legend - Rezervasyon Durumları
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('Durum: ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                _buildLegendItem(Colors.red[400]!, 'Aktif (Müşteride)'),
                const SizedBox(width: 12),
                _buildLegendItem(Colors.orange[400]!, 'Beklemede'),
                const SizedBox(width: 12),
                _buildLegendItem(Colors.green[400]!, 'Onaylandı'),
                const SizedBox(width: 12),
                _buildLegendItem(Colors.blue[400]!, 'Tamamlandı'),
                const SizedBox(width: 12),
                _buildLegendItem(AppColors.warning, 'Bakımda'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> cars,
    List<Map<String, dynamic>> bookings,
    DateTime weekStart,
    int totalCarCount,
  ) {
    if (cars.isEmpty) {
      return Center(
        child: Text(
          totalCarCount == 0 ? 'Henüz araç eklenmemiş' : 'Filtreye uygun araç bulunamadı',
        ),
      );
    }

    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dayFormat = DateFormat('EEE', 'tr_TR');
    final dateFormat = DateFormat('d', 'tr_TR');

    return SingleChildScrollView(
      child: Column(
        children: [
          // Day headers
          Container(
            color: AppColors.surface,
            child: Row(
              children: [
                // Car column header
                Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AppColors.surfaceLight),
                      bottom: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                  child: const Text(
                    'Araçlar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Day columns
                ...days.map((day) {
                  final isToday = _isSameDay(day, DateTime.now());
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.primary.withValues(alpha: 0.15) : null,
                        border: Border(
                          right: BorderSide(color: AppColors.surfaceLight),
                          bottom: BorderSide(color: AppColors.surfaceLight),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            dayFormat.format(day),
                            style: TextStyle(
                              fontSize: 12,
                              color: isToday ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                          Text(
                            dateFormat.format(day),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isToday ? AppColors.primary : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Car rows
          ...cars.map((car) => _buildCarRow(context, ref, car, bookings, days)),
        ],
      ),
    );
  }

  Widget _buildCarRow(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> car,
    List<Map<String, dynamic>> bookings,
    List<DateTime> days,
  ) {
    final carBookings = bookings.where((b) => b['car_id'] == car['id']).toList();
    final carStatus = car['status'] ?? 'available';
    final isMaintenance = carStatus == 'maintenance';
    final carId = car['id'] as String;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: Row(
        children: [
          // Car info
          Container(
            width: 180,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.surfaceLight)),
            ),
            child: Row(
              children: [
                if (isMaintenance)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.build, size: 16, color: AppColors.warning),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${car['brand']} ${car['model']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        car['plate'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Timeline cells
          ...days.map((day) {
            final isToday = _isSameDay(day, DateTime.now());
            final isSelected = _isDateInSelection(carId, day);

            // Find booking for this day
            final dayBooking = carBookings.cast<Map<String, dynamic>?>().firstWhere(
              (b) {
                if (b == null) return false;
                final pickupDate = DateTime.parse(b['pickup_date']);
                final dropoffDate = DateTime.parse(b['dropoff_date']);
                return !day.isBefore(pickupDate) && !day.isAfter(dropoffDate);
              },
              orElse: () => null,
            );

            final hasBooking = dayBooking != null;
            final canSelect = !isMaintenance && !hasBooking;

            return Expanded(
              child: Tooltip(
                message: dayBooking != null
                    ? '${dayBooking['customer_name'] ?? 'Müşteri'}\n${_getStatusText(dayBooking['status'])}\nDetay için tıklayın'
                    : isMaintenance
                        ? 'Araç bakımda'
                        : _isSelectingEndDate && _selectedCarId == carId
                            ? 'Bitiş tarihini seçmek için tıklayın'
                            : 'Başlangıç tarihini seçmek için tıklayın',
                preferBelow: true,
                waitDuration: const Duration(milliseconds: 300),
                child: MouseRegion(
                  cursor: canSelect ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  child: GestureDetector(
                    onTap: () => _handleCellTap(carId, day, canSelect, dayBooking),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : isMaintenance
                                ? AppColors.warning.withValues(alpha: 0.3)
                                : dayBooking != null
                                    ? _getBookingColor(dayBooking['status'])
                                    : isToday
                                        ? AppColors.primary.withValues(alpha: 0.1)
                                        : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 2)
                            : isToday
                                ? Border.all(color: AppColors.primary, width: 2)
                                : null,
                      ),
                      child: dayBooking != null
                          ? Center(
                              child: Text(
                                dayBooking['customer_name'] != null && (dayBooking['customer_name'] as String).length <= 10
                                    ? dayBooking['customer_name']
                                    : _getBookingInitials(dayBooking['customer_name']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            )
                          : isMaintenance
                              ? const Center(
                                  child: Icon(
                                    Icons.build,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                )
                              : isSelected
                                  ? Center(
                                      child: Icon(
                                        Icons.check,
                                        size: 16,
                                        color: AppColors.primary.withValues(alpha: 0.7),
                                      ),
                                    )
                                  : null,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getBookingColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.red[400]!;      // Aktif - Araç müşteride
      case 'pending':
        return Colors.orange[400]!;   // Beklemede - Onay bekliyor
      case 'confirmed':
        return Colors.green[400]!;    // Onaylandı - Hazır
      case 'completed':
        return Colors.blue[400]!;     // Tamamlandı
      case 'cancelled':
        return Colors.grey[400]!;     // İptal edildi
      default:
        return Colors.green[400]!;    // Varsayılan onaylandı
    }
  }

  String _getBookingInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'active':
        return 'Aktif (Araç Müşteride)';
      case 'pending':
        return 'Beklemede';
      case 'confirmed':
        return 'Onaylandı';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal Edildi';
      default:
        return status ?? '-';
    }
  }

  Future<void> _showCreateBookingDialog() async {
    if (_selectedRange == null || _selectedCarId == null) return;

    final (startDate, endDate) = _selectedRange!;

    // Get all cars for the dialog (including the selected one)
    final carsAsync = ref.read(calendarCarsProvider);
    List<Map<String, dynamic>> availableCars = [];

    carsAsync.whenData((cars) {
      // Get the selected car first
      final selectedCar = cars.firstWhere(
        (c) => c['id'] == _selectedCarId,
        orElse: () => <String, dynamic>{},
      );
      if (selectedCar.isNotEmpty) {
        availableCars = [selectedCar];
      }
    });

    if (availableCars.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seçili araç bulunamadı'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show the ManualBookingDialog from bookings_screen.dart
    showDialog(
      context: context,
      builder: (dialogContext) => _CalendarBookingDialog(
        selectedCar: availableCars.first,
        startDate: startDate,
        endDate: endDate,
        onSave: (bookingData) async {
          try {
            final client = ref.read(supabaseClientProvider);
            final companyId = await ref.read(companyIdProvider.future);

            // Generate booking number
            final bookingNumber = 'CL-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

            // Create booking
            await client.from('rental_bookings').insert({
              ...bookingData,
              'company_id': companyId,
              'booking_number': bookingNumber,
              'status': 'confirmed',
              'net_amount': bookingData['total_amount'],
            });

            // Refresh data
            ref.invalidate(weekBookingsProvider);
            ref.invalidate(calendarCarsProvider);

            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
            }

            // Reset selection
            _clearSelection();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rezervasyon başarıyla oluşturuldu'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text('Hata: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
        onCancel: () {
          _clearSelection();
        },
      ),
    );
  }
}

// Calendar specific booking dialog - uses selected car and dates from calendar
class _CalendarBookingDialog extends StatefulWidget {
  final Map<String, dynamic> selectedCar;
  final DateTime startDate;
  final DateTime endDate;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const _CalendarBookingDialog({
    required this.selectedCar,
    required this.startDate,
    required this.endDate,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_CalendarBookingDialog> createState() => _CalendarBookingDialogState();
}

class _CalendarBookingDialogState extends State<_CalendarBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _licenseNoController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _pickupDate;
  late DateTime _dropoffDate;
  TimeOfDay _pickupTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _dropoffTime = const TimeOfDay(hour: 18, minute: 0);
  String _paymentStatus = 'pending';
  String _paymentMethod = 'cash';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pickupDate = widget.startDate;
    _dropoffDate = widget.endDate;
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _licenseNoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _rentalDays {
    return _dropoffDate.difference(_pickupDate).inDays + 1;
  }

  double get _totalAmount {
    final dailyPrice = (widget.selectedCar['daily_price'] as num?)?.toDouble() ?? 0;
    return dailyPrice * _rentalDays;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFormat = DateFormat('dd MMM yyyy');
    final dailyPrice = (widget.selectedCar['daily_price'] as num?)?.toDouble() ?? 0;

    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.calendar_month, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Takvimden Rezervasyon',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onCancel();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seçtiğiniz tarih aralığı için rezervasyon oluşturun',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Seçili Araç (sabit - değiştirilemez)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.selectedCar['brand']} ${widget.selectedCar['model']}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${widget.selectedCar['plate']} • ${formatter.format(dailyPrice)}/gün',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Seçili Araç',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Teslim Alma Tarihi ve Saati
                const Text(
                  'Teslim Alma',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _pickupDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _pickupDate = date;
                              if (_dropoffDate.isBefore(_pickupDate)) {
                                _dropoffDate = _pickupDate.add(const Duration(days: 1));
                              }
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tarih',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(dateFormat.format(_pickupDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _pickupTime,
                          );
                          if (time != null) {
                            setState(() => _pickupTime = time);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Saat',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(_pickupTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Teslim Tarihi ve Saati
                const Text(
                  'Teslim',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dropoffDate,
                            firstDate: _pickupDate,
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _dropoffDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tarih',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(dateFormat.format(_dropoffDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _dropoffTime,
                          );
                          if (time != null) {
                            setState(() => _dropoffTime = time);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Saat',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(_dropoffTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Müşteri Bilgileri
                const Text(
                  'Müşteri Bilgileri',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Ad Soyad *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _customerPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefon *',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customerEmailController,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _licenseNoController,
                        decoration: const InputDecoration(
                          labelText: 'Ehliyet No',
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ödeme
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paymentStatus,
                        decoration: const InputDecoration(
                          labelText: 'Ödeme Durumu',
                          prefixIcon: Icon(Icons.payment),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
                          DropdownMenuItem(value: 'paid', child: Text('Ödendi')),
                          DropdownMenuItem(value: 'partial', child: Text('Kısmi Ödeme')),
                        ],
                        onChanged: (v) => setState(() => _paymentStatus = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Ödeme Yöntemi',
                          prefixIcon: Icon(Icons.account_balance_wallet),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Nakit')),
                          DropdownMenuItem(value: 'credit_card', child: Text('Kredi Kartı')),
                          DropdownMenuItem(value: 'bank_transfer', child: Text('Havale/EFT')),
                        ],
                        onChanged: (v) => setState(() => _paymentMethod = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notlar
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notlar',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Özet
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_rentalDays gün',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatter.format(_totalAmount),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.receipt_long,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onCancel();
                      },
                      child: const Text('İptal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _save,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Rezervasyon Oluştur'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final dailyPrice = (widget.selectedCar['daily_price'] as num?)?.toDouble() ?? 0;

    // Combine date and time
    final pickupDateTime = DateTime(
      _pickupDate.year,
      _pickupDate.month,
      _pickupDate.day,
      _pickupTime.hour,
      _pickupTime.minute,
    );
    final dropoffDateTime = DateTime(
      _dropoffDate.year,
      _dropoffDate.month,
      _dropoffDate.day,
      _dropoffTime.hour,
      _dropoffTime.minute,
    );

    widget.onSave({
      'car_id': widget.selectedCar['id'],
      'pickup_date': pickupDateTime.toIso8601String(),
      'dropoff_date': dropoffDateTime.toIso8601String(),
      'daily_rate': dailyPrice,
      'rental_days': _rentalDays,
      'subtotal': _totalAmount,
      'total_amount': _totalAmount,
      'customer_name': _customerNameController.text.trim(),
      'customer_phone': _customerPhoneController.text.trim(),
      'customer_email': _customerEmailController.text.trim().isEmpty
          ? null
          : _customerEmailController.text.trim(),
      'driver_license_no': _licenseNoController.text.trim().isEmpty
          ? null
          : _licenseNoController.text.trim(),
      'company_notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'payment_status': _paymentStatus,
      'payment_method': _paymentMethod,
    });
  }
}
