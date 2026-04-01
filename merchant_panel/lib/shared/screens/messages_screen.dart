import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/log_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/notification_sound_service.dart';
import '../../core/utils/app_dialogs.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  bool _showUnreadOnly = false;
  String? _selectedOrderId;
  String? _selectedMerchantId;
  RealtimeChannel? _channel;
  String? _merchantId;

  // Tab: 0 = Siparis mesajlari, 1 = Magaza mesajlari
  int _selectedTab = 0;
  List<Map<String, dynamic>> _storeConversations = [];
  bool _isStoreLoading = true;
  String? _selectedStoreCustomerId;
  RealtimeChannel? _storeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLoad();
    });
  }

  @override
  void dispose() {
    _removeChannel();
    _removeStoreChannel();
    super.dispose();
  }

  void _removeChannel() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
  }

  void _removeStoreChannel() {
    if (_storeChannel != null) {
      Supabase.instance.client.removeChannel(_storeChannel!);
      _storeChannel = null;
    }
  }

  void _initLoad() {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant != null) {
      _merchantId = merchant.id;
      _loadConversations();
      _setupRealtimeSubscription();
      _loadStoreConversations();
      _setupStoreRealtimeSubscription();
      return;
    }

    // Merchant henuz yuklenmemis - yuklenmesini dinle
    ref.listenManual(currentMerchantProvider, (previous, next) {
      final m = next.valueOrNull;
      if (m != null && _merchantId == null && mounted) {
        _merchantId = m.id;
        _loadConversations();
        _setupRealtimeSubscription();
        _loadStoreConversations();
        _setupStoreRealtimeSubscription();
      }
    });
  }

  Future<void> _loadConversations() async {
    if (_merchantId == null) return;

    try {
      // Sadece gerekli alanları çek (hafif sorgu)
      final messages = await Supabase.instance.client
          .from('order_messages')
          .select('id, order_id, sender_type, sender_name, message, is_read, created_at')
          .eq('merchant_id', _merchantId!)
          .order('created_at', ascending: false);

      // Group by order_id
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final msg in messages) {
        final orderId = msg['order_id'] as String;
        grouped.putIfAbsent(orderId, () => []);
        grouped[orderId]!.add(Map<String, dynamic>.from(msg));
      }

      final orderIds = grouped.keys.toList();
      if (orderIds.isEmpty) {
        if (mounted) {
          setState(() {
            _conversations = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Siparis bilgilerini al - merchant_id filtresi ekle (RLS uyumu icin)
      final orders = await Supabase.instance.client
          .from('orders')
          .select('id, order_number, status, customer_name, total_amount, created_at, user_id')
          .eq('merchant_id', _merchantId!)
          .inFilter('id', orderIds);

      final orderMap = <String, Map<String, dynamic>>{};
      final userIds = <String>{};
      for (final order in orders) {
        orderMap[order['id'] as String] = Map<String, dynamic>.from(order);
        final uid = order['user_id'] as String?;
        if (uid != null) userIds.add(uid);
      }

      // Musteri bilgilerini users tablosundan al
      Map<String, Map<String, dynamic>> userMap = {};
      if (userIds.isNotEmpty) {
        try {
          final users = await Supabase.instance.client
              .from('users')
              .select('id, full_name, phone, email, total_orders')
              .inFilter('id', userIds.toList());
          for (final u in users) {
            userMap[u['id'] as String] = Map<String, dynamic>.from(u);
          }
        } catch (e, st) { LogService.error('User lookup failed', error: e, stackTrace: st, source: 'MessagesScreen:_loadConversations'); }
      }

      // Build conversation list
      List<Map<String, dynamic>> conversations = [];
      for (final entry in grouped.entries) {
        final orderId = entry.key;
        final msgs = entry.value;
        final order = orderMap[orderId];
        if (order == null) continue;

        // Mesajlar zaten created_at DESC sıralı
        final unreadCount = msgs.where((m) =>
          m['sender_type'] == 'customer' && m['is_read'] != true
        ).length;

        final lastMessage = msgs.first;

        // Gercek musteri bilgisini users tablosundan al
        final userId = order['user_id'] as String?;
        final userInfo = userId != null ? userMap[userId] : null;
        final customerName = userInfo?['full_name'] as String? ??
            order['customer_name'] as String? ?? 'Musteri';
        final customerPhone = userInfo?['phone'] as String?;

        conversations.add({
          'order_id': orderId,
          'merchant_id': _merchantId!,
          'order_number': order['order_number'] ?? '',
          'order_status': order['status'] ?? '',
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'user_id': userId,
          'last_message': lastMessage['message'] ?? '',
          'last_message_sender': lastMessage['sender_type'] ?? '',
          'last_message_time': lastMessage['created_at'] ?? '',
          'unread_count': unreadCount,
          'total_messages': msgs.length,
        });
      }

      // Sort by last message time
      conversations.sort((a, b) =>
        (b['last_message_time'] as String).compareTo(a['last_message_time'] as String)
      );

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      LogService.error('loadConversations failed', error: e, stackTrace: st, source: 'MessagesScreen:_loadConversations');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtimeSubscription() {
    if (_merchantId == null) return;
    _removeChannel();

    // Postgres changes kullan (.stream() yerine) - sadece event bildirimi alır, bulk data çekmez
    _channel = Supabase.instance.client
        .channel('messages_screen_${_merchantId!}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: _merchantId!,
          ),
          callback: (_) {
            // Yeni mesaj geldiğinde conversation listesini yenile
            _loadConversations();
          },
        )
        .subscribe();
  }

  // ---- Store Messages ----

  Future<void> _loadStoreConversations() async {
    if (_merchantId == null) return;

    try {
      final messages = await Supabase.instance.client
          .from('store_messages')
          .select('id, customer_id, sender_type, sender_name, message, is_read, created_at')
          .eq('merchant_id', _merchantId!)
          .order('created_at', ascending: false);

      // Group by customer_id
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final msg in messages) {
        final customerId = msg['customer_id'] as String;
        grouped.putIfAbsent(customerId, () => []);
        grouped[customerId]!.add(Map<String, dynamic>.from(msg));
      }

      // Musteri bilgilerini users tablosundan al
      Map<String, Map<String, dynamic>> storeUserMap = {};
      if (grouped.keys.isNotEmpty) {
        try {
          final users = await Supabase.instance.client
              .from('users')
              .select('id, full_name, phone, email, total_orders')
              .inFilter('id', grouped.keys.toList());
          for (final u in users) {
            storeUserMap[u['id'] as String] = Map<String, dynamic>.from(u);
          }
        } catch (e, st) { LogService.error('Store user lookup failed', error: e, stackTrace: st, source: 'MessagesScreen:_loadStoreConversations'); }
      }

      List<Map<String, dynamic>> conversations = [];
      for (final entry in grouped.entries) {
        final customerId = entry.key;
        final msgs = entry.value;

        final unreadCount = msgs.where((m) =>
          m['sender_type'] == 'customer' && m['is_read'] != true
        ).length;

        final lastMessage = msgs.first;
        // Gercek musteri bilgisini users tablosundan al
        final userInfo = storeUserMap[customerId];
        final customerName = userInfo?['full_name'] as String? ??
            msgs
                .where((m) => m['sender_type'] == 'customer' && m['sender_name'] != null)
                .map((m) => m['sender_name'] as String)
                .firstOrNull ?? 'Musteri';
        final customerPhone = userInfo?['phone'] as String?;

        conversations.add({
          'customer_id': customerId,
          'merchant_id': _merchantId!,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'last_message': lastMessage['message'] ?? '',
          'last_message_sender': lastMessage['sender_type'] ?? '',
          'last_message_time': lastMessage['created_at'] ?? '',
          'unread_count': unreadCount,
          'total_messages': msgs.length,
        });
      }

      conversations.sort((a, b) =>
        (b['last_message_time'] as String).compareTo(a['last_message_time'] as String)
      );

      if (mounted) {
        setState(() {
          _storeConversations = conversations;
          _isStoreLoading = false;
        });
      }
    } catch (e, st) {
      LogService.error('loadStoreConversations failed', error: e, stackTrace: st, source: 'MessagesScreen:_loadStoreConversations');
      if (mounted) setState(() => _isStoreLoading = false);
    }
  }

  void _setupStoreRealtimeSubscription() {
    if (_merchantId == null) return;
    _removeStoreChannel();

    _storeChannel = Supabase.instance.client
        .channel('store_messages_screen_${_merchantId!}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'store_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: _merchantId!,
          ),
          callback: (payload) {
            _loadStoreConversations();
            // Play sound if new customer message and no chat detail open
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty && newRecord['sender_type'] == 'customer') {
              NotificationSoundService.playMessageSound();
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final isOrderTab = _selectedTab == 0;
    final conversations = isOrderTab ? _conversations : _storeConversations;
    final loading = isOrderTab ? _isLoading : _isStoreLoading;

    final filtered = _showUnreadOnly
        ? conversations.where((c) => (c['unread_count'] as int) > 0).toList()
        : conversations;

    final orderUnread = _conversations.fold<int>(
      0, (sum, c) => sum + (c['unread_count'] as int),
    );
    final storeUnread = _storeConversations.fold<int>(
      0, (sum, c) => sum + (c['unread_count'] as int),
    );

    final conversationList = Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.chat, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Mesajlar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  FilterChip(
                    label: Text(
                      'Okunmamis',
                      style: TextStyle(
                        color: _showUnreadOnly ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    selected: _showUnreadOnly,
                    onSelected: (val) => setState(() => _showUnreadOnly = val),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceLight,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: _showUnreadOnly ? AppColors.primary : AppColors.border,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () {
                      if (_merchantId == null) {
                        final m = ref.read(currentMerchantProvider).valueOrNull;
                        if (m != null) {
                          _merchantId = m.id;
                          _setupRealtimeSubscription();
                          _setupStoreRealtimeSubscription();
                        }
                      }
                      if (isOrderTab) {
                        setState(() => _isLoading = true);
                        _loadConversations();
                      } else {
                        setState(() => _isStoreLoading = true);
                        _loadStoreConversations();
                      }
                    },
                    icon: Icon(Icons.refresh, color: AppColors.textSecondary),
                    tooltip: 'Yenile',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tabs
              Row(
                children: [
                  _buildTab('Siparis', 0, orderUnread),
                  const SizedBox(width: 4),
                  _buildTab('Magaza', 1, storeUnread),
                ],
              ),
            ],
          ),
        ),

        // Conversation List
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final conv = filtered[index];
                        return isOrderTab
                            ? _buildConversationTile(conv)
                            : _buildStoreConversationTile(conv);
                      },
                    ),
        ),
      ],
    );

    // Detay paneli acik mi?
    final hasDetail = isOrderTab
        ? _selectedOrderId != null
        : _selectedStoreCustomerId != null;

    if (!hasDetail) {
      return conversationList;
    }

    return Row(
      children: [
        SizedBox(
          width: 380,
          child: conversationList,
        ),
        Container(width: 1, color: AppColors.border),
        Expanded(
          child: isOrderTab
              ? _ChatDetailPanel(
                  key: ValueKey(_selectedOrderId),
                  orderId: _selectedOrderId!,
                  merchantId: _selectedMerchantId!,
                  onClose: () => setState(() {
                    _selectedOrderId = null;
                    _selectedMerchantId = null;
                  }),
                  onMessagesRead: () => _loadConversations(),
                )
              : _StoreChatDetailPanel(
                  key: ValueKey(_selectedStoreCustomerId),
                  customerId: _selectedStoreCustomerId!,
                  merchantId: _merchantId!,
                  customerName: _storeConversations
                      .where((c) => c['customer_id'] == _selectedStoreCustomerId)
                      .map((c) => c['customer_name'] as String)
                      .firstOrNull ?? 'Musteri',
                  onClose: () => setState(() {
                    _selectedStoreCustomerId = null;
                  }),
                  onMessagesRead: () => _loadStoreConversations(),
                ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index, int unreadCount) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _showUnreadOnly ? 'Okunmamis mesaj yok' : 'Henuz mesaj yok',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Musteriler siparis verdikten sonra mesaj gonderebilir',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final orderId = conv['order_id'] as String;
    final isSelected = _selectedOrderId == orderId;
    final unreadCount = conv['unread_count'] as int;
    final status = conv['order_status'] as String;
    final customerPhone = conv['customer_phone'] as String?;
    final lastMessageTime = DateTime.tryParse(conv['last_message_time'] as String);
    final isFromCustomer = conv['last_message_sender'] == 'customer';

    // Time formatting
    String timeStr = '';
    if (lastMessageTime != null) {
      final now = DateTime.now();
      final diff = now.difference(lastMessageTime);
      if (diff.inMinutes < 1) {
        timeStr = 'Simdi';
      } else if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes} dk';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours} saat';
      } else {
        timeStr = '${diff.inDays} gun';
      }
    }

    final statusInfo = _getStatusInfo(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOrderId = orderId;
            _selectedMerchantId = conv['merchant_id'] as String;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : unreadCount > 0
                    ? AppColors.warning.withValues(alpha: 0.05)
                    : null,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              // Customer avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: unreadCount > 0
                    ? AppColors.primary
                    : AppColors.surfaceLight,
                child: Text(
                  (conv['customer_name'] as String).isNotEmpty
                      ? (conv['customer_name'] as String)[0].toUpperCase()
                      : 'M',
                  style: TextStyle(
                    color: unreadCount > 0 ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer name + time
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conv['customer_name'] as String,
                                style: TextStyle(
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (customerPhone != null && customerPhone.isNotEmpty)
                                Text(
                                  customerPhone,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: unreadCount > 0 ? AppColors.primary : AppColors.textMuted,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Order info + status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (statusInfo['color'] as Color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${conv['order_number']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: statusInfo['color'] as Color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          statusInfo['icon'] as IconData,
                          size: 12,
                          color: statusInfo['color'] as Color,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          statusInfo['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Last message preview
                    Row(
                      children: [
                        if (!isFromCustomer) ...[
                          Text(
                            'Siz: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            conv['last_message'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: unreadCount > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
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

              // Unread badge
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount',
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
      ),
    );
  }

  Widget _buildStoreConversationTile(Map<String, dynamic> conv) {
    final customerId = conv['customer_id'] as String;
    final isSelected = _selectedStoreCustomerId == customerId;
    final unreadCount = conv['unread_count'] as int;
    final customerPhone = conv['customer_phone'] as String?;
    final lastMessageTime = DateTime.tryParse(conv['last_message_time'] as String);
    final isFromCustomer = conv['last_message_sender'] == 'customer';

    String timeStr = '';
    if (lastMessageTime != null) {
      final now = DateTime.now();
      final diff = now.difference(lastMessageTime);
      if (diff.inMinutes < 1) {
        timeStr = 'Simdi';
      } else if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes} dk';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours} saat';
      } else {
        timeStr = '${diff.inDays} gun';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStoreCustomerId = customerId;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : unreadCount > 0
                    ? AppColors.warning.withValues(alpha: 0.05)
                    : null,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: unreadCount > 0
                    ? AppColors.primary
                    : AppColors.surfaceLight,
                child: Text(
                  (conv['customer_name'] as String).isNotEmpty
                      ? (conv['customer_name'] as String)[0].toUpperCase()
                      : 'M',
                  style: TextStyle(
                    color: unreadCount > 0 ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conv['customer_name'] as String,
                                style: TextStyle(
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (customerPhone != null && customerPhone.isNotEmpty)
                                Text(
                                  customerPhone,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: unreadCount > 0 ? AppColors.primary : AppColors.textMuted,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.storefront, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Magaza mesaji',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (!isFromCustomer) ...[
                          Text(
                            'Siz: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            conv['last_message'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: unreadCount > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
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
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount',
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
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {'label': 'Bekliyor', 'color': AppColors.warning, 'icon': Icons.hourglass_empty};
      case 'confirmed':
        return {'label': 'Onaylandi', 'color': AppColors.info, 'icon': Icons.check_circle_outline};
      case 'preparing':
        return {'label': 'Hazirlaniyor', 'color': const Color(0xFF8B5CF6), 'icon': Icons.restaurant};
      case 'ready':
        return {'label': 'Hazir', 'color': AppColors.success, 'icon': Icons.check_box};
      case 'picked_up':
        return {'label': 'Alindi', 'color': const Color(0xFF06B6D4), 'icon': Icons.local_shipping};
      case 'delivering':
        return {'label': 'Yolda', 'color': const Color(0xFF06B6D4), 'icon': Icons.delivery_dining};
      case 'delivered':
        return {'label': 'Teslim Edildi', 'color': AppColors.success, 'icon': Icons.done_all};
      case 'cancelled':
        return {'label': 'Iptal', 'color': AppColors.error, 'icon': Icons.cancel};
      default:
        return {'label': status, 'color': AppColors.textMuted, 'icon': Icons.help_outline};
    }
  }
}

// Chat detail panel - right side (order messages)
class _ChatDetailPanel extends StatefulWidget {
  final String orderId;
  final String merchantId;
  final VoidCallback onClose;
  final VoidCallback onMessagesRead;

  const _ChatDetailPanel({
    super.key,
    required this.orderId,
    required this.merchantId,
    required this.onClose,
    required this.onMessagesRead,
  });

  @override
  State<_ChatDetailPanel> createState() => _ChatDetailPanelState();
}

class _ChatDetailPanelState extends State<_ChatDetailPanel> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _orderInfo;
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('order_messages')
            .select()
            .eq('order_id', widget.orderId)
            .order('created_at', ascending: true),
        Supabase.instance.client
            .from('orders')
            .select('id, order_number, status, customer_name, total_amount, created_at, user_id')
            .eq('id', widget.orderId)
            .eq('merchant_id', widget.merchantId)
            .single(),
      ]);

      final orderData = results[1] as Map<String, dynamic>;

      // Musteri bilgilerini users tablosundan al
      final userId = orderData['user_id'] as String?;
      if (userId != null) {
        try {
          final userInfo = await Supabase.instance.client
              .from('users')
              .select('full_name, phone, email, total_orders')
              .eq('id', userId)
              .maybeSingle();
          if (userInfo != null) {
            orderData['customer_name'] = userInfo['full_name'] ?? orderData['customer_name'];
            orderData['customer_phone'] = userInfo['phone'];
            orderData['customer_email'] = userInfo['email'];
            orderData['customer_total_orders'] = userInfo['total_orders'];
          }
        } catch (e, st) { LogService.error('Customer info lookup failed', error: e, stackTrace: st, source: 'ChatDetailPanel:_loadData'); }
      }

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(results[0] as List);
          _orderInfo = orderData;
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    } catch (e, st) {
      LogService.error('ChatDetailPanel loadData failed', error: e, stackTrace: st, source: 'ChatDetailPanel:_loadData');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    // Postgres changes kullan (.stream() yerine) - çok daha hafif
    _channel = Supabase.instance.client
        .channel('chat_detail_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (payload) {
            if (mounted) {
              final newMsg = Map<String, dynamic>.from(payload.newRecord);
              // Yeni mesajı listeye ekle (tekrar sorgu atma)
              setState(() {
                // Duplicate kontrolü
                if (!_messages.any((m) => m['id'] == newMsg['id'])) {
                  _messages.add(newMsg);
                }
              });
              _scrollToBottom();

              // Müşteri mesajı ise ses çal ve okundu işaretle
              if (newMsg['sender_type'] == 'customer') {
                NotificationSoundService.playMessageSound();
                _markMessagesAsRead();
              }
            }
          },
        )
        .subscribe();
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

      widget.onMessagesRead();
    } catch (e, st) {
      LogService.error('Mark read failed', error: e, stackTrace: st, source: 'ChatDetailPanel:_markMessagesAsRead');
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
    _messageController.clear();

    try {
      await Supabase.instance.client.from('order_messages').insert({
        'order_id': widget.orderId,
        'merchant_id': widget.merchantId,
        'sender_type': 'merchant',
        'sender_id': widget.merchantId,
        'sender_name': 'Restoran',
        'message': text,
      });
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Mesaj gonderilemedi: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _orderInfo?['status'] as String? ?? '';
    final statusInfo = _getStatusInfo(status);

    return Column(
      children: [
        // Order Info Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onClose,
                icon: Icon(Icons.arrow_back, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  ((_orderInfo?['customer_name'] as String?) ?? 'M').isNotEmpty
                      ? ((_orderInfo?['customer_name'] as String?) ?? 'M')[0].toUpperCase()
                      : 'M',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          (_orderInfo?['customer_name'] as String?) ?? 'Musteri',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_orderInfo?['customer_phone'] != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.phone, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            _orderInfo!['customer_phone'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                        if (_orderInfo?['customer_total_orders'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_orderInfo!['customer_total_orders']} siparis',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Siparis #${_orderInfo?['order_number'] ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (statusInfo['color'] as Color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusInfo['icon'] as IconData,
                                size: 10,
                                color: statusInfo['color'] as Color,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                statusInfo['label'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: statusInfo['color'] as Color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Henuz mesaj yok',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isFromCustomer = message['sender_type'] == 'customer';
                    final time = DateTime.tryParse(message['created_at'] ?? '');
                    final timeStr = time != null
                        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                        : '';

                    // Date separator
                    Widget? dateSeparator;
                    if (index == 0 || _isDifferentDay(
                      _messages[index - 1]['created_at'] as String?,
                      message['created_at'] as String?,
                    )) {
                      final dateStr = time != null ? _formatDate(time) : '';
                      dateSeparator = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              dateStr,
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        if (dateSeparator != null) dateSeparator,
                        Align(
                          alignment: isFromCustomer
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.4,
                            ),
                            decoration: BoxDecoration(
                              color: isFromCustomer
                                  ? AppColors.surfaceLight
                                  : AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isFromCustomer ? 4 : 16),
                                bottomRight: Radius.circular(isFromCustomer ? 16 : 4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['message'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isFromCustomer
                                          ? (message['sender_name'] ?? 'Musteri')
                                          : 'Siz',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    if (!isFromCustomer && message['is_read'] == true) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.done_all, size: 12, color: AppColors.primary),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Mesaj yazin...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isDifferentDay(String? date1, String? date2) {
    if (date1 == null || date2 == null) return true;
    final d1 = DateTime.tryParse(date1);
    final d2 = DateTime.tryParse(date2);
    if (d1 == null || d2 == null) return true;
    return d1.year != d2.year || d1.month != d2.month || d1.day != d2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Bugun';
    if (dateOnly == yesterday) return 'Dun';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {'label': 'Bekliyor', 'color': AppColors.warning, 'icon': Icons.hourglass_empty};
      case 'confirmed':
        return {'label': 'Onaylandi', 'color': AppColors.info, 'icon': Icons.check_circle_outline};
      case 'preparing':
        return {'label': 'Hazirlaniyor', 'color': const Color(0xFF8B5CF6), 'icon': Icons.restaurant};
      case 'ready':
        return {'label': 'Hazir', 'color': AppColors.success, 'icon': Icons.check_box};
      case 'picked_up':
        return {'label': 'Alindi', 'color': const Color(0xFF06B6D4), 'icon': Icons.local_shipping};
      case 'delivering':
        return {'label': 'Yolda', 'color': const Color(0xFF06B6D4), 'icon': Icons.delivery_dining};
      case 'delivered':
        return {'label': 'Teslim Edildi', 'color': AppColors.success, 'icon': Icons.done_all};
      case 'cancelled':
        return {'label': 'Iptal', 'color': AppColors.error, 'icon': Icons.cancel};
      default:
        return {'label': status, 'color': AppColors.textMuted, 'icon': Icons.help_outline};
    }
  }
}

// Store chat detail panel - right side (store messages)
class _StoreChatDetailPanel extends StatefulWidget {
  final String customerId;
  final String merchantId;
  final String customerName;
  final VoidCallback onClose;
  final VoidCallback onMessagesRead;

  const _StoreChatDetailPanel({
    super.key,
    required this.customerId,
    required this.merchantId,
    required this.customerName,
    required this.onClose,
    required this.onMessagesRead,
  });

  @override
  State<_StoreChatDetailPanel> createState() => _StoreChatDetailPanelState();
}

class _StoreChatDetailPanelState extends State<_StoreChatDetailPanel> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final messages = await Supabase.instance.client
          .from('store_messages')
          .select()
          .eq('merchant_id', widget.merchantId)
          .eq('customer_id', widget.customerId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(messages);
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    } catch (e, st) {
      LogService.error('StoreChatDetail loadData failed', error: e, stackTrace: st, source: 'StoreChatDetailPanel:_loadData');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    _channel = Supabase.instance.client
        .channel('store_chat_detail_${widget.merchantId}_${widget.customerId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'store_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: widget.merchantId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newMsg = Map<String, dynamic>.from(payload.newRecord);
            if (newMsg['customer_id'] != widget.customerId) return;
            if (_messages.any((m) => m['id'] == newMsg['id'])) return;

            setState(() => _messages.add(newMsg));
            _scrollToBottom();

            if (newMsg['sender_type'] == 'customer') {
              NotificationSoundService.playMessageSound();
              _markMessagesAsRead();
            }
          },
        )
        .subscribe();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await Supabase.instance.client
          .from('store_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('merchant_id', widget.merchantId)
          .eq('customer_id', widget.customerId)
          .eq('sender_type', 'customer')
          .eq('is_read', false);

      widget.onMessagesRead();
    } catch (e, st) {
      LogService.error('Mark store read failed', error: e, stackTrace: st, source: 'StoreChatDetailPanel:_markMessagesAsRead');
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
    _messageController.clear();

    try {
      await Supabase.instance.client.from('store_messages').insert({
        'merchant_id': widget.merchantId,
        'customer_id': widget.customerId,
        'sender_type': 'merchant',
        'sender_id': widget.merchantId,
        'sender_name': 'Magaza',
        'message': text,
      });
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Mesaj gonderilemedi: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onClose,
                icon: Icon(Icons.arrow_back, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  widget.customerName.isNotEmpty
                      ? widget.customerName[0].toUpperCase()
                      : 'M',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.storefront, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Magaza mesaji',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Henuz mesaj yok',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isFromCustomer = message['sender_type'] == 'customer';
                    final time = DateTime.tryParse(message['created_at'] ?? '');
                    final timeStr = time != null
                        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                        : '';

                    // Date separator
                    Widget? dateSeparator;
                    if (index == 0 || _isDifferentDay(
                      _messages[index - 1]['created_at'] as String?,
                      message['created_at'] as String?,
                    )) {
                      final dateStr = time != null ? _formatDate(time) : '';
                      dateSeparator = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              dateStr,
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        if (dateSeparator != null) dateSeparator,
                        Align(
                          alignment: isFromCustomer
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.4,
                            ),
                            decoration: BoxDecoration(
                              color: isFromCustomer
                                  ? AppColors.surfaceLight
                                  : AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isFromCustomer ? 4 : 16),
                                bottomRight: Radius.circular(isFromCustomer ? 16 : 4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['message'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isFromCustomer
                                          ? (message['sender_name'] ?? 'Musteri')
                                          : 'Siz',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    if (!isFromCustomer && message['is_read'] == true) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.done_all, size: 12, color: AppColors.primary),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Mesaj yazin...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isDifferentDay(String? date1, String? date2) {
    if (date1 == null || date2 == null) return true;
    final d1 = DateTime.tryParse(date1);
    final d2 = DateTime.tryParse(date2);
    if (d1 == null || d2 == null) return true;
    return d1.year != d2.year || d1.month != d2.month || d1.day != d2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Bugun';
    if (dateOnly == yesterday) return 'Dun';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
