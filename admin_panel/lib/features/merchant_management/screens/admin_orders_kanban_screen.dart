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
  _KanbanColumnDef(
    status: 'pending',
    title: 'Bekleyen',
    icon: Icons.hourglass_empty,
    color: const Color(0xFFF59E0B),
    gradient: const [Color(0xFFFCD34D), Color(0xFFF59E0B)],
  ),
  _KanbanColumnDef(
    status: 'confirmed',
    title: 'Onaylanan',
    icon: Icons.check_circle_outline,
    color: const Color(0xFF3B82F6),
    gradient: const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
  ),
  _KanbanColumnDef(
    status: 'preparing',
    title: 'Hazırlanıyor',
    icon: Icons.restaurant,
    color: const Color(0xFF8B5CF6),
    gradient: const [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
  ),
  _KanbanColumnDef(
    status: 'ready',
    title: 'Hazır',
    icon: Icons.check_box,
    color: const Color(0xFF10B981),
    gradient: const [Color(0xFF34D399), Color(0xFF10B981)],
  ),
  _KanbanColumnDef(
    status: 'delivering',
    title: "Teslimat'ta",
    icon: Icons.delivery_dining,
    color: const Color(0xFF06B6D4),
    gradient: const [Color(0xFF22D3EE), Color(0xFF06B6D4)],
  ),
  _KanbanColumnDef(
    status: 'completed',
    title: 'Tamamlandı',
    icon: Icons.done_all,
    color: const Color(0xFF059669),
    gradient: const [Color(0xFF34D399), Color(0xFF059669)],
  ),
  _KanbanColumnDef(
    status: 'cancelled',
    title: 'İptal',
    icon: Icons.cancel_outlined,
    color: const Color(0xFFEF4444),
    gradient: const [Color(0xFFF87171), Color(0xFFEF4444)],
  ),
];

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

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
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
          _buildSearchBar(),
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

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Sipariş no veya müşteri adı ile ara...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
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
          Text(
            'Siparişler yüklenirken hata oluştu',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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

    return Scrollbar(
      controller: _horizontalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _columns.asMap().entries.map((entry) {
            final index = entry.key;
            final column = entry.value;
            final columnOrders = filtered
                .where((o) => o['status'] == column.status)
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                right: index < _columns.length - 1 ? 12 : 0,
              ),
              child: _buildColumn(column, columnOrders),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildColumn(
      _KanbanColumnDef column, List<Map<String, dynamic>> orders) {
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
          width: 300,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - 180,
          ),
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
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: isHighlighted ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColumnHeader(column, orders.length),
              if (orders.isEmpty)
                _buildEmptyColumn(column)
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _buildDraggableOrderCard(orders[index]);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
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
    );
  }

  Widget _buildDraggableOrderCard(Map<String, dynamic> order) {
    return Draggable<Map<String, dynamic>>(
      data: order,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
        child: SizedBox(
          width: 280,
          child: _buildOrderCard(order, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildOrderCard(order),
      ),
      child: _buildOrderCard(order),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order,
      {bool isDragging = false}) {
    final orderNumber = order['order_number']?.toString() ?? '-';
    final customerName = order['customer_name']?.toString() ?? 'Bilinmeyen';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final itemCount = order['item_count'] as int? ?? 0;
    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final timeStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDragging ? AppColors.surfaceLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDragging
              ? AppColors.primary.withValues(alpha: 0.5)
              : _borderColor,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$orderNumber',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${totalAmount.toStringAsFixed(2)} TL',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '$itemCount ürün',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
