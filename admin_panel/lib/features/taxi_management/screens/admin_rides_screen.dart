import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/taxi_management_providers.dart';

class AdminRidesScreen extends ConsumerStatefulWidget {
  final String driverId;
  const AdminRidesScreen({super.key, required this.driverId});

  @override
  ConsumerState<AdminRidesScreen> createState() => _AdminRidesScreenState();
}

class _AdminRidesScreenState extends ConsumerState<AdminRidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _daysFilter = 30;
  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '\u20BA',
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('dd MMM yyyy HH:mm', 'tr');

  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': 'Tümü'},
    {'key': 'completed', 'label': 'Tamamlanan'},
    {'key': 'cancelled', 'label': 'İptal'},
    {'key': 'in_progress', 'label': 'Devam Eden'},
  ];

  final List<Map<String, dynamic>> _dateRanges = [
    {'label': 'Bugün', 'days': 1},
    {'label': 'Bu Hafta', 'days': 7},
    {'label': 'Bu Ay', 'days': 30},
    {'label': 'Son 3 Ay', 'days': 90},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentStatus => _tabs[_tabController.index]['key']!;

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(
      driverRidesProvider((
        driverId: widget.driverId,
        status: _currentStatus,
        days: _daysFilter,
      )),
    );

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
                      'Seferler',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sürücünün tüm seferlerini görüntüleyin.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                  onPressed: () => ref.invalidate(driverRidesProvider),
                  tooltip: 'Yenile',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Cards
            ridesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (rides) => _buildSummaryCards(rides),
            ),
            const SizedBox(height: 20),

            // Date range quick buttons
            Row(
              children: [
                ..._dateRanges.map((range) {
                  final isSelected = _daysFilter == range['days'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        range['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _daysFilter = range['days'] as int;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Status Tabs
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: Colors.transparent,
                tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Rides List
            Expanded(
              child: ridesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Hata: $e', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                data: (rides) {
                  if (rides.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_taxi_outlined, size: 64, color: AppColors.textSecondary),
                          SizedBox(height: 16),
                          Text(
                            'Bu dönemde sefer bulunamadı.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      return _buildRideCard(rides[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> rides) {
    final totalRides = rides.length;
    double totalDistance = 0;
    double totalFare = 0;
    int cancelledCount = 0;

    for (final ride in rides) {
      totalDistance += (ride['distance_km'] as num?)?.toDouble() ?? 0;
      totalFare += (ride['fare'] as num?)?.toDouble() ?? 0;
      if (ride['status'] == 'cancelled') {
        cancelledCount++;
      }
    }

    final avgFare = totalRides > 0 ? totalFare / totalRides : 0.0;
    final cancelRate = totalRides > 0 ? (cancelledCount / totalRides * 100) : 0.0;

    return Row(
      children: [
        _buildSummaryCard(
          'Toplam Sefer',
          '$totalRides',
          Icons.local_taxi,
          AppColors.info,
        ),
        const SizedBox(width: 12),
        _buildSummaryCard(
          'Toplam Mesafe',
          '${totalDistance.toStringAsFixed(1)} km',
          Icons.route,
          AppColors.success,
        ),
        const SizedBox(width: 12),
        _buildSummaryCard(
          'Ortalama Ücret',
          _currencyFormat.format(avgFare),
          Icons.payments,
          AppColors.warning,
        ),
        const SizedBox(width: 12),
        _buildSummaryCard(
          'İptal Oranı',
          '%${cancelRate.toStringAsFixed(1)}',
          Icons.cancel_outlined,
          AppColors.error,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final createdAt = ride['created_at'] != null
        ? DateTime.parse(ride['created_at']).toLocal()
        : DateTime.now();
    final pickup = ride['pickup_address'] ?? ride['pickup_location'] ?? 'Bilinmiyor';
    final dropoff = ride['dropoff_address'] ?? ride['dropoff_location'] ?? 'Bilinmiyor';
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final tip = (ride['tip_amount'] as num?)?.toDouble() ?? 0;
    final distance = (ride['distance_km'] as num?)?.toDouble() ?? 0;
    final duration = (ride['duration_minutes'] as num?)?.toInt() ?? 0;
    final status = ride['status'] ?? 'unknown';
    final timeAgo = _getTimeAgo(createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showRideDetailDialog(ride),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              // Route icon
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: AppColors.surfaceLight,
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.error, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Addresses
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickup.toString(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dropoff.toString(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
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
              const SizedBox(width: 16),

              // Fare + Tip
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(fare),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (tip > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '+${_currencyFormat.format(tip)} bahşiş',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 16),

              // Distance & Duration
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '$duration dk',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Status badge
              _buildStatusChip(status),
              const SizedBox(width: 12),

              // Time ago
              SizedBox(
                width: 70,
                child: Text(
                  timeAgo,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRideDetailDialog(Map<String, dynamic> ride) {
    final pickup = ride['pickup_address'] ?? ride['pickup_location'] ?? 'Bilinmiyor';
    final dropoff = ride['dropoff_address'] ?? ride['dropoff_location'] ?? 'Bilinmiyor';
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final tip = (ride['tip_amount'] as num?)?.toDouble() ?? 0;
    final distance = (ride['distance_km'] as num?)?.toDouble() ?? 0;
    final duration = (ride['duration_minutes'] as num?)?.toInt() ?? 0;
    final status = ride['status'] ?? 'unknown';
    final customerName = ride['customer_name'] as String? ?? 'Bilinmiyor';
    final createdAt = ride['created_at'] != null
        ? DateTime.parse(ride['created_at']).toLocal()
        : DateTime.now();
    final completedAt = ride['completed_at'] != null
        ? DateTime.parse(ride['completed_at']).toLocal()
        : null;
    final vehicleType = ride['vehicle_type'] ?? 'standard';

    // Fare breakdown estimates
    final baseFare = (ride['base_fare'] as num?)?.toDouble() ?? fare * 0.3;
    final distanceFare = (ride['distance_fare'] as num?)?.toDouble() ?? fare * 0.5;
    final timeFare = (ride['time_fare'] as num?)?.toDouble() ?? fare * 0.2;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 550,
            constraints: const BoxConstraints(maxHeight: 680),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_taxi, color: AppColors.primary, size: 24),
                            const SizedBox(width: 8),
                            const Text(
                              'Sefer Detayı',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildStatusChip(status),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Map placeholder
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.map_outlined, size: 40, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'Rota Haritası',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // Route overlay
                          Positioned(
                            left: 40,
                            top: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 8, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text('Başlangıç', style: TextStyle(color: AppColors.success, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 40,
                            bottom: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 8, color: AppColors.error),
                                  const SizedBox(width: 4),
                                  Text('Bitiş', style: TextStyle(color: AppColors.error, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                          // Dotted line between points
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _RoutePlaceholderPainter(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pickup / Dropoff
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Alış Noktası', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text(
                                      pickup.toString(),
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Column(
                              children: List.generate(3, (_) {
                                return Container(
                                  width: 2,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  color: AppColors.surfaceLight,
                                );
                              }),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Varış Noktası', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text(
                                      dropoff.toString(),
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Customer info
                    _buildDetailSection('Yolcu Bilgileri', [
                      _buildDetailRow('Yolcu', customerName),
                      _buildDetailRow('Araç Tipi', _vehicleTypeLabel(vehicleType)),
                      _buildDetailRow('Tarih', _dateFormat.format(createdAt)),
                      if (completedAt != null)
                        _buildDetailRow('Tamamlanma', _dateFormat.format(completedAt)),
                      _buildDetailRow('Mesafe', '${distance.toStringAsFixed(1)} km'),
                      _buildDetailRow('Süre', '$duration dakika'),
                    ]),
                    const SizedBox(height: 16),

                    // Fare breakdown
                    _buildDetailSection('Ücret Dökümü', [
                      _buildDetailRow('Açılış Ücreti', _currencyFormat.format(baseFare)),
                      _buildDetailRow('Mesafe Ücreti', _currencyFormat.format(distanceFare)),
                      _buildDetailRow('Zaman Ücreti', _currencyFormat.format(timeFare)),
                      const Divider(color: AppColors.surfaceLight, height: 16),
                      _buildDetailRow(
                        'Toplam Ücret',
                        _currencyFormat.format(fare),
                        isBold: true,
                      ),
                      if (tip > 0)
                        _buildDetailRow(
                          'Bahşiş',
                          _currencyFormat.format(tip),
                          valueColor: AppColors.success,
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'completed':
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        label = 'Tamamlandı';
      case 'cancelled':
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        label = 'İptal';
      case 'in_progress':
        bgColor = AppColors.info.withValues(alpha: 0.15);
        textColor = AppColors.info;
        label = 'Devam Ediyor';
      case 'accepted':
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        label = 'Kabul Edildi';
      case 'arrived':
        bgColor = AppColors.info.withValues(alpha: 0.15);
        textColor = AppColors.info;
        label = 'Varış';
      case 'pending':
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        label = 'Bekliyor';
      default:
        bgColor = AppColors.surfaceLight.withValues(alpha: 0.15);
        textColor = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Az önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} hafta önce';
    } else {
      return DateFormat('dd MMM', 'tr').format(date);
    }
  }

  String _vehicleTypeLabel(String type) {
    switch (type) {
      case 'economy':
        return 'Ekonomi';
      case 'comfort':
        return 'Konfor';
      case 'premium':
        return 'Premium';
      case 'xl':
        return 'XL';
      default:
        return 'Standart';
    }
  }
}

class _RoutePlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(60, 50)
      ..cubicTo(size.width * 0.3, size.height * 0.8, size.width * 0.7, size.height * 0.2, size.width - 60, size.height - 50);

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        final extractPath = metric.extractPath(distance, end);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
