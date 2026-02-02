import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/merchant_models.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/notification_sound_service.dart';
import '../widgets/order_card.dart';

class OrdersKanbanScreen extends ConsumerStatefulWidget {
  const OrdersKanbanScreen({super.key});

  @override
  ConsumerState<OrdersKanbanScreen> createState() => _OrdersKanbanScreenState();
}

class _OrdersKanbanScreenState extends ConsumerState<OrdersKanbanScreen>
    with TickerProviderStateMixin {
  late AnimationController _columnAnimationController;
  String _searchQuery = '';

  // Kanban columns configuration
  final List<KanbanColumn> _columns = [
    KanbanColumn(
      status: OrderStatus.pending,
      title: 'Bekleyen',
      icon: Icons.hourglass_empty,
      color: const Color(0xFFF59E0B),
      gradient: const [Color(0xFFFCD34D), Color(0xFFF59E0B)],
    ),
    KanbanColumn(
      status: OrderStatus.confirmed,
      title: 'Onaylanan',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF3B82F6),
      gradient: const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
    ),
    KanbanColumn(
      status: OrderStatus.preparing,
      title: 'Hazırlanan',
      icon: Icons.restaurant,
      color: const Color(0xFF8B5CF6),
      gradient: const [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
    ),
    KanbanColumn(
      status: OrderStatus.ready,
      title: 'Hazır',
      icon: Icons.check_box,
      color: const Color(0xFF10B981),
      gradient: const [Color(0xFF34D399), Color(0xFF10B981)],
    ),
    KanbanColumn(
      status: OrderStatus.delivering,
      title: 'Yolda',
      icon: Icons.delivery_dining,
      color: const Color(0xFF06B6D4),
      gradient: const [Color(0xFF22D3EE), Color(0xFF06B6D4)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _columnAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _columnAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);

    return Column(
      children: [
        // Header
        _buildHeader(),

        // Kanban Board
        Expanded(
          child: orders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(error),
            data: (orderList) => _buildKanbanBoard(orderList),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            flex: 2,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Sipariş ara...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Stats
          _buildStatChip(
            icon: Icons.pending_actions,
            label: 'Bekleyen',
            count: ref.watch(pendingOrdersProvider).length,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            icon: Icons.local_shipping,
            label: 'Aktif',
            count: ref.watch(activeOrdersCountProvider),
            color: const Color(0xFF3B82F6),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
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
          Text('Hata: $error', style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final merchant = ref.read(currentMerchantProvider).valueOrNull;
              if (merchant != null) {
                ref.read(ordersProvider.notifier).loadOrders(merchant.id);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanBoard(List<Order> orders) {
    // Filter orders by search
    final filteredOrders = _searchQuery.isEmpty
        ? orders
        : orders.where((o) =>
            o.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            o.customerName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final columnCount = _columns.length;
        final horizontalPadding = 20.0 * 2; // left + right padding
        final totalGapWidth = 12.0 * (columnCount - 1); // gaps between columns
        final columnWidth = ((availableWidth - horizontalPadding - totalGapWidth) / columnCount).clamp(200.0, 320.0);
        final columnHeight = availableHeight - 40; // subtract vertical padding

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _columns.asMap().entries.map((entry) {
              final index = entry.key;
              final column = entry.value;
              final columnOrders = filteredOrders
                  .where((o) => o.status == column.status)
                  .toList();
              final isLast = index == _columns.length - 1;

              return AnimatedBuilder(
                animation: _columnAnimationController,
                builder: (context, child) {
                  final delay = index * 0.08;
                  final end = (delay + 0.4).clamp(0.0, 1.0);
                  final animation = CurvedAnimation(
                    parent: _columnAnimationController,
                    curve: Interval(delay.clamp(0.0, 1.0), end, curve: Curves.easeOutBack),
                  );

                  final animValue = animation.value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - animValue)),
                    child: Opacity(
                      opacity: animValue,
                      child: _buildColumn(column, columnOrders, columnWidth, columnHeight, isLast),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildColumn(KanbanColumn column, List<Order> orders, double columnWidth, double columnHeight, bool isLast) {
    return DragTarget<Order>(
      onWillAcceptWithDetails: (details) {
        return details.data.status != column.status;
      },
      onAcceptWithDetails: (details) {
        _onOrderDropped(details.data, column.status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: columnWidth,
          height: columnHeight,
          margin: EdgeInsets.only(right: isLast ? 0 : 12),
          decoration: BoxDecoration(
            color: isHighlighted
                ? column.color.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? column.color : AppColors.border,
              width: isHighlighted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? column.color.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: isHighlighted ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Column Header
              _buildColumnHeader(column, orders.length),

              // Orders List
              Expanded(
                child: orders.isEmpty
                    ? _buildEmptyColumn(column)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return _buildDraggableOrderCard(order);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColumnHeader(KanbanColumn column, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(column.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$count sipariş',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyColumn(KanbanColumn column) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: column.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                column.icon,
                size: 32,
                color: column.color.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sipariş yok',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Siparişleri buraya sürükleyin',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableOrderCard(Order order) {
    return Draggable<Order>(
      data: order,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 290,
          child: OrderCard(
            order: order,
            isDragging: true,
            isCompact: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: OrderCard(
          order: order,
          isCompact: true,
        ),
      ),
      child: OrderCard(
        order: order,
        isCompact: true,
        onTap: () => _showOrderDetail(order),
        onStatusChange: (status) => _updateOrderStatus(order, status),
      ),
    );
  }

  void _onOrderDropped(Order order, OrderStatus newStatus) {
    _updateOrderStatus(order, newStatus);
  }

  void _updateOrderStatus(Order order, OrderStatus newStatus) {
    ref.read(ordersProvider.notifier).updateOrderStatus(order.id, newStatus);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(newStatus.icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('Sipariş #${order.orderNumber} - ${newStatus.displayName}'),
          ],
        ),
        backgroundColor: newStatus.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showOrderDetail(Order order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                    colors: [
                      order.status.color,
                      order.status.color.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(order.status.icon, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sipariş Detayı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OrderCard(
                        order: order,
                        onStatusChange: (status) {
                          _updateOrderStatus(order, status);
                          Navigator.pop(context);
                        },
                      ),

                      // Müşteri Mesajları
                      _KanbanOrderMessagesCard(
                        orderId: order.id,
                        merchantId: order.merchantId,
                      ),
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
}

// Kanban modal için mesaj kartı
class _KanbanOrderMessagesCard extends StatefulWidget {
  final String orderId;
  final String merchantId;

  const _KanbanOrderMessagesCard({
    required this.orderId,
    required this.merchantId,
  });

  @override
  State<_KanbanOrderMessagesCard> createState() => _KanbanOrderMessagesCardState();
}

class _KanbanOrderMessagesCardState extends State<_KanbanOrderMessagesCard> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('order_messages')
          .select()
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtimeSubscription() {
    _subscription = Supabase.instance.client
        .from('order_messages')
        .stream(primaryKey: ['id'])
        .eq('order_id', widget.orderId)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        final newMessages = List<Map<String, dynamic>>.from(data);

        // Yeni müşteri mesajı geldi mi kontrol et
        if (newMessages.length > _messages.length) {
          final lastMessage = newMessages.last;
          if (lastMessage['sender_type'] == 'customer') {
            // Ses çal
            NotificationSoundService.playSound();
          }
        }

        setState(() {
          _messages = newMessages;
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await Supabase.instance.client
          .from('order_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('order_id', widget.orderId)
          .eq('sender_type', 'customer')
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Mesaj okundu işaretleme hatası: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('order_messages').insert({
        'order_id': widget.orderId,
        'merchant_id': widget.merchantId,
        'sender_type': 'merchant',
        'sender_id': widget.merchantId,
        'sender_name': 'Restoran',
        'message': text,
      });

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _messages.where((m) =>
      m['sender_type'] == 'customer' && m['is_read'] != true
    ).length;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Müşteri Mesajları',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount yeni',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Messages List
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 32, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'Henüz mesaj yok',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isFromCustomer = message['sender_type'] == 'customer';
                  final time = DateTime.tryParse(message['created_at'] ?? '');
                  final timeStr = time != null
                      ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                      : '';

                  return Align(
                    alignment: isFromCustomer ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: isFromCustomer
                            ? AppColors.surface
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFromCustomer
                              ? AppColors.border
                              : AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFromCustomer ? Icons.person : Icons.store,
                                size: 12,
                                color: isFromCustomer ? AppColors.textMuted : AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                message['sender_name'] ?? (isFromCustomer ? 'Müşteri' : 'Restoran'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isFromCustomer ? AppColors.textMuted : AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message['message'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yazın...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KanbanColumn {
  final OrderStatus status;
  final String title;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  KanbanColumn({
    required this.status,
    required this.title,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}
