import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/taxi_service.dart';
import '../../core/theme/app_theme.dart';

// All rides provider
final allRidesProvider = FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final active = await TaxiService.getActiveRides();
  final completed = await TaxiService.getCompletedRides();
  return {
    'active': active,
    'completed': completed,
  };
});

class RidesScreen extends ConsumerWidget {
  const RidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(allRidesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Yolculuklarım'),
          bottom: TabBar(
            labelColor: AppColors.secondary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Aktif'),
              Tab(text: 'Tamamlanan'),
            ],
          ),
        ),
        body: ridesAsync.when(
          data: (rides) => TabBarView(
            children: [
              _buildRidesList(context, rides['active'] ?? [], isActive: true),
              _buildRidesList(context, rides['completed'] ?? [], isActive: false),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Hata: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(allRidesProvider),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRidesList(BuildContext context, List<Map<String, dynamic>> rides, {required bool isActive}) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.local_taxi : Icons.check_circle_outline,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Aktif yolculuk yok' : 'Tamamlanan yolculuk yok',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (context, index) => _buildRideCard(context, rides[index], isActive),
    );
  }

  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride, bool isActive) {
    final customer = ride['customers'] as Map<String, dynamic>?;
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final status = ride['status'] as String? ?? '';

    Color statusColor;
    String statusText;

    switch (status) {
      case 'accepted':
        statusColor = AppColors.info;
        statusText = 'Kabul Edildi';
        break;
      case 'arrived':
        statusColor = AppColors.warning;
        statusText = 'Varıldı';
        break;
      case 'in_progress':
        statusColor = AppColors.primary;
        statusText = 'Yolda';
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusText = 'Tamamlandı';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/rides/${ride['id']}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isActive ? Icons.local_taxi : Icons.check_circle,
                        color: isActive ? AppColors.secondary : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer?['full_name'] ?? 'Yolcu',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            ride['ride_number'] ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₺${fare.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Addresses
                Row(
                  children: [
                    Icon(Icons.trip_origin, size: 14, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride['pickup_address'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride['dropoff_address'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (isActive) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/rides/${ride['id']}'),
                      child: const Text('Detayları Gör'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
