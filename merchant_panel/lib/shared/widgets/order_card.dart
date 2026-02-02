import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/merchant_models.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_sound_service.dart';
import '../screens/couriers_screen.dart';

class OrderCard extends ConsumerStatefulWidget {
  final Order order;
  final VoidCallback? onTap;
  final Function(OrderStatus)? onStatusChange;
  final bool isDragging;
  final bool isCompact;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onStatusChange,
    this.isDragging = false,
    this.isCompact = false,
  });

  @override
  ConsumerState<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<OrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;
  bool _isNew = false;
  int _unreadMessageCount = 0;
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Check if order is new (less than 30 seconds old) AND pending
    _isNew =
        DateTime.now().difference(widget.order.createdAt).inSeconds < 30 &&
        widget.order.status == OrderStatus.pending;

    if (_isNew) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }

    // Load unread message count
    _loadUnreadMessageCount();
    _setupMessageSubscription();
  }

  Future<void> _loadUnreadMessageCount() async {
    try {
      final response = await Supabase.instance.client
          .from('order_messages')
          .select('id')
          .eq('order_id', widget.order.id)
          .eq('sender_type', 'customer')
          .eq('is_read', false);

      if (mounted) {
        setState(() {
          _unreadMessageCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread messages: $e');
    }
  }

  void _setupMessageSubscription() {
    _messageSubscription = Supabase.instance.client
        .from('order_messages')
        .stream(primaryKey: ['id'])
        .eq('order_id', widget.order.id)
        .listen((data) {
      if (mounted) {
        final previousUnread = _unreadMessageCount;
        final unread = data.where((m) =>
            m['sender_type'] == 'customer' && m['is_read'] != true).length;

        // Yeni okunmamış mesaj geldiyse ses çal
        if (unread > previousUnread) {
          NotificationSoundService.playSound();
        }

        setState(() {
          _unreadMessageCount = unread;
        });
      }
    });
  }

  @override
  void didUpdateWidget(OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sipariş onaylandığında animasyonu durdur
    if (oldWidget.order.status == OrderStatus.pending &&
        widget.order.status != OrderStatus.pending) {
      _controller.stop();
      _controller.forward();
      setState(() => _isNew = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isDragging ? 1.05 : _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _isNew
                          ? widget.order.status.color.withValues(alpha:
                            _glowAnimation.value.clamp(0.0, 1.0) * 0.8,
                          )
                          : (_isHovered
                              ? widget.order.status.color.withValues(alpha:0.3)
                              : AppColors.border),
                  width: _isNew ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        widget.isDragging
                            ? widget.order.status.color.withValues(alpha:0.3)
                            : (_isNew
                                ? widget.order.status.color.withValues(alpha:
                                  _glowAnimation.value.clamp(0.0, 1.0) * 0.2,
                                )
                                : Colors.black.withValues(alpha:
                                  _isHovered ? 0.15 : 0.08,
                                )),
                    blurRadius: widget.isDragging ? 20 : (_isHovered ? 15 : 8),
                    offset: Offset(0, widget.isDragging ? 8 : 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child:
                      widget.isCompact ? _buildCompactCard() : _buildFullCard(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactCard() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              _buildStatusBadge(),
              const Spacer(),
              if (_unreadMessageCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble, color: Colors.white, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        '$_unreadMessageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              _buildOrderNumber(),
            ],
          ),
          const SizedBox(height: 10),

          // Customer
          Row(
            children: [
              _buildCustomerAvatar(size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.order.itemCount} urun',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.order.total.toStringAsFixed(2)} TL',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Time & Action
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                _getTimeAgo(widget.order.createdAt),
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const Spacer(),
              if (widget.order.status == OrderStatus.pending)
                _buildQuickActions(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.order.status.color.withValues(alpha:0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              _buildStatusBadge(),
              const Spacer(),
              _buildOrderNumber(),
              const SizedBox(width: 8),
              _buildMenuButton(),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info Section
              _buildSectionHeader('Musteri Bilgileri', Icons.person_outline),
              const SizedBox(height: 8),
              _buildCustomerInfoSection(),
              const SizedBox(height: 16),

              // Delivery Address Section
              _buildSectionHeader(
                'Teslimat Adresi',
                Icons.location_on_outlined,
              ),
              const SizedBox(height: 8),
              _buildAddressSection(),
              const SizedBox(height: 16),

              // Order Items Section
              _buildSectionHeader(
                'Siparis Detayi',
                Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 8),
              _buildOrderItemsSection(),

              // Order Notes Section
              if (widget.order.deliveryInstructions != null &&
                  widget.order.deliveryInstructions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionHeader('Siparis Notu', Icons.note_outlined),
                const SizedBox(height: 8),
                _buildNotesSection(),
              ],

              const SizedBox(height: 16),

              // Payment & Totals Section
              _buildSectionHeader('Odeme Bilgileri', Icons.payment_outlined),
              const SizedBox(height: 8),
              _buildPaymentSection(),

              // Courier Assignment Section
              if (widget.order.status == OrderStatus.preparing ||
                  widget.order.status == OrderStatus.ready) ...[
                const SizedBox(height: 16),
                _buildSectionHeader(
                  'Kurye Atama',
                  Icons.delivery_dining_outlined,
                ),
                const SizedBox(height: 8),
                _buildCourierAssignmentSection(),
              ],

              const SizedBox(height: 16),

              // Footer with Time & Actions
              Row(
                children: [
                  _buildTimeInfo(),
                  const Spacer(),
                  if (widget.order.status != OrderStatus.delivered &&
                      widget.order.status != OrderStatus.cancelled)
                    _buildActionButtons(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildCustomerAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.order.customerPhone ?? 'Telefon bilgisi yok',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.order.customerPhone != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap:
                                () => _copyToClipboard(
                                  widget.order.customerPhone!,
                                ),
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.order.total.toStringAsFixed(2)} TL',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${widget.order.itemCount} urun',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.deliveryAddress,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (widget.order.deliveryInstructions != null &&
                        widget.order.deliveryInstructions!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha:0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.order.deliveryInstructions!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: () => _copyToClipboard(widget.order.deliveryAddress),
                child: Icon(Icons.copy, size: 18, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Items header
          Row(
            children: [
              Text(
                '${widget.order.items.length} Kalem Urun',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const Spacer(),
              Text(
                'Toplam: ${widget.order.itemCount} adet',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const Divider(height: 16),

          // Items list
          ...widget.order.items.map((item) => _buildOrderItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha:0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main item row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha:0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${item.quantity}x',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // Options/Extras
                    if (item.options != null && item.options!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children:
                            item.options!
                                .map(
                                  (option) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],

                    // Item note
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.note,
                              size: 12,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.notes!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.price.toStringAsFixed(2)} TL',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Text(
                    '${(item.price * item.quantity).toStringAsFixed(2)} TL',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha:0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.order.deliveryInstructions!,
              style: TextStyle(fontSize: 13, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Payment method
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getPaymentMethodColor().withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getPaymentMethodIcon(),
                  size: 18,
                  color: _getPaymentMethodColor(),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _getPaymentMethodText(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _getPaymentMethodColor(),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      widget.order.paymentStatus == 'paid'
                          ? AppColors.success.withValues(alpha:0.1)
                          : AppColors.warning.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.order.paymentStatus == 'paid' ? 'Odendi' : 'Bekliyor',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        widget.order.paymentStatus == 'paid'
                            ? AppColors.success
                            : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Price breakdown
          _buildPriceRow('Ara Toplam', widget.order.subtotal),
          if (widget.order.deliveryFee > 0)
            _buildPriceRow('Teslimat Ucreti', widget.order.deliveryFee),
          if (widget.order.serviceFee > 0)
            _buildPriceRow('Hizmet Bedeli', widget.order.serviceFee),
          if (widget.order.discount > 0)
            _buildPriceRow('Indirim', -widget.order.discount, isDiscount: true),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOPLAM',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${widget.order.total.toStringAsFixed(2)} TL',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          Text(
            '${isDiscount ? '-' : ''}${amount.abs().toStringAsFixed(2)} TL',
            style: TextStyle(
              fontSize: 13,
              color: isDiscount ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierAssignmentSection() {
    final merchantCouriers = ref.watch(merchantCouriersProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          merchantCouriers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Kuryeler yuklenemedi'),
            data: (couriers) {
              final onlineCouriers =
                  couriers
                      .where(
                        (c) => c['is_online'] == true && c['is_busy'] != true,
                      )
                      .toList();

              return Column(
                children: [
                  // My Couriers Button
                  if (onlineCouriers.isNotEmpty)
                    _buildCourierOptionTile(
                      icon: Icons.person,
                      title: 'Kendi Kuryem',
                      subtitle: '${onlineCouriers.length} kurye musait',
                      color: AppColors.success,
                      onTap: () => _showMyCouriersBottomSheet(onlineCouriers),
                    ),
                  if (onlineCouriers.isEmpty)
                    _buildCourierOptionTile(
                      icon: Icons.person_off,
                      title: 'Kendi Kuryem',
                      subtitle: 'Musait kurye yok',
                      color: AppColors.textMuted,
                      onTap: null,
                    ),
                  const SizedBox(height: 8),
                  // Platform Couriers Button
                  _buildCourierOptionTile(
                    icon: Icons.public,
                    title: 'Platform Kuryesi',
                    subtitle: 'Yakin kuryelere teklif gonder',
                    color: AppColors.info,
                    onTap: () => _broadcastToPlatformCouriers(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCourierOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha:0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color.withValues(alpha:0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios, color: color, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyCouriersBottomSheet(List<Map<String, dynamic>> couriers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delivery_dining, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Kurye Sec',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                ...couriers.map(
                  (courier) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.success.withValues(alpha:0.1),
                      child: Text(
                        (courier['full_name'] as String?)
                                ?.substring(0, 1)
                                .toUpperCase() ??
                            'K',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(courier['full_name'] ?? 'Kurye'),
                    subtitle: Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: AppColors.success),
                        const SizedBox(width: 4),
                        const Text(
                          'Musait',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.star, size: 14, color: AppColors.warning),
                        const SizedBox(width: 2),
                        Text(
                          '${(courier['rating'] ?? 5.0).toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _assignCourier(courier['id'], 'restaurant');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Ata'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Future<void> _assignCourier(String courierId, String courierType) async {
    final supabase = ref.read(supabaseProvider);

    try {
      await supabase
          .from('orders')
          .update({
            'courier_id': courierId,
            'courier_type': courierType,
            'delivery_status': 'assigned',
            'courier_assigned_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.order.id);

      // Update courier status
      await supabase
          .from('couriers')
          .update({'is_busy': true, 'current_order_id': widget.order.id})
          .eq('id', courierId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kurye atandi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _broadcastToPlatformCouriers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Platform Kuryelerine Gonder'),
            content: const Text(
              'Yakin bolgenizdeki musait platform kuryelerine siparis teklifi gonderilecek. '
              'Ilk kabul eden kurye siparisi alacak.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Teklif Gonder'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    final supabase = ref.read(supabaseProvider);

    try {
      // Update order delivery status
      await supabase
          .from('orders')
          .update({'delivery_status': 'searching'})
          .eq('id', widget.order.id);

      // Get nearby online platform couriers
      final couriers = await supabase
          .from('couriers')
          .select()
          .eq('status', 'approved')
          .eq('is_online', true)
          .inFilter('work_mode', ['platform', 'both'])
          .limit(10);

      // Create courier requests
      for (final courier in couriers) {
        await supabase.from('courier_requests').insert({
          'order_id': widget.order.id,
          'courier_id': courier['id'],
          'status': 'pending',
          'delivery_fee': 15.0,
          'expires_at':
              DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${couriers.length} kuryeye teklif gonderildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildStatusBadge() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.order.status.color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.order.status.color.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.order.status.icon,
            size: 14,
            color: widget.order.status.color,
          ),
          const SizedBox(width: 6),
          Text(
            widget.order.status.displayName,
            style: TextStyle(
              color: widget.order.status.color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNumber() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#${widget.order.orderNumber}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'print':
            _printOrder();
            break;
          case 'print_thermal':
            _printThermalReceipt();
            break;
          case 'copy':
            _copyOrderNumber();
            break;
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: 'print',
              child: Row(
                children: [
                  Icon(Icons.print_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('A4 Yazdir'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'print_thermal',
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Termal Fis Yazdir'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Siparis No Kopyala'),
                ],
              ),
            ),
          ],
    );
  }

  Widget _buildCustomerAvatar({double size = 44}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha:0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha:0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.order.customerName.isNotEmpty
              ? widget.order.customerName.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo() {
    return Row(
      children: [
        Icon(Icons.access_time, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          DateFormat('HH:mm').format(widget.order.createdAt),
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        if (widget.order.status == OrderStatus.pending) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  widget.order.waitingTime.inMinutes > 5
                      ? AppColors.error.withValues(alpha:0.1)
                      : AppColors.warning.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color:
                      widget.order.waitingTime.inMinutes > 5
                          ? AppColors.error
                          : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.order.waitingTimeText,
                  style: TextStyle(
                    color:
                        widget.order.waitingTime.inMinutes > 5
                            ? AppColors.error
                            : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMiniActionButton(
          icon: Icons.close,
          color: AppColors.error,
          onTap: () => widget.onStatusChange?.call(OrderStatus.cancelled),
        ),
        const SizedBox(width: 6),
        _buildMiniActionButton(
          icon: Icons.check,
          color: AppColors.success,
          onTap: () => widget.onStatusChange?.call(OrderStatus.confirmed),
        ),
      ],
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha:0.3)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildActionButtons() {
    // Kurye atandıysa ve sipariş ready/pickedUp/delivering durumundaysa buton gösterme
    final isCourierInControl =
        widget.order.hasCourierAssigned &&
        (widget.order.status == OrderStatus.ready ||
            widget.order.status == OrderStatus.pickedUp ||
            widget.order.status == OrderStatus.delivering);

    if (isCourierInControl) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delivery_dining, size: 16, color: AppColors.info),
            const SizedBox(width: 6),
            Text(
              'Kurye Kontrolunde',
              style: TextStyle(color: AppColors.info, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        if (widget.order.status == OrderStatus.pending) ...[
          OutlinedButton.icon(
            onPressed: () => widget.onStatusChange?.call(OrderStatus.cancelled),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reddet'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => widget.onStatusChange?.call(OrderStatus.confirmed),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Onayla'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: () => widget.onStatusChange?.call(_getNextStatus()),
            icon: Icon(_getNextStatusIcon(), size: 16),
            label: Text(_getNextStatusText()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
      ],
    );
  }

  // Helper methods
  IconData _getPaymentMethodIcon() {
    switch (widget.order.paymentMethod) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'online':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor() {
    switch (widget.order.paymentMethod) {
      case 'cash':
        return AppColors.success;
      case 'card':
        return AppColors.primary;
      default:
        return AppColors.textMuted;
    }
  }

  String _getPaymentMethodText() {
    switch (widget.order.paymentMethod) {
      case 'cash':
        return 'Kapida Nakit';
      case 'card':
        return 'Kredi Karti';
      case 'online':
        return 'Online Odeme';
      default:
        return widget.order.paymentMethod;
    }
  }

  OrderStatus _getNextStatus() {
    switch (widget.order.status) {
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return OrderStatus.pickedUp;
      case OrderStatus.pickedUp:
        return OrderStatus.delivering;
      case OrderStatus.delivering:
        return OrderStatus.delivered;
      default:
        return widget.order.status;
    }
  }

  IconData _getNextStatusIcon() {
    switch (widget.order.status) {
      case OrderStatus.confirmed:
        return Icons.restaurant;
      case OrderStatus.preparing:
        return Icons.check_circle;
      case OrderStatus.ready:
        return Icons.delivery_dining;
      case OrderStatus.pickedUp:
        return Icons.local_shipping;
      case OrderStatus.delivering:
        return Icons.done_all;
      default:
        return Icons.arrow_forward;
    }
  }

  String _getNextStatusText() {
    switch (widget.order.status) {
      case OrderStatus.confirmed:
        return 'Hazirlaniyor';
      case OrderStatus.preparing:
        return 'Hazir';
      case OrderStatus.ready:
        return 'Teslim Alindi';
      case OrderStatus.pickedUp:
        return 'Yolda';
      case OrderStatus.delivering:
        return 'Teslim Edildi';
      default:
        return 'Sonraki';
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Simdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk once';
    if (diff.inHours < 24) return '${diff.inHours} saat once';
    return DateFormat('dd.MM HH:mm').format(dateTime);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kopyalandi'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyOrderNumber() {
    Clipboard.setData(ClipboardData(text: widget.order.orderNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Siparis numarasi kopyalandi'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // THERMAL RECEIPT PRINT (58mm/80mm)
  Future<void> _printThermalReceipt() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;

    final pdf = pw.Document();

    // 80mm thermal paper width = ~72mm printable = ~204 points
    const receiptWidth = 204.0;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          receiptWidth,
          double.infinity,
          marginAll: 8,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo/Business Name
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Column(
                  children: [
                    pw.Text(
                      merchant?.businessName ?? 'RESTORAN',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (merchant?.address != null)
                      pw.Text(
                        merchant!.address!,
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    if (merchant?.phone != null)
                      pw.Text(
                        'Tel: ${merchant!.phone}',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                  ],
                ),
              ),
              _buildDashedLine(),

              // Order Info
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'SIPARIS FISI',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '#${widget.order.orderNumber}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          DateFormat(
                            'dd.MM.yyyy',
                          ).format(widget.order.createdAt),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          DateFormat('HH:mm:ss').format(widget.order.createdAt),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildDashedLine(),

              // Customer Info
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MUSTERI',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      widget.order.customerName,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (widget.order.customerPhone != null)
                      pw.Text(
                        'Tel: ${widget.order.customerPhone}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'ADRES',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      widget.order.deliveryAddress,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    if (widget.order.deliveryInstructions != null &&
                        widget.order.deliveryInstructions!.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(border: pw.Border.all()),
                        child: pw.Text(
                          'NOT: ${widget.order.deliveryInstructions}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildDashedLine(),

              // Order Items
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Column(
                  children: [
                    // Header
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            'AD',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(
                            'URUN',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            'TUTAR',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),

                    // Items
                    ...widget.order.items.map(
                      (item) => pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  '${item.quantity}x',
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                              pw.Expanded(
                                flex: 4,
                                child: pw.Text(
                                  item.name,
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  (item.price * item.quantity).toStringAsFixed(
                                    2,
                                  ),
                                  style: const pw.TextStyle(fontSize: 9),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          // Options
                          if (item.options != null && item.options!.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 16),
                              child: pw.Text(
                                '+ ${item.options!.join(', ')}',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ),
                          // Notes
                          if (item.notes != null && item.notes!.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 16),
                              child: pw.Text(
                                '* ${item.notes}',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                            ),
                          pw.SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildDashedLine(),

              // Totals
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Column(
                  children: [
                    _buildTotalRow('Ara Toplam', widget.order.subtotal),
                    if (widget.order.deliveryFee > 0)
                      _buildTotalRow('Teslimat', widget.order.deliveryFee),
                    if (widget.order.serviceFee > 0)
                      _buildTotalRow('Hizmet Bedeli', widget.order.serviceFee),
                    if (widget.order.discount > 0)
                      _buildTotalRow('Indirim', -widget.order.discount),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOPLAM',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${widget.order.total.toStringAsFixed(2)} TL',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildDashedLine(),

              // Payment Method
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'ODEME',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      widget.order.paymentMethod == 'cash'
                          ? 'NAKIT'
                          : 'KREDI KARTI',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDashedLine(),

              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Bizi tercih ettiginiz icin',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      'TESEKKUR EDERIZ',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: widget.order.orderNumber,
                      width: 120,
                      height: 30,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Fis_${widget.order.orderNumber}',
    );
  }

  pw.Widget _buildDashedLine() {
    return pw.Container(
      width: double.infinity,
      child: pw.Text(
        '--------------------------------',
        style: const pw.TextStyle(fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTotalRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          '${amount < 0 ? '-' : ''}${amount.abs().toStringAsFixed(2)} TL',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  // A4 PRINT
  Future<void> _printOrder() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with Logo
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          merchant?.businessName ?? 'RESTORAN',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (merchant?.address != null)
                          pw.Text(
                            merchant!.address!,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        if (merchant?.phone != null)
                          pw.Text(
                            'Tel: ${merchant!.phone}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'SIPARIS FISI',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '#${widget.order.orderNumber}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          DateFormat(
                            'dd.MM.yyyy HH:mm',
                          ).format(widget.order.createdAt),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Customer & Delivery Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'MUSTERI BILGILERI',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            widget.order.customerName,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (widget.order.customerPhone != null)
                            pw.Text(
                              'Tel: ${widget.order.customerPhone}',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TESLIMAT ADRESI',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            widget.order.deliveryAddress,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          if (widget.order.deliveryInstructions != null &&
                              widget
                                  .order
                                  .deliveryInstructions!
                                  .isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.amber50,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'Not: ${widget.order.deliveryInstructions}',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Order Items Table
              pw.Text(
                'SIPARIS DETAYI',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Adet',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Urun',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Secenekler',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Not',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Birim',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Toplam',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...widget.order.items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${item.quantity}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item.name,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item.options?.join(', ') ?? '-',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item.notes ?? '-',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${item.price.toStringAsFixed(2)} TL',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${(item.price * item.quantity).toStringAsFixed(2)} TL',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Ara Toplam:',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            '${widget.order.subtotal.toStringAsFixed(2)} TL',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      if (widget.order.deliveryFee > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Teslimat:',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              '${widget.order.deliveryFee.toStringAsFixed(2)} TL',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      if (widget.order.discount > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Indirim:',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              '-${widget.order.discount.toStringAsFixed(2)} TL',
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.green,
                              ),
                            ),
                          ],
                        ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOPLAM:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${widget.order.total.toStringAsFixed(2)} TL',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Payment & Barcode
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Odeme: ${widget.order.paymentMethod == 'cash' ? 'Kapida Nakit' : 'Kredi Karti'}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Durum: ${widget.order.paymentStatus == 'paid' ? 'Odendi' : 'Odeme Bekliyor'}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: widget.order.orderNumber,
                    width: 150,
                    height: 40,
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Bizi tercih ettiginiz icin tesekkur ederiz!',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Siparis_${widget.order.orderNumber}',
    );
  }
}
