import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/business_proxy_service.dart';
import '../../../shared/widgets/status_badge.dart';
import 'package:support_panel/core/services/log_service.dart';

class TaxiCourierOpsPanel extends ConsumerStatefulWidget {
  final String businessId;
  final String businessType; // 'taxi_driver' or 'courier'
  final Map<String, dynamic> data;
  const TaxiCourierOpsPanel({super.key, required this.businessId, required this.businessType, required this.data});

  @override
  ConsumerState<TaxiCourierOpsPanel> createState() => _TaxiCourierOpsPanelState();
}

class _TaxiCourierOpsPanelState extends ConsumerState<TaxiCourierOpsPanel> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(businessProxyServiceProvider);
    try {
      if (widget.businessType == 'taxi_driver') {
        final rides = await service.getTaxiRides(widget.businessId);
        final profile = await service.getTaxiDriverById(widget.businessId);
        setState(() { _items = rides; _profile = profile; _isLoading = false; });
      } else {
        final deliveries = await service.getCourierDeliveries(widget.businessId);
        final profile = await service.getCourierById(widget.businessId);
        setState(() { _items = deliveries; _profile = profile; _isLoading = false; });
      }
    } catch (e, st) {
      LogService.error('Failed to load taxi/courier data', error: e, stackTrace: st, source: 'TaxiCourierOpsPanel:_loadData');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final isTaxi = widget.businessType == 'taxi_driver';

    return Column(
      children: [
        // Profile info card
        if (_profile != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Icon(isTaxi ? Icons.local_taxi : Icons.delivery_dining, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile!['full_name'] ?? '-',
                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profile!['phone'] ?? '-',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isTaxi && _profile!['vehicle_plate'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _profile!['vehicle_plate'],
                      style: const TextStyle(color: AppColors.info, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(width: 8),
                StatusBadge.ticketStatus(_profile!['status'] ?? 'offline'),
                if (_profile!['rating'] != null) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: AppColors.warning, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        double.tryParse(_profile!['rating'].toString())?.toStringAsFixed(1) ?? '-',
                        style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

        // Items list header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(isTaxi ? Icons.route : Icons.inventory_2, size: 16, color: textMuted),
              const SizedBox(width: 6),
              Text(
                isTaxi ? 'Yolculuklar (${_items.length})' : 'Teslimatlar (${_items.length})',
                style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Items list
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Text(
                    isTaxi ? 'Yolculuk bulunamad\u0131' : 'Teslimat bulunamad\u0131',
                    style: TextStyle(color: textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) => isTaxi
                      ? _buildRideItem(_items[i], cardColor, borderColor, textPrimary, textMuted)
                      : _buildDeliveryItem(_items[i], cardColor, borderColor, textPrimary, textMuted),
                ),
        ),
      ],
    );
  }

  Widget _buildRideItem(Map<String, dynamic> ride, Color cardColor, Color borderColor, Color textPrimary, Color textMuted) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final createdAt = DateTime.tryParse(ride['created_at'] ?? '');
    final status = ride['status'] ?? 'unknown';
    final fare = ride['fare'] ?? ride['estimated_fare'];

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${ride['id'].toString().substring(0, 8)}',
                    style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                if (fare != null)
                  Text('\u20ba$fare', style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                StatusBadge.ticketStatus(status),
              ],
            ),
            const SizedBox(height: 8),
            if (ride['pickup_address'] != null)
              Row(
                children: [
                  Icon(Icons.trip_origin, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(child: Text(ride['pickup_address'], style: TextStyle(color: textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            if (ride['dropoff_address'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(child: Text(ride['dropoff_address'], style: TextStyle(color: textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(createdAt != null ? df.format(createdAt.toLocal()) : '', style: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryItem(Map<String, dynamic> order, Color cardColor, Color borderColor, Color textPrimary, Color textMuted) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final createdAt = DateTime.tryParse(order['created_at'] ?? '');
    final status = order['status'] ?? 'unknown';

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
      child: ListTile(
        title: Text(
          '#${order['id'].toString().substring(0, 8)} - \u20ba${order['total_amount'] ?? 0}',
          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order['delivery_address'] != null)
              Text(order['delivery_address'], style: TextStyle(color: textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(createdAt != null ? df.format(createdAt.toLocal()) : '', style: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
        trailing: StatusBadge.ticketStatus(status),
      ),
    );
  }
}
