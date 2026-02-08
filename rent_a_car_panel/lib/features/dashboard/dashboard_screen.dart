import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// ── Providers ──────────────────────────────────────────────────────────

final dashboardStatsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);
  if (companyId == null) {
    return {
      'totalCars': 0,
      'availableCars': 0,
      'rentedCars': 0,
      'maintenanceCars': 0,
      'pendingBookings': 0,
      'activeBookings': 0,
      'monthlyRevenue': 0.0,
      'totalRevenue': 0.0,
      'utilizationRate': 0.0,
      'avgRentalDays': 0.0,
    };
  }

  final carsResponse = await client
      .from('rental_cars')
      .select('status')
      .eq('company_id', companyId);

  final totalCars = carsResponse.length;
  final availableCars =
      carsResponse.where((c) => c['status'] == 'available').length;
  final rentedCars =
      carsResponse.where((c) => c['status'] == 'rented').length;
  final maintenanceCars =
      carsResponse.where((c) => c['status'] == 'maintenance').length;

  final bookingsResponse = await client
      .from('rental_bookings')
      .select('status, total_amount, rental_days, created_at')
      .eq('company_id', companyId);

  final pendingBookings =
      bookingsResponse.where((b) => b['status'] == 'pending').length;
  final activeBookings =
      bookingsResponse.where((b) => b['status'] == 'active').length;

  double totalRevenue = 0;
  double monthlyRevenue = 0;
  int completedCount = 0;
  int totalRentalDays = 0;
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  for (final booking in bookingsResponse) {
    if (booking['status'] == 'completed') {
      final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0;
      totalRevenue += amount;
      completedCount++;
      totalRentalDays += (booking['rental_days'] as num?)?.toInt() ?? 0;

      final createdAt = DateTime.tryParse(booking['created_at'] ?? '');
      if (createdAt != null && createdAt.isAfter(startOfMonth)) {
        monthlyRevenue += amount;
      }
    }
  }

  final utilizationRate =
      totalCars > 0 ? (rentedCars / totalCars) * 100 : 0.0;
  final avgRentalDays =
      completedCount > 0 ? totalRentalDays / completedCount : 0.0;

  return {
    'totalCars': totalCars,
    'availableCars': availableCars,
    'rentedCars': rentedCars,
    'maintenanceCars': maintenanceCars,
    'pendingBookings': pendingBookings,
    'activeBookings': activeBookings,
    'monthlyRevenue': monthlyRevenue,
    'totalRevenue': totalRevenue,
    'utilizationRate': utilizationRate,
    'avgRentalDays': avgRentalDays,
  };
});

final todayPickupsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);
  if (companyId == null) return <Map<String, dynamic>>[];

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final response = await client
      .from('rental_bookings')
      .select(
          '*, rental_cars(brand, model, plate, image_url), pickup_location:rental_locations!pickup_location_id(name)')
      .eq('company_id', companyId)
      .eq('status', 'confirmed')
      .gte('pickup_date', '${today}T00:00:00')
      .lt('pickup_date', '${today}T23:59:59')
      .order('pickup_date');

  return List<Map<String, dynamic>>.from(response);
});

final todayReturnsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);
  if (companyId == null) return <Map<String, dynamic>>[];

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final response = await client
      .from('rental_bookings')
      .select(
          '*, rental_cars(brand, model, plate, image_url), dropoff_location:rental_locations!dropoff_location_id(name)')
      .eq('company_id', companyId)
      .eq('status', 'active')
      .gte('dropoff_date', '${today}T00:00:00')
      .lt('dropoff_date', '${today}T23:59:59')
      .order('dropoff_date');

  return List<Map<String, dynamic>>.from(response);
});

final overdueReturnsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);
  if (companyId == null) return <Map<String, dynamic>>[];

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final response = await client
      .from('rental_bookings')
      .select(
          '*, rental_cars(brand, model, plate, image_url), dropoff_location:rental_locations!dropoff_location_id(name)')
      .eq('company_id', companyId)
      .eq('status', 'active')
      .lt('dropoff_date', '${today}T00:00:00')
      .order('dropoff_date');

  return List<Map<String, dynamic>>.from(response);
});

final upcomingEventsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);
  if (companyId == null) return <Map<String, dynamic>>[];

  final now = DateTime.now();
  final today = DateFormat('yyyy-MM-dd').format(now);
  final nextWeek =
      DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 7)));

  // Upcoming pickups
  final pickups = await client
      .from('rental_bookings')
      .select('id, pickup_date, customer_name, status, rental_cars(brand, model)')
      .eq('company_id', companyId)
      .inFilter('status', ['confirmed'])
      .gte('pickup_date', '${today}T00:00:00')
      .lt('pickup_date', '${nextWeek}T23:59:59')
      .order('pickup_date');

  // Upcoming returns
  final returns = await client
      .from('rental_bookings')
      .select('id, dropoff_date, customer_name, status, rental_cars(brand, model)')
      .eq('company_id', companyId)
      .inFilter('status', ['active', 'confirmed'])
      .gte('dropoff_date', '${today}T00:00:00')
      .lt('dropoff_date', '${nextWeek}T23:59:59')
      .order('dropoff_date');

  final events = <Map<String, dynamic>>[];
  for (final p in pickups) {
    events.add({...p, '_type': 'pickup', '_date': p['pickup_date']});
  }
  for (final r in returns) {
    events.add({...r, '_type': 'return', '_date': r['dropoff_date']});
  }
  events.sort((a, b) =>
      (a['_date'] as String).compareTo(b['_date'] as String));

  return events;
});

final recentBookingsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);
  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_bookings')
      .select('*, rental_cars(brand, model, image_url)')
      .eq('company_id', companyId)
      .order('created_at', ascending: false)
      .limit(5);

  return List<Map<String, dynamic>>.from(response);
});

final monthlyRevenueChartProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);
  if (companyId == null) return <Map<String, double>>{};

  final now = DateTime.now();
  final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

  final response = await client
      .from('rental_bookings')
      .select('total_amount, created_at')
      .eq('company_id', companyId)
      .eq('status', 'completed')
      .gte('created_at', sixMonthsAgo.toIso8601String());

  final monthlyData = <String, double>{};
  for (int i = 0; i < 6; i++) {
    final month = DateTime(now.year, now.month - 5 + i, 1);
    final key = DateFormat('yyyy-MM').format(month);
    monthlyData[key] = 0;
  }

  for (final booking in response) {
    final createdAt = DateTime.tryParse(booking['created_at'] ?? '');
    if (createdAt != null) {
      final key = DateFormat('yyyy-MM').format(createdAt);
      if (monthlyData.containsKey(key)) {
        monthlyData[key] =
            monthlyData[key]! + ((booking['total_amount'] as num?)?.toDouble() ?? 0);
      }
    }
  }

  return monthlyData;
});

