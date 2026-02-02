import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/communication_service.dart';
import '../core/theme/app_theme.dart';

/// Güvenli Müşteri Bilgi Kartı (Sürücü için)
class SecureCustomerCard extends StatefulWidget {
  final String rideId;
  final VoidCallback? onCallPressed;
  final VoidCallback? onMessagePressed;

  const SecureCustomerCard({
    super.key,
    required this.rideId,
    this.onCallPressed,
    this.onMessagePressed,
  });

  @override
  State<SecureCustomerCard> createState() => _SecureCustomerCardState();
}

class _SecureCustomerCardState extends State<SecureCustomerCard> {
  SecureCustomerInfo? _customerInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  Future<void> _loadCustomerInfo() async {
    final info = await CommunicationService.getSecureCustomerInfo(widget.rideId);
    if (mounted) {
      setState(() {
        _customerInfo = info;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_customerInfo == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _customerInfo!.customerName.isNotEmpty
                    ? _customerInfo!.customerName[0].toUpperCase()
                    : 'Y',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 20,
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
                  'Yolcu',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _customerInfo!.customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.shield,
                      size: 12,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Güvenli iletişim',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Call button
          if (_customerInfo!.canCall)
            _SecureActionButton(
              icon: Icons.phone,
              color: AppColors.success,
              onTap: widget.onCallPressed ?? () => _initiateSecureCall(),
              tooltip: 'Güvenli Ara',
            ),
          const SizedBox(width: 8),

          // Message button
          if (_customerInfo!.canMessage)
            _SecureActionButton(
              icon: Icons.message,
              color: AppColors.info,
              onTap: widget.onMessagePressed ?? () => _openMessaging(),
              tooltip: 'Mesaj Gönder',
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Arama başlatılamadı'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        // Numara yoksa bilgilendirme göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.phone, color: Colors.white),
                const SizedBox(width: 8),
                Text('Arama kaydedildi'),
              ],
            ),
            backgroundColor: AppColors.success,
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
      builder: (context) => RideChatSheet(rideId: widget.rideId),
    );
  }
}

/// Güvenli Arama Butonu
class _SecureActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _SecureActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

/// Yolculuk Mesajlaşma Ekranı
class RideChatSheet extends StatefulWidget {
  final String rideId;

  const RideChatSheet({super.key, required this.rideId});

  @override
  State<RideChatSheet> createState() => _RideChatSheetState();
}

class _RideChatSheetState extends State<RideChatSheet> {
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
    final quickMessages = await CommunicationService.getQuickMessages(
      userType: 'driver',
    );
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle & Header
          _buildHeader(),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(),
          ),

          // Quick messages
          if (_quickMessages.isNotEmpty) _buildQuickMessages(),

          // Input
          _buildInput(),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AppColors.border,
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
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.message, color: AppColors.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mesajlar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.shield, size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Güvenli iletişim',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
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
        Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz mesaj yok',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hazır mesajları kullanarak\nhızlıca iletişim kurun',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textHint,
              ),
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
        final isDriver = message.isFromDriver;

        return Align(
          alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isDriver
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isDriver ? 16 : 4),
                bottomRight: Radius.circular(isDriver ? 4 : 16),
              ),
              border: Border.all(
                color: isDriver
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
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

  Widget _buildQuickMessages() {
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
              label: Text(
                quick.messageTr,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: AppColors.background,
              side: BorderSide(color: AppColors.border),
              onPressed: () => _sendMessage(quick.messageTr),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    return Container(
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
              decoration: InputDecoration(
                hintText: 'Mesaj yazın...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppColors.background,
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
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : () => _sendMessage(),
              icon: _isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.secondary,
                      ),
                    )
                  : Icon(Icons.send, color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acil Durum Butonu
class EmergencyButton extends StatefulWidget {
  final String? rideId;
  final double? latitude;
  final double? longitude;

  const EmergencyButton({
    super.key,
    this.rideId,
    this.latitude,
    this.longitude,
  });

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> {
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
            Icon(Icons.warning, color: AppColors.error),
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
              color: AppColors.error,
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
              color: AppColors.info,
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
            backgroundColor: AppColors.error,
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
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _isPressed
              ? AppColors.error
              : AppColors.error.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.error,
            width: 2,
          ),
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
              color: _isPressed ? Colors.white : AppColors.error,
              size: 28,
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

/// Yolculuk Paylaşım Butonu
class ShareRideButton extends StatelessWidget {
  final String rideId;

  const ShareRideButton({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showShareDialog(context),
      icon: Icon(Icons.share, color: AppColors.info),
      tooltip: 'Yolculuğu Paylaş',
    );
  }

  void _showShareDialog(BuildContext context) {
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
  bool _isLoading = true;
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
        _isLoading = false;
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

      // Kopyala
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
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
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
                    Icon(Icons.share, color: AppColors.info),
                    const SizedBox(width: 12),
                    const Text(
                      'Yolculuğu Paylaş',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Yakınlarınız konumunuzu canlı takip edebilir',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Create new link button
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

            // Existing links
            if (_shareLinks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Aktif Linkler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._shareLinks.take(3).map((link) => ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.link, color: AppColors.info),
                ),
                title: Text(
                  link.recipientName ?? 'Paylaşım Linki',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${link.viewCount} görüntüleme',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.copy, color: AppColors.textSecondary),
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
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
