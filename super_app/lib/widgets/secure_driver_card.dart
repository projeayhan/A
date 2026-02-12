import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/communication_service.dart';
import '../core/utils/app_dialogs.dart';

/// Güvenli Sürücü Bilgi Kartı (Müşteri için)
class SecureDriverCard extends StatefulWidget {
  final String rideId;
  final VoidCallback? onCallPressed;
  final VoidCallback? onMessagePressed;

  const SecureDriverCard({
    super.key,
    required this.rideId,
    this.onCallPressed,
    this.onMessagePressed,
  });

  @override
  State<SecureDriverCard> createState() => _SecureDriverCardState();
}

class _SecureDriverCardState extends State<SecureDriverCard> {
  SecureDriverInfo? _driverInfo;
  bool _isLoading = true;
  int _unreadCount = 0;
  dynamic _messageChannel;

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
    _loadUnreadCount();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDriverInfo() async {
    final info = await CommunicationService.getSecureDriverInfo(widget.rideId);
    if (mounted) {
      setState(() {
        _driverInfo = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    final messages = await CommunicationService.getMessages(widget.rideId);
    if (mounted) {
      final unread = messages.where((m) => m.senderType == 'driver' && !m.isRead).length;
      setState(() => _unreadCount = unread);
    }
  }

  void _subscribeToMessages() {
    _messageChannel = CommunicationService.subscribeToMessages(widget.rideId, (message) {
      if (mounted && message.senderType == 'driver') {
        setState(() => _unreadCount++);
      }
    });
  }

  void _onMessageTap() {
    setState(() => _unreadCount = 0);
    CommunicationService.markMessagesAsRead(widget.rideId);
    if (widget.onMessagePressed != null) {
      widget.onMessagePressed!();
    } else {
      _openMessaging();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_driverInfo == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver info row
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _driverInfo!.driverName.isNotEmpty
                        ? _driverInfo!.driverName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverInfo!.driverName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _driverInfo!.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.shield,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Güvenli',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              if (_driverInfo!.canCall)
                _ActionButton(
                  icon: Icons.phone,
                  color: Colors.green,
                  onTap: widget.onCallPressed ?? () => _initiateSecureCall(),
                ),
              const SizedBox(width: 8),
              if (_driverInfo!.canMessage)
                _ActionButton(
                  icon: Icons.message,
                  color: theme.primaryColor,
                  onTap: _onMessageTap,
                  badgeCount: _unreadCount,
                ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1),
          const SizedBox(height: 12),

          // Vehicle info
          Row(
            children: [
              Icon(Icons.directions_car, size: 20, color: theme.hintColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverInfo!.vehicleFullInfo,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _driverInfo!.vehiclePlate,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _initiateSecureCall() async {
    HapticFeedback.mediumImpact();
    final callInfo = await CommunicationService.initiateCall(widget.rideId);
    if (callInfo != null && mounted) {
      // Telefon numarası varsa arama yap
      if (callInfo.phoneNumber != null && callInfo.phoneNumber!.isNotEmpty) {
        final phoneUri = Uri.parse('tel:${callInfo.phoneNumber}');
        try {
          await launchUrl(phoneUri);
        } catch (e) {
          debugPrint('Could not launch phone: $e');
          if (mounted) {
            AppDialogs.showError(context, 'Arama başlatılamadı');
          }
        }
      } else {
        // Numara yoksa bilgilendirme göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.phone, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Arama kaydedildi'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openMessaging() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerChatSheet(rideId: widget.rideId),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Müşteri Mesajlaşma Ekranı
class CustomerChatSheet extends StatefulWidget {
  final String rideId;

  const CustomerChatSheet({super.key, required this.rideId});

  @override
  State<CustomerChatSheet> createState() => _CustomerChatSheetState();
}

class _CustomerChatSheetState extends State<CustomerChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<RideMessage> _messages = [];
  List<QuickMessage> _quickMessages = [];
  bool _isLoading = true;
  bool _isSending = false;

  // Realtime subscription channel
  dynamic _messageChannel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadQuickMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    final messages = await CommunicationService.getMessages(widget.rideId);
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadQuickMessages() async {
    final quickMessages = await CommunicationService.getQuickMessages();
    if (mounted) {
      setState(() => _quickMessages = quickMessages);
    }
  }

  void _subscribeToMessages() {
    _messageChannel = CommunicationService.subscribeToMessages(widget.rideId, (message) {
      if (mounted) {
        // Duplikasyon kontrolü - aynı ID varsa ekleme
        final exists = _messages.any((m) => m.id == message.id);
        if (!exists) {
          setState(() => _messages.add(message));
          _scrollToBottom();
        }
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? content]) async {
    final text = content ?? _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final messageId = await CommunicationService.sendMessage(
      rideId: widget.rideId,
      content: text,
    );

    // Realtime mesajı getirecek, sadece hata durumunda yeniden yükle
    if (messageId == null && mounted) {
      await _loadMessages();
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _messageChannel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle & Header
          _buildHeader(theme),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(theme),
          ),

          // Quick messages
          if (_quickMessages.isNotEmpty) _buildQuickMessages(theme),

          // Input
          _buildInput(theme),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: theme.dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.message, color: theme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sürücüyle Mesajlaş',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.shield, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Güvenli iletişim',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Divider(height: 1),
      ],
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz mesaj yok',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Sürücünüzle iletişim kurmak için\nhazır mesajları kullanabilirsiniz',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isCustomer = message.isFromCustomer;

        return Align(
          alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isCustomer
                  ? theme.primaryColor.withValues(alpha: 0.1)
                  : theme.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isCustomer ? 16 : 4),
                bottomRight: Radius.circular(isCustomer ? 4 : 16),
              ),
              border: Border.all(
                color: isCustomer
                    ? theme.primaryColor.withValues(alpha: 0.2)
                    : theme.dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.content, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildQuickMessages(ThemeData theme) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickMessages.length,
        itemBuilder: (context, index) {
          final quick = _quickMessages[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(quick.messageTr, style: const TextStyle(fontSize: 12)),
              onPressed: () => _sendMessage(quick.messageTr),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Mesaj yazın...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : () => _sendMessage(),
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
    );
  }
}

/// Acil Durum Butonu (Müşteri için)
class CustomerEmergencyButton extends StatefulWidget {
  final String? rideId;
  final double? latitude;
  final double? longitude;

  const CustomerEmergencyButton({
    super.key,
    this.rideId,
    this.latitude,
    this.longitude,
  });

  @override
  State<CustomerEmergencyButton> createState() => _CustomerEmergencyButtonState();
}

class _CustomerEmergencyButtonState extends State<CustomerEmergencyButton> {
  bool _isPressed = false;
  Timer? _holdTimer;
  double _progress = 0;

  void _startHold() {
    setState(() => _isPressed = true);
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 0.02;
        if (_progress >= 1.0) {
          timer.cancel();
          _triggerEmergency();
        }
      });
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    setState(() {
      _isPressed = false;
      _progress = 0;
    });
  }

  Future<void> _triggerEmergency() async {
    HapticFeedback.heavyImpact();

    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Acil Durum'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Acil durum türünü seçin:'),
            const SizedBox(height: 16),
            _EmergencyOption(
              icon: Icons.sos,
              label: 'SOS - Tehlike',
              value: 'sos',
              color: Colors.red,
            ),
            _EmergencyOption(
              icon: Icons.car_crash,
              label: 'Kaza',
              value: 'accident',
              color: Colors.orange,
            ),
            _EmergencyOption(
              icon: Icons.local_hospital,
              label: 'Sağlık Sorunu',
              value: 'medical',
              color: Colors.blue,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );

    if (confirmed != null && mounted) {
      final alertId = await CommunicationService.createEmergencyAlert(
        rideId: widget.rideId,
        alertType: confirmed,
        latitude: widget.latitude ?? 0,
        longitude: widget.longitude ?? 0,
      );

      if (alertId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Acil durum bildirimi gönderildi'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    setState(() {
      _isPressed = false;
      _progress = 0;
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: _cancelHold,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _isPressed ? Colors.red : Colors.red.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isPressed)
              CircularProgressIndicator(
                value: _progress,
                color: Colors.white,
                strokeWidth: 3,
              ),
            Icon(
              Icons.sos,
              color: _isPressed ? Colors.white : Colors.red,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _EmergencyOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

/// Yolculuk Paylaşım Butonu (Müşteri için)
class ShareRideButton extends StatelessWidget {
  final String rideId;
  final Color? color;

  const ShareRideButton({
    super.key,
    required this.rideId,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showShareSheet(context),
      icon: Icon(Icons.share, color: color ?? Theme.of(context).primaryColor),
      tooltip: 'Yolculuğu Paylaş',
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShareRideSheet(rideId: rideId),
    );
  }
}

class _ShareRideSheet extends StatefulWidget {
  final String rideId;

  const _ShareRideSheet({required this.rideId});

  @override
  State<_ShareRideSheet> createState() => _ShareRideSheetState();
}

class _ShareRideSheetState extends State<_ShareRideSheet> {
  List<ShareLinkInfo> _shareLinks = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadShareLinks();
  }

  Future<void> _loadShareLinks() async {
    final links = await CommunicationService.getShareLinks(widget.rideId);
    if (mounted) {
      setState(() {
        _shareLinks = links;
      });
    }
  }

  Future<void> _createShareLink() async {
    setState(() => _isCreating = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final linkInfo = await CommunicationService.createShareLink(
      rideId: widget.rideId,
    );

    if (linkInfo != null && mounted) {
      setState(() => _shareLinks.insert(0, linkInfo));

      await Clipboard.setData(ClipboardData(text: linkInfo.shareUrl ?? ''));

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check, color: Colors.white),
              const SizedBox(width: 8),
              Text('Link kopyalandı!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.share, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      'Yolculuğu Paylaş',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Yakınlarınız konumunuzu canlı takip edebilir',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createShareLink,
                icon: _isCreating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.add_link),
                label: Text(_isCreating ? 'Oluşturuluyor...' : 'Yeni Link Oluştur'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          if (_shareLinks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Aktif Linkler',
                style: theme.textTheme.titleSmall,
              ),
            ),
            ..._shareLinks.take(3).map((link) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.link, color: theme.primaryColor),
              ),
              title: Text(link.recipientName ?? 'Paylaşım Linki'),
              subtitle: Text('${link.viewCount} görüntüleme'),
              trailing: IconButton(
                icon: Icon(Icons.copy),
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    ClipboardData(text: link.shareUrl ?? ''),
                  );
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Link kopyalandı')),
                    );
                  }
                },
              ),
            )),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