// ── Dashboard Screen ───────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(todayPickupsProvider);
    ref.invalidate(todayReturnsProvider);
    ref.invalidate(overdueReturnsProvider);
    ref.invalidate(upcomingEventsProvider);
    ref.invalidate(recentBookingsProvider);
    ref.invalidate(monthlyRevenueChartProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final pickupsAsync = ref.watch(todayPickupsProvider);
    final returnsAsync = ref.watch(todayReturnsProvider);
    final overdueAsync = ref.watch(overdueReturnsProvider);
    final upcomingAsync = ref.watch(upcomingEventsProvider);
    final bookingsAsync = ref.watch(recentBookingsProvider);
    final revenueAsync = ref.watch(monthlyRevenueChartProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => _invalidateAll(ref),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              _buildHeader(context),
              const SizedBox(height: 20),

              // ── Bölüm 1: Aksiyon Kartları ──
              statsAsync.when(
                data: (stats) => _buildActionCards(
                  context,
                  stats,
                  pickupsAsync.valueOrNull ?? [],
                  returnsAsync.valueOrNull ?? [],
                  overdueAsync.valueOrNull ?? [],
                ),
                loading: () => const _LoadingRow(),
                error: (e, _) => _ErrorText(e),
              ),
              const SizedBox(height: 20),

              // ── Bölüm 2: Mini Stats ──
              statsAsync.when(
                data: (stats) => _buildMiniStats(stats),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 20),

              // ── Bölüm 3: Timeline + Filo Durumu ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: upcomingAsync.when(
                      data: (events) =>
                          _buildUpcomingTimeline(context, events),
                      loading: () => const _LoadingCard(height: 350),
                      error: (e, _) => _ErrorText(e),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: statsAsync.when(
                      data: (stats) => _buildFleetStatus(context, stats),
                      loading: () => const _LoadingCard(height: 350),
                      error: (e, _) => _ErrorText(e),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Bölüm 4: Bugünkü Teslimler / İadeler ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: pickupsAsync.when(
                      data: (pickups) =>
                          _buildTodayPickups(context, ref, pickups),
                      loading: () => const _LoadingCard(height: 280),
                      error: (e, _) => _ErrorText(e),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: returnsAsync.when(
                      data: (returns) =>
                          _buildTodayReturns(context, ref, returns),
                      loading: () => const _LoadingCard(height: 280),
                      error: (e, _) => _ErrorText(e),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Bölüm 5: Gelir Grafiği + Son Rezervasyonlar ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: revenueAsync.when(
                      data: (data) => _buildRevenueChart(Map<String, double>.from(data as Map)),
                      loading: () => const _LoadingCard(height: 300),
                      error: (e, _) => _ErrorText(e),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: bookingsAsync.when(
                      data: (bookings) =>
                          _buildRecentBookings(context, bookings),
                      loading: () => const _LoadingCard(height: 300),
                      error: (e, _) => _ErrorText(e),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now()),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/cars'),
          icon: const Icon(Icons.add),
          label: const Text('Yeni Arac Ekle'),
        ),
      ],
    );
  }

  // ── Bölüm 1: Aksiyon Kartları ──

  Widget _buildActionCards(
    BuildContext context,
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> pickups,
    List<Map<String, dynamic>> returns,
    List<Map<String, dynamic>> overdue,
  ) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ActionCard(
          title: 'Onay Bekleyen',
          count: stats['pendingBookings'] as int,
          icon: Icons.pending_actions,
          color: AppColors.warning,
          actionLabel: 'Goruntule',
          onAction: () => context.go('/bookings'),
        ),
        _ActionCard(
          title: 'Bugun Teslim',
          count: pickups.length,
          icon: Icons.login,
          color: AppColors.info,
          actionLabel: 'Detaylar',
          onAction: pickups.isEmpty ? null : () => context.go('/bookings'),
        ),
        _ActionCard(
          title: 'Bugun Iade',
          count: returns.length,
          icon: Icons.logout,
          color: AppColors.success,
          actionLabel: 'Detaylar',
          onAction: returns.isEmpty ? null : () => context.go('/bookings'),
        ),
        _ActionCard(
          title: 'Geciken Iade',
          count: overdue.length,
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          actionLabel: 'Incele',
          onAction: overdue.isEmpty ? null : () => context.go('/bookings'),
          urgent: overdue.isNotEmpty,
        ),
      ],
    );
  }

  // ── Bölüm 2: Mini Stats ──

  Widget _buildMiniStats(Map<String, dynamic> stats) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final utilizationRate = (stats['utilizationRate'] as num).toDouble();
    final avgDays = (stats['avgRentalDays'] as num).toDouble();

    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Filo Doluluk',
            value: '%${utilizationRate.toStringAsFixed(0)}',
            icon: Icons.pie_chart_outline,
            color: utilizationRate > 70
                ? AppColors.success
                : utilizationRate > 40
                    ? AppColors.warning
                    : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatCard(
            label: 'Bakimdaki Arac',
            value: '${stats['maintenanceCars']}',
            icon: Icons.build_outlined,
            color: (stats['maintenanceCars'] as int) > 0
                ? AppColors.warning
                : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatCard(
            label: 'Bu Ay Gelir',
            value: formatter.format(stats['monthlyRevenue']),
            icon: Icons.trending_up,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatCard(
            label: 'Ort. Kiralama',
            value: '${avgDays.toStringAsFixed(1)} gun',
            icon: Icons.access_time,
            color: AppColors.info,
          ),
        ),
      ],
    );
  }

  // ── Bölüm 3a: Yaklaşan Etkinlikler Timeline ──

  Widget _buildUpcomingTimeline(
      BuildContext context, List<Map<String, dynamic>> events) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Onumuzdeki 7 Gun',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${events.length} etkinlik',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_available,
                          size: 40, color: AppColors.textMuted),
                      SizedBox(height: 8),
                      Text('Yaklasan etkinlik yok',
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              )
            else
              ...() {
                // Group by date
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final e in events) {
                  final date = (e['_date'] as String).substring(0, 10);
                  grouped.putIfAbsent(date, () => []).add(e);
                }
                return grouped.entries.take(7).map((entry) {
                  final dateStr = entry.key;
                  final dateObj = DateTime.tryParse(dateStr);
                  final dayLabel = dateObj != null
                      ? DateFormat('dd MMM, EEEE', 'tr_TR').format(dateObj)
                      : dateStr;
                  final isToday = dateStr ==
                      DateFormat('yyyy-MM-dd').format(DateTime.now());

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isToday ? 'Bugun' : dayLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isToday
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...entry.value.map((e) {
                        final car =
                            e['rental_cars'] as Map<String, dynamic>?;
                        final isPickup = e['_type'] == 'pickup';
                        final time = _extractTime(
                            e[isPickup ? 'pickup_date' : 'dropoff_date']);

                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              context.go('/bookings/${e['id']}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: (isPickup
                                            ? AppColors.info
                                            : AppColors.success)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isPickup ? Icons.login : Icons.logout,
                                    size: 16,
                                    color: isPickup
                                        ? AppColors.info
                                        : AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e['customer_name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        car != null
                                            ? '${car['brand']} ${car['model']}'
                                            : '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isPickup
                                            ? AppColors.info
                                            : AppColors.success)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isPickup ? 'Teslim' : 'Iade',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isPickup
                                          ? AppColors.info
                                          : AppColors.success,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right,
                                    size: 16, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 1),
                    ],
                  );
                }).toList();
              }(),
          ],
        ),
      ),
    );
  }

  // ── Bölüm 3b: Filo Durumu ──

  Widget _buildFleetStatus(
      BuildContext context, Map<String, dynamic> stats) {
    final total = stats['totalCars'] as int;
    final available = stats['availableCars'] as int;
    final rented = stats['rentedCars'] as int;
    final maintenance = stats['maintenanceCars'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filo Durumu',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/cars'),
                  child: const Text('Tumu',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Horizontal stacked bar
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      if (available > 0)
                        Expanded(
                          flex: available,
                          child: Container(
                            color: AppColors.success,
                            alignment: Alignment.center,
                            child: available > 0
                                ? Text('$available',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))
                                : null,
                          ),
                        ),
                      if (rented > 0)
                        Expanded(
                          flex: rented,
                          child: Container(
                            color: AppColors.info,
                            alignment: Alignment.center,
                            child: Text('$rented',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ),
                      if (maintenance > 0)
                        Expanded(
                          flex: maintenance,
                          child: Container(
                            color: AppColors.warning,
                            alignment: Alignment.center,
                            child: Text('$maintenance',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem('Musait', AppColors.success),
                  _buildLegendItem('Kirada', AppColors.info),
                  _buildLegendItem('Bakim', AppColors.warning),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Henuz arac eklenmedi',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            // Fleet detail cards
            _FleetDetailRow(
              icon: Icons.check_circle_outline,
              label: 'Musait Araclar',
              count: available,
              color: AppColors.success,
            ),
            const SizedBox(height: 8),
            _FleetDetailRow(
              icon: Icons.car_rental,
              label: 'Kirada Olan',
              count: rented,
              color: AppColors.info,
            ),
            const SizedBox(height: 8),
            _FleetDetailRow(
              icon: Icons.build_circle_outlined,
              label: 'Bakimda',
              count: maintenance,
              color: AppColors.warning,
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _FleetDetailRow(
              icon: Icons.directions_car,
              label: 'Toplam Filo',
              count: total,
              color: AppColors.textSecondary,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── Bölüm 4a: Bugünkü Teslimler ──

  Widget _buildTodayPickups(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> pickups) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.login,
                      size: 18, color: AppColors.info),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Bugunku Teslimler',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (pickups.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${pickups.length}',
                        style: const TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (pickups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Bugun teslim yok',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ...pickups.map((booking) {
                final car =
                    booking['rental_cars'] as Map<String, dynamic>?;
                final location =
                    booking['pickup_location'] as Map<String, dynamic>?;
                final time = _extractTime(booking['pickup_date']);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // Car image
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: car?['image_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(car!['image_url'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.directions_car,
                                              color: AppColors.textMuted,
                                              size: 20)),
                                )
                              : const Icon(Icons.directions_car,
                                  color: AppColors.textMuted, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking['customer_name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              Text(
                                '${car?['brand'] ?? ''} ${car?['model'] ?? ''} - ${car?['plate'] ?? ''}',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 11, color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text(time,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted)),
                                  if (location != null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.location_on,
                                        size: 11,
                                        color: AppColors.textMuted),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        location['name'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () =>
                                _deliverCar(context, ref, booking),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: const Text('Teslim Et'),
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
    );
  }

  // ── Bölüm 4b: Bugünkü İadeler ──

  Widget _buildTodayReturns(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> returns) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout,
                      size: 18, color: AppColors.success),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Bugunku Iadeler',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (returns.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${returns.length}',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (returns.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Bugun iade yok',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ...returns.map((booking) {
                final car =
                    booking['rental_cars'] as Map<String, dynamic>?;
                final location =
                    booking['dropoff_location'] as Map<String, dynamic>?;
                final time = _extractTime(booking['dropoff_date']);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: car?['image_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(car!['image_url'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.directions_car,
                                              color: AppColors.textMuted,
                                              size: 20)),
                                )
                              : const Icon(Icons.directions_car,
                                  color: AppColors.textMuted, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking['customer_name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              Text(
                                '${car?['brand'] ?? ''} ${car?['model'] ?? ''} - ${car?['plate'] ?? ''}',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 11, color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text(time,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted)),
                                  if (location != null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.location_on,
                                        size: 11,
                                        color: AppColors.textMuted),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        location['name'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () =>
                                _receiveCar(context, ref, booking),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: const Text('Teslim Al'),
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
    );
  }

  // ── Bölüm 5a: Gelir Grafiği ──

  Widget _buildRevenueChart(Map<String, double> data) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Gelir Grafigi',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 60),
              Center(
                  child: Text('Veri yok',
                      style: TextStyle(color: AppColors.textMuted))),
            ],
          ),
        ),
      );
    }

    final entries = data.entries.toList();
    final maxValue = data.values.fold<double>(0, (a, b) => a > b ? a : b);
    final interval =
        maxValue > 0 ? (maxValue / 4).ceilToDouble() : 10000.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gelir Grafigi',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'Son 6 ay',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.surfaceLight,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: interval,
                        getTitlesWidget: (value, meta) => Text(
                          '${(value / 1000).toStringAsFixed(0)}K',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < entries.length) {
                            final month =
                                DateTime.tryParse('${entries[idx].key}-01');
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                month != null
                                    ? DateFormat('MMM', 'tr_TR')
                                        .format(month)
                                    : '',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: entries.asMap().entries.map((e) {
                        return FlSpot(
                            e.key.toDouble(), e.value.value);
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bölüm 5b: Son Rezervasyonlar ──

  Widget _buildRecentBookings(
      BuildContext context, List<Map<String, dynamic>> bookings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Son Rezervasyonlar',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => context.go('/bookings'),
                  child: const Text('Tumunu Gor',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (bookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: Text('Henuz rezervasyon yok',
                        style: TextStyle(color: AppColors.textMuted))),
              )
            else
              ...bookings.map((booking) {
                final car =
                    booking['rental_cars'] as Map<String, dynamic>?;
                final createdAt =
                    DateTime.tryParse(booking['created_at'] ?? '');

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      context.go('/bookings/${booking['id']}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: car?['image_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(car!['image_url'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.directions_car,
                                              color: AppColors.textMuted,
                                              size: 18)),
                                )
                              : const Icon(Icons.directions_car,
                                  color: AppColors.textMuted, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                car != null
                                    ? '${car['brand']} ${car['model']}'
                                    : 'Arac',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              Text(
                                booking['customer_name'] ?? '',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStatusBadge(
                                booking['status'] ?? ''),
                            if (createdAt != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 2),
                                child: Text(
                                  DateFormat('dd MMM HH:mm')
                                      .format(createdAt),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Beklemede';
      case 'confirmed':
        color = AppColors.info;
        label = 'Onaylandi';
      case 'active':
        color = AppColors.success;
        label = 'Aktif';
      case 'completed':
        color = AppColors.secondary;
        label = 'Tamamlandi';
      case 'cancelled':
        color = AppColors.error;
        label = 'Iptal';
      default:
        color = AppColors.textMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _extractTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return DateFormat('HH:mm').format(dt);
  }

  // ── Actions ──

  Future<void> _deliverCar(
      BuildContext context, WidgetRef ref, Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Araci Teslim Et'),
        content: Text(
            '${booking['customer_name']} adina araci teslim etmek istediginize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Iptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Teslim Et')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('rental_bookings')
          .update({'status': 'active', 'actual_pickup_date': DateTime.now().toIso8601String()})
          .eq('id', booking['id']);
      await client
          .from('rental_cars')
          .update({'status': 'rented'})
          .eq('id', booking['car_id']);

      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Arac teslim edildi'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _receiveCar(
      BuildContext context, WidgetRef ref, Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Araci Teslim Al'),
        content: Text(
            '${booking['customer_name']} adina araci teslim almak istediginize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Iptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success),
              child: const Text('Teslim Al')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('rental_bookings')
          .update({
            'status': 'completed',
            'actual_dropoff_date': DateTime.now().toIso8601String(),
          })
          .eq('id', booking['id']);
      await client
          .from('rental_cars')
          .update({'status': 'available'})
          .eq('id', booking['car_id']);

      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Arac teslim alindi'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// ── Reusable Widgets ─────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool urgent;

  const _ActionCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.actionLabel,
    this.onAction,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: urgent
            ? BorderSide(color: color.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onAction,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (count > 0 && onAction != null)
                    Text(actionLabel,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text('$count',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: count > 0 ? color : AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool bold;

  const _FleetDetailRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
        Text('$count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: bold ? AppColors.textPrimary : color,
            )),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 100,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final Object error;
  const _ErrorText(this.error);
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Hata: $error', style: const TextStyle(color: AppColors.error)));
  }
}
