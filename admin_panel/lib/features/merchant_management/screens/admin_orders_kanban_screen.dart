import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/merchant_management_providers.dart';

class _KanbanColumnDef {
  final String status;
  final String title;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _KanbanColumnDef({
    required this.status,
    required this.title,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

const _borderColor = Color(0xFF334155);

final List<_KanbanColumnDef> _columns = [
  const _KanbanColumnDef(
    status: 'pending',
    title: 'Bekleyen',
    icon: Icons.hourglass_empty,
    color: Color(0xFFF59E0B),
    gradient: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
  ),
  const _KanbanColumnDef(
    status: 'confirmed',
    title: 'Onaylanan',
    icon: Icons.check_circle_outline,
    color: Color(0xFF3B82F6),
    gradient: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
  ),
  const _KanbanColumnDef(
    status: 'preparing',
    title: 'Hazırlanıyor',
    icon: Icons.restaurant,
    color: Color(0xFF8B5CF6),
    gradient: [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
  ),
  const _KanbanColumnDef(
    status: 'ready',
    title: 'Hazır',
    icon: Icons.check_box,
    color: Color(0xFF10B981),
    gradient: [Color(0xFF34D399), Color(0xFF10B981)],
  ),
  const _KanbanColumnDef(
    status: 'delivering',
    title: "Teslimat'ta",
    icon: Icons.delivery_dining,
    color: Color(0xFF06B6D4),
    gradient: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
  ),
  const _KanbanColumnDef(
    status: 'completed',
    title: 'Tamamlandı',
    icon: Icons.done_all,
    color: Color(0xFF059669),
    gradient: [Color(0xFF34D399), Color(0xFF059669)],
  ),
  const _KanbanColumnDef(
    status: 'cancelled',
    title: 'İptal',
    icon: Icons.cancel_outlined,
    color: Color(0xFFEF4444),
    gradient: [Color(0xFFF87171), Color(0xFFEF4444)],
  ),
];

/// Status flow for quick status advancement
const Map<String, String> _nextStatusMap = {
  'pending': 'confirmed',
  'confirmed': 'preparing',
  'preparing': 'ready',
  'ready': 'delivering',
  'delivering': 'completed',
};

String _timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inDays > 0) return '${diff.inDays} gün önce';
  if (diff.inHours > 0) return '${diff.inHours} sa önce';
  if (diff.inMinutes > 0) return '${diff.inMinutes} dk önce';
  return 'Az önce';
}

String _formatCurrency(double amount) {
  return '${amount.toStringAsFixed(2)} TL';
}

class AdminOrdersKanbanScreen extends ConsumerStatefulWidget {
  final String merchantId;
  final String sectorLabel;

  const AdminOrdersKanbanScreen({
    super.key,
    required this.merchantId,
    required this.sectorLabel,
  });

  @override
  ConsumerState<AdminOrdersKanbanScreen> createState() =>
      _AdminOrdersKanbanScreenState();
}

class _AdminOrdersKanbanScreenState
    extends ConsumerState<AdminOrdersKanbanScreen> {
  String _searchQuery = '';
  final ScrollController _horizontalScrollController = ScrollController();
  bool _autoRefresh = false;
  Timer? _refreshTimer;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
      if (_autoRefresh) {
        _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          ref.invalidate(merchantOrdersProvider(widget.merchantId));
        });
      } else {
        _refreshTimer?.cancel();
        _refreshTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(merchantOrdersProvider(widget.merchantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          '${widget.sectorLabel} - Sipariş Yönetimi',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Tooltip(
            message: _autoRefresh ? 'Otomatik yenileme açık' : 'Otomatik yenile',
            child: IconButton(
              icon: Icon(
                _autoRefresh ? Icons.sync : Icons.sync_disabled,
                color: _autoRefresh ? AppColors.success : AppColors.textMuted,
              ),
              onPressed: _toggleAutoRefresh,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: () {
              ref.invalidate(merchantOrdersProvider(widget.merchantId));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderBar(ordersAsync),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, _) => _buildErrorState(error),
              data: (orders) => _buildKanbanBoard(orders),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(AsyncValue<List<Map<String, dynamic>>> ordersAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search bar
              Expanded(
                flex: 3,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Sipariş no veya müşteri adı ile ara...',
                      hintStyle:
                          TextStyle(color: AppColors.textMuted, fontSize: 14),
                      prefixIcon: Icon(Icons.search,
                          color: AppColors.textMuted, size: 20),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Stat chips
              ...ordersAsync.when(
                loading: () => [const SizedBox.shrink()],
                error: (_, _) => [const SizedBox.shrink()],
                data: (orders) {
                  final pendingCount = orders
                      .where((o) => o['status'] == 'pending')
                      .length;
                  final activeCount = orders
                      .where((o) =>
                          o['status'] == 'confirmed' ||
                          o['status'] == 'preparing' ||
                          o['status'] == 'ready' ||
                          o['status'] == 'delivering')
                      .length;
                  final completedCount = orders
                      .where((o) => o['status'] == 'completed')
                      .length;
                  return [
                    _buildStatChip(
                      icon: Icons.pending_actions,
                      label: 'Bekleyen',
                      count: pendingCount,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 10),
                    _buildStatChip(
                      icon: Icons.local_shipping,
                      label: 'Aktif',
                      count: activeCount,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 10),
                    _buildStatChip(
                      icon: Icons.done_all,
                      label: 'Tamamlanan',
                      count: completedCount,
                      color: const Color(0xFF059669),
                    ),
                  ];
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text(
            'Siparişler yüklenirken hata oluştu',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () =>
                ref.invalidate(merchantOrdersProvider(widget.merchantId)),
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanBoard(List<Map<String, dynamic>> orders) {
    final filtered = _searchQuery.isEmpty
        ? orders
        : orders.where((o) {
            final query = _searchQuery.toLowerCase();
            final orderNum =
                (o['order_number']?.toString() ?? '').toLowerCase();
            final customerName =
                (o['customer_name']?.toString() ?? '').toLowerCase();
            return orderNum.contains(query) || customerName.contains(query);
          }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final columnCount = _columns.length;
        const horizontalPadding = 16.0 * 2;
        final totalGapWidth = 12.0 * (columnCount - 1);
        final calculatedWidth =
            (availableWidth - horizontalPadding - totalGapWidth) / columnCount;
        final columnWidth = calculatedWidth.clamp(260.0, 340.0);
        final totalNeededWidth =
            columnWidth * columnCount + totalGapWidth + horizontalPadding;
        final needsScroll = totalNeededWidth > availableWidth;
        final columnHeight = availableHeight - 32;

        final content = Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _columns.asMap().entries.map((entry) {
              final index = entry.key;
              final column = entry.value;
              final columnOrders =
                  filtered.where((o) => o['status'] == column.status).toList();
              final isLast = index == _columns.length - 1;

              return Container(
                width: columnWidth,
                height: columnHeight,
                margin: EdgeInsets.only(right: isLast ? 0 : 12),
                child: _buildColumn(column, columnOrders, columnHeight),
              );
            }).toList(),
          ),
        );

        if (needsScroll) {
          return Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }

  Widget _buildColumn(
    _KanbanColumnDef column,
    List<Map<String, dynamic>> orders,
    double columnHeight,
  ) {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        return details.data['status'] != column.status;
      },
      onAcceptWithDetails: (details) {
        _onOrderDropped(details.data, column.status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHighlighted
                ? column.color.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? column.color : _borderColor,
              width: isHighlighted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? column.color.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: isHighlighted ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildColumnHeader(column, orders.length),
              Expanded(
                child: orders.isEmpty
                    ? _buildEmptyColumn(column)
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          return _buildDraggableOrderCard(
                              orders[index], column);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColumnHeader(_KanbanColumnDef column, int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: column.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(column.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$count sipariş',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyColumn(_KanbanColumnDef column) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: column.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                column.icon,
                size: 28,
                color: column.color.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sipariş yok',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Siparişleri buraya sürükleyin',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableOrderCard(
      Map<String, dynamic> order, _KanbanColumnDef column) {
    return Draggable<Map<String, dynamic>>(
      data: order,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
        child: SizedBox(
          width: 280,
          child: _buildOrderCard(order, column, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildOrderCard(order, column),
      ),
      child: GestureDetector(
        onTap: () => _showOrderDetailDialog(order),
        child: _buildOrderCard(order, column),
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
    _KanbanColumnDef column, {
    bool isDragging = false,
  }) {
    final orderNumber = order['order_number']?.toString() ?? '-';
    final customerName = order['customer_name']?.toString() ?? 'Bilinmeyen';
    final customerPhone = order['customer_phone']?.toString() ?? '';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final timeAgoStr = createdAt != null ? _timeAgo(createdAt) : '-';
    final paymentMethod = order['payment_method']?.toString() ?? '';
    final notes = order['notes']?.toString() ?? '';
    final status = order['status']?.toString() ?? '';
    final hasNextStatus = _nextStatusMap.containsKey(status);

    // Parse items
    final rawItems = order['items'];
    List<dynamic> items = [];
    if (rawItems is List) {
      items = rawItems;
    }
    final itemCount = items.length;
    final itemsSummary = items.take(2).map((item) {
      if (item is Map) {
        final name = item['name']?.toString() ?? '';
        final qty = item['quantity']?.toString() ?? '1';
        return '$qty x $name';
      }
      return item.toString();
    }).join(', ');
    final hasMore = items.length > 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDragging ? AppColors.surfaceLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDragging
              ? column.color.withValues(alpha: 0.5)
              : _borderColor,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: column.color.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order number + time ago
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: column.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$orderNumber',
                  style: TextStyle(
                    color: column.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    timeAgoStr,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Customer info
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  customerName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (customerPhone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  customerPhone,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),

          // Items summary
          if (itemsSummary.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemsSummary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasMore)
                    Text(
                      '+${items.length - 2} ürün daha',
                      style: TextStyle(
                        color: column.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ] else if (itemCount == 0) ...[
            const SizedBox(height: 4),
          ],

          // Notes
          if (notes.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.note_outlined,
                    size: 12, color: AppColors.warning.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    notes,
                    style: TextStyle(
                      color: AppColors.warning.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Payment method tag
          if (paymentMethod.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  paymentMethod == 'cash'
                      ? Icons.money
                      : Icons.credit_card,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  paymentMethod == 'cash'
                      ? 'Nakit'
                      : paymentMethod == 'card'
                          ? 'Kart'
                          : paymentMethod,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Bottom row: total + item count + next status button
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _formatCurrency(totalAmount),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.shopping_bag_outlined,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(
                '${itemCount > 0 ? itemCount : (order['item_count'] ?? 0)} ürün',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              // Quick status advance button
              if (hasNextStatus)
                _buildQuickStatusButton(order, status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatusButton(
      Map<String, dynamic> order, String currentStatus) {
    final nextStatus = _nextStatusMap[currentStatus]!;
    final nextColumn =
        _columns.firstWhere((c) => c.status == nextStatus);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onOrderDropped(order, nextStatus),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: nextColumn.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: nextColumn.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward, size: 12, color: nextColumn.color),
              const SizedBox(width: 3),
              Text(
                nextColumn.title,
                style: TextStyle(
                  color: nextColumn.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetailDialog(Map<String, dynamic> order) {
    final orderNumber = order['order_number']?.toString() ?? '-';
    final customerName = order['customer_name']?.toString() ?? 'Bilinmeyen';
    final customerPhone = order['customer_phone']?.toString() ?? '-';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final deliveryAddress = order['delivery_address']?.toString() ?? '-';
    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(order['updated_at']?.toString() ?? '');
    final status = order['status']?.toString() ?? 'pending';
    final paymentMethod = order['payment_method']?.toString() ?? '-';
    final notes = order['notes']?.toString() ?? '';
    final timeAgoStr = createdAt != null ? _timeAgo(createdAt) : '-';

    final currentColumn =
        _columns.firstWhere((c) => c.status == status, orElse: () => _columns.first);

    // Parse items
    final rawItems = order['items'];
    List<dynamic> items = [];
    if (rawItems is List) {
      items = rawItems;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 520,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: currentColumn.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(currentColumn.icon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sipariş #$orderNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${currentColumn.title} - $timeAgoStr',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Info Section
                      _buildDetailSection(
                        title: 'Müşteri Bilgileri',
                        icon: Icons.person_outline,
                        children: [
                          _buildDetailRow('Ad', customerName),
                          _buildDetailRow('Telefon', customerPhone),
                          _buildDetailRow('Adres', deliveryAddress),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Items Section
                      _buildDetailSection(
                        title: 'Sipariş Kalemleri',
                        icon: Icons.receipt_long,
                        children: [
                          if (items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Kalem bilgisi yok',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            ...items.map((item) {
                              if (item is Map) {
                                final name =
                                    item['name']?.toString() ?? 'Ürün';
                                final qty =
                                    item['quantity']?.toString() ?? '1';
                                final price =
                                    (item['price'] as num?)?.toDouble() ?? 0;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: currentColumn.color
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${qty}x',
                                            style: TextStyle(
                                              color: currentColumn.color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(price),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                          const Divider(color: _borderColor, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Toplam',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatCurrency(totalAmount),
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Order Info Section
                      _buildDetailSection(
                        title: 'Sipariş Bilgileri',
                        icon: Icons.info_outline,
                        children: [
                          _buildDetailRow(
                            'Ödeme',
                            paymentMethod == 'cash'
                                ? 'Nakit'
                                : paymentMethod == 'card'
                                    ? 'Kredi Kartı'
                                    : paymentMethod,
                          ),
                          _buildDetailRow(
                            'Oluşturulma',
                            createdAt != null
                                ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                                : '-',
                          ),
                          if (updatedAt != null)
                            _buildDetailRow(
                              'Son Güncelleme',
                              '${updatedAt.day.toString().padLeft(2, '0')}/${updatedAt.month.toString().padLeft(2, '0')}/${updatedAt.year} ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}',
                            ),
                          if (notes.isNotEmpty)
                            _buildDetailRow('Not', notes),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Status change buttons
                      _buildStatusChangeButtons(order, dialogContext),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChangeButtons(
      Map<String, dynamic> order, BuildContext dialogContext) {
    final currentStatus = order['status']?.toString() ?? '';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Next status button (primary)
        if (_nextStatusMap.containsKey(currentStatus)) ...[
          _buildStatusActionButton(
            order: order,
            targetStatus: _nextStatusMap[currentStatus]!,
            isPrimary: true,
            dialogContext: dialogContext,
          ),
        ],
        // Cancel button (if not already completed or cancelled)
        if (currentStatus != 'completed' && currentStatus != 'cancelled')
          _buildStatusActionButton(
            order: order,
            targetStatus: 'cancelled',
            isPrimary: false,
            dialogContext: dialogContext,
          ),
      ],
    );
  }

  Widget _buildStatusActionButton({
    required Map<String, dynamic> order,
    required String targetStatus,
    required bool isPrimary,
    required BuildContext dialogContext,
  }) {
    final targetColumn =
        _columns.firstWhere((c) => c.status == targetStatus);

    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(dialogContext);
          _onOrderDropped(order, targetStatus);
        },
        icon: Icon(targetColumn.icon, size: 18),
        label: Text(targetColumn.title),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? targetColumn.color
              : targetColumn.color.withValues(alpha: 0.15),
          foregroundColor: isPrimary ? Colors.white : targetColumn.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: isPrimary ? 2 : 0,
        ),
      ),
    );
  }

  Future<void> _onOrderDropped(
      Map<String, dynamic> order, String newStatus) async {
    final orderId = order['id']?.toString();
    if (orderId == null) return;

    try {
      final client = ref.read(supabaseProvider);
      await updateOrderStatus(client, orderId, newStatus);
      ref.invalidate(merchantOrdersProvider(widget.merchantId));

      if (!mounted) return;

      final columnDef = _columns.firstWhere((c) => c.status == newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(columnDef.icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                'Sipariş #${order['order_number']} -> ${columnDef.title}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: columnDef.color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sipariş durumu güncellenemedi: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
