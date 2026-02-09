import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/ai_chat_service.dart';
import '../core/services/voice_input_service.dart';
import '../core/services/voice_output_service.dart';
import '../core/providers/ai_context_provider.dart';
import '../core/providers/cart_provider.dart';
import '../core/providers/store_cart_provider.dart';
import '../core/router/app_router.dart';

class FloatingAIAssistant extends ConsumerStatefulWidget {
  const FloatingAIAssistant({super.key});

  /// Call this to show notification alert on the robot
  static void showNotificationAlert(BuildContext context, {int count = 1}) {
    final state = context.findAncestorStateOfType<_FloatingAIAssistantState>();
    state?._showNotificationAlert(count);
  }

  @override
  ConsumerState<FloatingAIAssistant> createState() => _FloatingAIAssistantState();
}

class _FloatingAIAssistantState extends ConsumerState<FloatingAIAssistant>
    with TickerProviderStateMixin {
  late AnimationController _walkController;
  late AnimationController _glowController;
  late AnimationController _moveController;
  late AnimationController _hoverController;
  late AnimationController _shakeController;

  late Animation<double> _legAnimation;
  late Animation<double> _armAnimation;
  late Animation<double> _bodyBounceAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _horizontalAnimation;
  late Animation<double> _hoverScaleAnimation;
  late Animation<double> _shakeAnimation;

  bool _isHovered = false;
  bool _movingRight = true;
  Offset _position = const Offset(16, 160);
  bool _isManualPosition = false;
  bool _isChatOpen = false;
  OverlayEntry? _chatOverlayEntry;

  // Proactive message state
  bool _showProactiveMessage = false;
  String _proactiveMessage = '';
  String _proactiveEmoji = '🍽️';
  Timer? _proactiveTimer;
  bool _proactiveMessageDismissed = false;

  // Notification alert state
  bool _showNotificationBubble = false;
  int _notificationCount = 0;
  Timer? _notificationTimer;

  // Voice mode state (long-press on robot)
  bool _isVoiceMode = false;
  bool _isVoicePreparing = false;
  bool _isStoppingVoice = false; // Re-entry guard
  bool _pendingRelease = false; // User released during async init
  String _voicePartialText = '';
  String _voiceResponseText = '';
  bool _isVoiceProcessing = false;
  bool _showVoiceResponse = false;
  Timer? _longPressTimer;
  Timer? _voiceResponseDismissTimer;
  String? _voiceSessionId;
  bool _voiceServicesInitialized = false;

  @override
  void initState() {
    super.initState();

    _walkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _legAnimation = Tween<double>(begin: -0.25, end: 0.25).animate(
      CurvedAnimation(parent: _walkController, curve: Curves.easeInOut),
    );

    _armAnimation = Tween<double>(begin: 0.15, end: -0.15).animate(
      CurvedAnimation(parent: _walkController, curve: Curves.easeInOut),
    );

    _bodyBounceAnimation = Tween<double>(begin: 0, end: 2).animate(
      CurvedAnimation(parent: _walkController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _moveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _horizontalAnimation = Tween<double>(begin: 16, end: 120).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.linear),
    );

    _moveController.addListener(() {
      if (!_isManualPosition && !_isChatOpen) {
        setState(() {
          _movingRight = _moveController.status == AnimationStatus.forward;
        });
      }
    });

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );

    // Shake animation for notifications
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Pre-initialize voice services
    _initVoiceServices();

    // Start proactive message timer
    _startProactiveMessageTimer();
  }

  Future<void> _initVoiceServices() async {
    await voiceInputService.initialize();
    await voiceOutputService.initialize();
    _voiceServicesInitialized = true;
  }

  /// Show notification alert with shake animation
  void _showNotificationAlert(int count) {
    if (_isChatOpen || !mounted) return;

    // Cancel proactive message if showing
    if (_showProactiveMessage) {
      setState(() => _showProactiveMessage = false);
    }

    setState(() {
      _notificationCount = count;
      _showNotificationBubble = true;
    });

    // Shake animation
    _shakeController.forward().then((_) {
      _shakeController.reverse().then((_) {
        _shakeController.forward().then((_) {
          _shakeController.reverse();
        });
      });
    });

    // Auto hide after 6 seconds
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_isChatOpen) {
        setState(() => _showNotificationBubble = false);
      }
    });
  }

  void _dismissNotificationBubble() {
    _notificationTimer?.cancel();
    setState(() => _showNotificationBubble = false);
  }

  // ==================== VOICE MODE (Long-press) ====================

  void _onLongPressStart() {
    if (_isChatOpen) return;

    _isStoppingVoice = false;
    _pendingRelease = false;

    // Proactive/notification/response bubble'ları kapat
    if (_showVoiceResponse) _dismissVoiceResponse();
    setState(() {
      _showProactiveMessage = false;
      _showNotificationBubble = false;
      _isVoicePreparing = true;
    });

    // Kısa gecikme sonra ses modunu başlat
    _longPressTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _startVoiceMode();
    });
  }

  void _onLongPressEnd() {
    _longPressTimer?.cancel();

    if (_isVoiceMode) {
      // Walkie-talkie: parmak kaldırıldı → dinlemeyi durdur ve gönder
      _stopVoiceAndSend();
    } else if (_isVoicePreparing) {
      // Hazırlanma sırasında bıraktı → _startVoiceMode kontrol edecek
      _pendingRelease = true;
    }
  }

  Future<void> _startVoiceMode() async {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    // Animasyonları durdur
    _walkController.stop();
    _moveController.stop();
    await voiceOutputService.stop();

    // Ses tanıma başlatılamadıysa hata göster
    final initialized = await voiceInputService.initialize();
    if (!mounted) return;

    // Kullanıcı hazırlanma sırasında bıraktıysa iptal et
    if (_pendingRelease) {
      setState(() => _isVoicePreparing = false);
      _resumeAnimations();
      return;
    }

    if (!initialized) {
      setState(() {
        _isVoicePreparing = false;
        _voiceResponseText = 'Ses tanıma başlatılamadı. Mikrofon izni verdiğinizden emin olun.';
        _showVoiceResponse = true;
      });
      _voiceResponseDismissTimer?.cancel();
      _voiceResponseDismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) _dismissVoiceResponse();
      });
      _resumeAnimations();
      return;
    }

    setState(() {
      _isVoicePreparing = false;
      _isVoiceMode = true;
      _voicePartialText = '';
    });

    final started = await voiceInputService.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _voicePartialText = text);
      },
      onDone: () {
        // Otomatik bitişte de gönder (guard ile)
        if (mounted && _isVoiceMode && !_isStoppingVoice) {
          _stopVoiceAndSend();
        }
      },
    );

    if (!started && mounted) {
      setState(() {
        _isVoiceMode = false;
        _voiceResponseText = 'Ses dinleme başlatılamadı: ${voiceInputService.lastError}';
        _showVoiceResponse = true;
      });
      _voiceResponseDismissTimer?.cancel();
      _voiceResponseDismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) _dismissVoiceResponse();
      });
      _resumeAnimations();
      return;
    }

    // Eğer startListening sırasında kullanıcı bıraktıysa hemen gönder
    if (_pendingRelease && _isVoiceMode) {
      _stopVoiceAndSend();
    }
  }

  Future<void> _stopVoiceAndSend() async {
    // Re-entry guard: çift çağrıyı engelle
    if (_isStoppingVoice) return;
    _isStoppingVoice = true;

    // Hemen voice mode'u kapat (onDone callback tekrar çağırmasın)
    setState(() => _isVoiceMode = false);

    // Ses tanıyıcıya son sesleri işlemesi için kısa süre ver
    await Future.delayed(const Duration(milliseconds: 600));
    await voiceInputService.stopListening();

    final text = _voicePartialText.trim();
    setState(() {
      _voicePartialText = '';
    });

    if (text.isEmpty) {
      // Kullanıcıya geri bildirim ver
      setState(() {
        _voiceResponseText = 'Ses algılanamadı. Basılı tutarken konuşun.';
        _showVoiceResponse = true;
      });
      _voiceResponseDismissTimer?.cancel();
      _voiceResponseDismissTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _dismissVoiceResponse();
      });
      _resumeAnimations();
      _isStoppingVoice = false;
      return;
    }

    // İşleniyor göster
    setState(() => _isVoiceProcessing = true);

    try {
      final screenContext = ref.read(aiScreenContextProvider);
      final response = await AiChatService.sendMessage(
        message: text,
        sessionId: _voiceSessionId,
        screenContext: screenContext.toJson(),
        generateAudio: true,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _voiceSessionId = response['session_id'];
        final aiMsg = response['message'] ?? '';

        setState(() {
          _isVoiceProcessing = false;
          _voiceResponseText = aiMsg;
          _showVoiceResponse = true;
        });

        // Inline audio varsa doğrudan çal, yoksa ayrı TTS çağrısı yap
        voiceOutputService.setEnabled(true);
        final inlineAudio = response['audio'] as String?;
        void onAudioComplete() {
          if (!mounted) return;
          _voiceResponseDismissTimer?.cancel();
          _voiceResponseDismissTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) _dismissVoiceResponse();
          });
        }
        if (inlineAudio != null && inlineAudio.isNotEmpty) {
          voiceOutputService.playBase64Audio(inlineAudio, onComplete: onAudioComplete);
        } else {
          voiceOutputService.speak(aiMsg, onComplete: onAudioComplete);
        }

        // Aksiyon varsa işle
        final actions = response['actions'] as List<dynamic>?;
        if (actions != null && actions.isNotEmpty) {
          for (final action in actions) {
            final type = (action as Map<String, dynamic>)['type'] as String?;
            final payload = action['payload'] as Map<String, dynamic>?;
            if (type == 'navigate' && payload?['route'] != null) {
              _dismissVoiceResponse();
              Future.delayed(const Duration(milliseconds: 300), () {
                final navContext = rootNavigatorKey.currentContext;
                if (navContext != null) {
                  GoRouter.of(navContext).go(payload!['route'] as String);
                }
              });
            } else if (type == 'add_to_cart' && payload != null) {
              _addToCart(payload);
            }
          }
        }

        // Fallback: TTS hata verirse 3 dk sonra kapat
        _voiceResponseDismissTimer?.cancel();
        _voiceResponseDismissTimer = Timer(const Duration(seconds: 180), () {
          if (mounted) _dismissVoiceResponse();
        });
      } else {
        setState(() {
          _isVoiceProcessing = false;
          _voiceResponseText = response['error'] as String? ?? 'Üzgünüm, bir hata oluştu.';
          _showVoiceResponse = true;
        });
        _voiceResponseDismissTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) _dismissVoiceResponse();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVoiceProcessing = false;
        _voiceResponseText = 'Bağlantı hatası.';
        _showVoiceResponse = true;
      });
      _voiceResponseDismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) _dismissVoiceResponse();
      });
    }

    _resumeAnimations();
    _isStoppingVoice = false;
  }

  void _addToCart(Map<String, dynamic> payload) {
    final productId = payload['product_id'] as String? ?? '';
    final name = payload['name'] as String? ?? 'Ürün';
    final price = (payload['price'] is int)
        ? (payload['price'] as int).toDouble()
        : (payload['price'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = payload['image_url'] as String? ?? '';
    final merchantId = payload['merchant_id'] as String? ?? '';
    final merchantName = payload['merchant_name'] as String? ?? '';
    final quantity = (payload['quantity'] as num?)?.toInt() ?? 1;
    final merchantType = payload['merchant_type'] as String? ?? 'restaurant';

    if (merchantType == 'store' || merchantType == 'market') {
      ref.read(storeCartProvider.notifier).addItem(StoreCartItem(
        id: productId,
        productId: productId,
        name: name,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        storeId: merchantId,
        storeName: merchantName,
      ));
    } else {
      ref.read(cartProvider.notifier).addItem(CartItem(
        id: productId,
        name: name,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        merchantId: merchantId,
        merchantName: merchantName,
      ));
    }
  }

  void _dismissVoiceResponse() {
    _voiceResponseDismissTimer?.cancel();
    voiceOutputService.stop();
    setState(() {
      _showVoiceResponse = false;
      _isVoiceProcessing = false;
      _voiceResponseText = '';
    });
  }

  void _resumeAnimations() {
    if (!_isManualPosition && !_isChatOpen) {
      _moveController.repeat(reverse: true);
    }
    if (!_isChatOpen) {
      _walkController.repeat(reverse: true);
    }
  }

  void _startProactiveMessageTimer() {
    // Show proactive message after 5 seconds, then every 2 minutes
    _proactiveTimer = Timer(const Duration(seconds: 5), () {
      _fetchAndShowProactiveMessage();
    });
  }

  Future<void> _fetchAndShowProactiveMessage() async {
    if (_isChatOpen || _proactiveMessageDismissed || !mounted) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      final response = await Supabase.instance.client.rpc(
        'ai_get_proactive_message',
        params: {'p_user_id': userId},
      );

      if (response != null && response.isNotEmpty && mounted) {
        final data = response[0];
        setState(() {
          _proactiveMessage = data['message'] ?? 'Bugün ne yemek istersin?';
          _proactiveEmoji = data['emoji'] ?? '🍽️';
          _showProactiveMessage = true;
        });

        // Auto hide after 8 seconds
        Timer(const Duration(seconds: 8), () {
          if (mounted && !_isChatOpen) {
            setState(() => _showProactiveMessage = false);
          }
        });

        // Schedule next proactive message in 2 minutes
        _proactiveTimer = Timer(const Duration(minutes: 2), () {
          if (!_proactiveMessageDismissed) {
            _fetchAndShowProactiveMessage();
          }
        });
      }
    } catch (e) {
      // Silently fail - proactive messages are not critical
      debugPrint('Proactive message error: $e');
    }
  }

  void _dismissProactiveMessage() {
    setState(() {
      _showProactiveMessage = false;
      _proactiveMessageDismissed = true;
    });
    _proactiveTimer?.cancel();
  }

  @override
  void dispose() {
    _chatOverlayEntry?.remove();
    _walkController.dispose();
    _glowController.dispose();
    _moveController.dispose();
    _hoverController.dispose();
    _shakeController.dispose();
    _proactiveTimer?.cancel();
    _notificationTimer?.cancel();
    _longPressTimer?.cancel();
    _voiceResponseDismissTimer?.cancel();
    voiceInputService.stopListening();
    voiceOutputService.stop();
    super.dispose();
  }

  void _onTap() {
    if (_isChatOpen || _isVoiceMode || _isVoicePreparing) return;

    // Ses yanıtı gösteriliyorsa kapat
    if (_showVoiceResponse) {
      _dismissVoiceResponse();
      return;
    }

    setState(() => _isChatOpen = true);
    _walkController.stop();
    _moveController.stop();

    // Capture current screen context for the chat dialog
    final screenContext = ref.read(aiScreenContextProvider);

    _chatOverlayEntry = OverlayEntry(
      builder: (overlayContext) => Material(
        color: Colors.black54,
        child: Center(
          child: _AIChatDialog(
            onClose: _closeChat,
            screenContext: screenContext,
            onAddToCart: _addToCart,
          ),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_chatOverlayEntry!);
  }

  void _closeChat() {
    _chatOverlayEntry?.remove();
    _chatOverlayEntry = null;
    if (mounted) {
      setState(() => _isChatOpen = false);
      if (!_isManualPosition) {
        _moveController.repeat(reverse: true);
      }
      _walkController.repeat(reverse: true);
    }
  }

  void _onHoverStart() {
    setState(() => _isHovered = true);
    _hoverController.forward();
  }

  void _onHoverEnd() {
    setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_horizontalAnimation, _walkController, _glowAnimation, _hoverScaleAnimation, _shakeAnimation]),
      builder: (context, child) {
        final xPos = _isManualPosition || _isChatOpen ? _position.dx : _horizontalAnimation.value;

        return Positioned(
          right: xPos,
          bottom: _position.dy,
          child: GestureDetector(
            onPanStart: _isVoiceMode || _isVoicePreparing ? null : (_) {
              setState(() => _isManualPosition = true);
              _walkController.stop();
              _moveController.stop();
            },
            onPanUpdate: _isVoiceMode || _isVoicePreparing ? null : (details) {
              setState(() {
                _position = Offset(
                  _position.dx - details.delta.dx,
                  _position.dy - details.delta.dy,
                );
              });
            },
            onPanEnd: _isVoiceMode || _isVoicePreparing ? null : (_) {
              if (!_isChatOpen) {
                _walkController.repeat(reverse: true);
              }
            },
            onTap: _onTap,
            onLongPressStart: (_) => _onLongPressStart(),
            onLongPressEnd: (_) => _onLongPressEnd(),
            child: MouseRegion(
              onEnter: (_) => _onHoverStart(),
              onExit: (_) => _onHoverEnd(),
              cursor: SystemMouseCursors.click,
              child: Transform.scale(
                scale: _hoverScaleAnimation.value,
                child: Transform.rotate(
                  angle: _showNotificationBubble ? _shakeAnimation.value : 0,
                  child: SizedBox(
                    width: 80,
                    height: 175,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 55,
                              height: 13,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF00D4FF).withAlpha((100 * _glowAnimation.value).toInt()),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Transform.translate(
                              offset: Offset(0, _isChatOpen ? 0 : -_bodyBounceAnimation.value),
                              child: Transform.flip(
                                flipX: !_movingRight,
                                child: _buildFuturisticRobot(),
                              ),
                            ),
                          ),
                        ),
                        if (_isHovered && !_isChatOpen && !_showProactiveMessage && !_showNotificationBubble)
                          Positioned(
                            top: 0,
                            left: -50,
                            right: -50,
                            child: Center(child: _buildSpeechBubble()),
                          ),
                        // Proactive message bubble
                        if (_showProactiveMessage && !_isChatOpen && !_showNotificationBubble)
                          Positioned(
                            top: -10,
                            left: -100,
                            right: -100,
                            child: Center(child: _buildProactiveMessageBubble()),
                          ),
                        // Notification alert bubble
                        if (_showNotificationBubble && !_isChatOpen)
                          Positioned(
                            top: -15,
                            left: -80,
                            right: -80,
                            child: Center(child: _buildNotificationBubble()),
                          ),
                        // Voice preparing bubble
                        if (_isVoicePreparing && !_isVoiceMode)
                          Positioned(
                            top: -10,
                            left: -80,
                            right: -80,
                            child: Center(child: _buildVoicePreparingBubble()),
                          ),
                        // Voice listening bubble
                        if (_isVoiceMode)
                          Positioned(
                            top: -10,
                            left: -100,
                            right: -100,
                            child: Center(child: _buildVoiceListeningBubble()),
                          ),
                        // Voice processing bubble
                        if (_isVoiceProcessing && !_isVoiceMode)
                          Positioned(
                            top: -10,
                            left: -100,
                            right: -100,
                            child: Center(child: _buildVoiceProcessingBubble()),
                          ),
                        // Voice response bubble
                        if (_showVoiceResponse && !_isVoiceProcessing)
                          Positioned(
                            top: -15,
                            left: -110,
                            right: -110,
                            child: Center(child: _buildVoiceResponseBubble()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFuturisticRobot() {
    return SizedBox(
      width: 75,
      height: 115,
      child: CustomPaint(
        painter: _FuturisticRobotPainter(
          walkAnimation: (_isChatOpen || _isVoiceMode) ? 0 : _legAnimation.value,
          armAnimation: (_isChatOpen || _isVoiceMode) ? 0 : _armAnimation.value,
          glowIntensity: _glowAnimation.value,
          isHovered: _isHovered,
          isChatOpen: _isChatOpen,
          isVoiceListening: _isVoiceMode,
        ),
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00D4FF).withAlpha(150), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00D4FF).withAlpha(60), blurRadius: 12, spreadRadius: 1),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF00FF88), blurRadius: 5)],
                  ),
                ),
                const SizedBox(width: 5),
                const Flexible(
                  child: Text(
                    'Yardim?',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(size: const Size(12, 7), painter: _BubbleTailPainter()),
        ],
      ),
    );
  }

  Widget _buildProactiveMessageBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main bubble - tap to open chat
              GestureDetector(
                onTap: () {
                  _dismissProactiveMessage();
                  _onTap();
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00FF88).withAlpha(180), width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00FF88).withAlpha(80), blurRadius: 16, spreadRadius: 2),
                      BoxShadow(color: const Color(0xFF00D4FF).withAlpha(40), blurRadius: 20, spreadRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_proactiveEmoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _proactiveMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20), // Space for close button
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF00FF88)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Konuşalım!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Close button - positioned outside main gesture area
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _dismissProactiveMessage,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(80),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
          CustomPaint(size: const Size(14, 8), painter: _ProactiveBubbleTailPainter()),
        ],
      ),
    );
  }

  Widget _buildNotificationBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main notification bubble
              GestureDetector(
                onTap: () {
                  _dismissNotificationBubble();
                  // Navigate to notifications - you can customize this
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF6B6B).withAlpha(200), width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF6B6B).withAlpha(100), blurRadius: 16, spreadRadius: 2),
                      BoxShadow(color: const Color(0xFFFF6B6B).withAlpha(50), blurRadius: 24, spreadRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Bell icon with badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.notifications_active,
                                color: Color(0xFFFF6B6B),
                                size: 20,
                              ),
                              if (_notificationCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF6B6B),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _notificationCount > 9 ? '9+' : '$_notificationCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _notificationCount == 1
                                  ? 'Yeni bildiriminiz var!'
                                  : '$_notificationCount yeni bildirim!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Arrow pointing up to notification icon
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            color: Color(0xFFFF6B6B),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Bildirimleri gör',
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _dismissNotificationBubble,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(100),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Tail pointing to robot
          CustomPaint(size: const Size(14, 8), painter: _NotificationBubbleTailPainter()),
        ],
      ),
    );
  }

  // ==================== VOICE BUBBLES ====================

  Widget _buildVoicePreparingBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF8800).withAlpha(180), width: 2),
              boxShadow: [BoxShadow(color: const Color(0xFFFF8800).withAlpha(60), blurRadius: 12)],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, color: Color(0xFFFF8800), size: 16),
                SizedBox(width: 6),
                Text('Hazırlanıyor...', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          CustomPaint(size: const Size(12, 7), painter: _VoiceBubbleTailPainter(color: const Color(0xFFFF8800))),
        ],
      ),
    );
  }

  Widget _buildVoiceListeningBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF4444).withAlpha(200), width: 2),
              boxShadow: [BoxShadow(color: const Color(0xFFFF4444).withAlpha(80), blurRadius: 16, spreadRadius: 2)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic, color: Color(0xFFFF4444), size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _voicePartialText.isEmpty ? 'Dinleniyor...' : _voicePartialText,
                    style: TextStyle(
                      color: _voicePartialText.isEmpty ? Colors.white70 : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontStyle: _voicePartialText.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(size: const Size(12, 7), painter: _VoiceBubbleTailPainter(color: const Color(0xFFFF4444))),
        ],
      ),
    );
  }

  Widget _buildVoiceProcessingBubble() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00D4FF).withAlpha(180), width: 2),
            boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(60), blurRadius: 12)],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF))),
              SizedBox(width: 8),
              Text('Düşünüyor...', style: TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        CustomPaint(size: const Size(12, 7), painter: _VoiceBubbleTailPainter(color: const Color(0xFF00D4FF))),
      ],
    );
  }

  Widget _buildVoiceResponseBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  _dismissVoiceResponse();
                  _onTap(); // Chat dialog'u aç
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00FF88).withAlpha(200), width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00FF88).withAlpha(80), blurRadius: 16, spreadRadius: 2),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.smart_toy, color: Color(0xFF00FF88), size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _voiceResponseText,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _dismissVoiceResponse,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(100),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 10, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
          CustomPaint(size: const Size(12, 7), painter: _VoiceBubbleTailPainter(color: const Color(0xFF00FF88))),
        ],
      ),
    );
  }
}

class _VoiceBubbleTailPainter extends CustomPainter {
  final Color color;
  const _VoiceBubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF16213e), Color(0xFF0f0f23)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = color.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(size.width / 2, size.height);
    borderPath.lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(_VoiceBubbleTailPainter oldDelegate) => oldDelegate.color != color;
}

class _NotificationBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF16213e), Color(0xFF0f0f23)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFFFF6B6B).withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(size.width / 2, size.height);
    borderPath.lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF16213e), Color(0xFF0f0f23)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00D4FF).withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(size.width / 2, size.height);
    borderPath.lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProactiveBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF16213e), Color(0xFF0f0f23)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00FF88).withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(size.width / 2, size.height);
    borderPath.lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FuturisticRobotPainter extends CustomPainter {
  final double walkAnimation;
  final double armAnimation;
  final double glowIntensity;
  final bool isHovered;
  final bool isChatOpen;
  final bool isVoiceListening;

  _FuturisticRobotPainter({
    required this.walkAnimation,
    required this.armAnimation,
    required this.glowIntensity,
    required this.isHovered,
    required this.isChatOpen,
    this.isVoiceListening = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final scale = size.height / 140;
    final metalDark = const Color(0xFF2d3436);
    final metalMid = const Color(0xFF636e72);
    final metalLight = const Color(0xFFb2bec3);
    final glowColor = isVoiceListening
        ? const Color(0xFFFF4444)
        : isHovered ? const Color(0xFF00FF88) : const Color(0xFF00D4FF);
    final glowColorDim = glowColor.withAlpha((150 * glowIntensity).toInt());

    _drawLeg(canvas, centerX - 10 * scale, size.height - 45 * scale, walkAnimation, metalDark, metalMid, glowColor, scale);
    _drawLeg(canvas, centerX + 10 * scale, size.height - 45 * scale, -walkAnimation, metalDark, metalMid, glowColor, scale);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, size.height - 65 * scale), width: 32 * scale, height: 36 * scale),
      Radius.circular(6 * scale),
    );
    canvas.drawRRect(bodyRect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [metalLight, metalMid, metalDark]).createShader(bodyRect.outerRect));
    canvas.drawRRect(bodyRect, Paint()..color = glowColorDim..style = PaintingStyle.stroke..strokeWidth = 1.2);

    final chestCenter = Offset(centerX, size.height - 65 * scale);
    canvas.drawCircle(chestCenter, 10 * scale, Paint()..shader = RadialGradient(colors: [glowColor, glowColor.withAlpha((100 * glowIntensity).toInt()), Colors.transparent]).createShader(Rect.fromCircle(center: chestCenter, radius: 12 * scale)));
    canvas.drawCircle(chestCenter, 5 * scale, Paint()..color = glowColor);
    canvas.drawCircle(chestCenter, 2 * scale, Paint()..color = Colors.white);

    _drawArm(canvas, centerX - 20 * scale, size.height - 73 * scale, armAnimation, metalDark, metalMid, glowColor, scale);
    _drawArm(canvas, centerX + 20 * scale, size.height - 73 * scale, -armAnimation, metalDark, metalMid, glowColor, scale);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, size.height - 85 * scale), width: 10 * scale, height: 6 * scale), Radius.circular(2 * scale)), Paint()..color = metalDark);

    _drawHead(canvas, centerX, size.height - 105 * scale, metalDark, metalMid, metalLight, glowColor, glowIntensity, isHovered, scale);
  }

  void _drawLeg(Canvas canvas, double x, double y, double angle, Color dark, Color mid, Color glow, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4 * scale, 0, 8 * scale, 20 * scale), Radius.circular(2 * scale)), Paint()..shader = LinearGradient(colors: [mid, dark], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(Rect.fromLTWH(-4 * scale, 0, 8 * scale, 20 * scale)));
    canvas.drawCircle(Offset(0, 20 * scale), 4 * scale, Paint()..color = dark);
    canvas.drawCircle(Offset(0, 20 * scale), 2 * scale, Paint()..color = glow.withAlpha(100));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-3 * scale, 20 * scale, 6 * scale, 18 * scale), Radius.circular(2 * scale)), Paint()..color = dark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-6 * scale, 36 * scale, 12 * scale, 5 * scale), Radius.circular(2 * scale)), Paint()..color = mid);
    canvas.drawCircle(Offset(0, 38 * scale), 1.5 * scale, Paint()..color = glow);

    canvas.restore();
  }

  void _drawArm(Canvas canvas, double x, double y, double angle, Color dark, Color mid, Color glow, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    canvas.drawCircle(Offset.zero, 5 * scale, Paint()..color = mid);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-3 * scale, 0, 6 * scale, 16 * scale), Radius.circular(2 * scale)), Paint()..color = dark);
    canvas.drawCircle(Offset(0, 16 * scale), 3 * scale, Paint()..color = mid);
    canvas.drawCircle(Offset(0, 16 * scale), 1.5 * scale, Paint()..color = glow.withAlpha(80));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-2.5 * scale, 16 * scale, 5 * scale, 14 * scale), Radius.circular(2 * scale)), Paint()..color = dark);
    canvas.drawCircle(Offset(0, 32 * scale), 4 * scale, Paint()..color = mid);
    canvas.drawCircle(Offset(0, 32 * scale), 1.5 * scale, Paint()..color = glow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    canvas.restore();
  }

  void _drawHead(Canvas canvas, double x, double y, Color dark, Color mid, Color light, Color glow, double glowIntensity, bool isHovered, double scale) {
    final headPath = Path();
    headPath.moveTo(x - 14 * scale, y + 12 * scale);
    headPath.lineTo(x - 18 * scale, y - 4 * scale);
    headPath.quadraticBezierTo(x - 18 * scale, y - 16 * scale, x - 8 * scale, y - 18 * scale);
    headPath.lineTo(x + 8 * scale, y - 18 * scale);
    headPath.quadraticBezierTo(x + 18 * scale, y - 16 * scale, x + 18 * scale, y - 4 * scale);
    headPath.lineTo(x + 14 * scale, y + 12 * scale);
    headPath.close();

    canvas.drawPath(headPath, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light, mid, dark]).createShader(Rect.fromCenter(center: Offset(x, y), width: 36 * scale, height: 32 * scale)));
    canvas.drawPath(headPath, Paint()..color = glow.withAlpha((100 * glowIntensity).toInt())..style = PaintingStyle.stroke..strokeWidth = 1.2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 2 * scale), width: 28 * scale, height: 18 * scale), Radius.circular(4 * scale)), Paint()..color = const Color(0xFF0a0a0f));

    if (isHovered) {
      final leftEyePath = Path()..moveTo(x - 10 * scale, y)..quadraticBezierTo(x - 6 * scale, y - 5 * scale, x - 3 * scale, y);
      canvas.drawPath(leftEyePath, Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
      final rightEyePath = Path()..moveTo(x + 3 * scale, y)..quadraticBezierTo(x + 6 * scale, y - 5 * scale, x + 10 * scale, y);
      canvas.drawPath(rightEyePath, Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    } else {
      canvas.drawLine(Offset(x - 10 * scale, y - 2 * scale), Offset(x + 10 * scale, y - 2 * scale), Paint()..color = glow..strokeWidth = 2.5..strokeCap = StrokeCap.round..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * glowIntensity));
      canvas.drawCircle(Offset(x - 5 * scale, y - 2 * scale), 1.5 * scale, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x + 5 * scale, y - 2 * scale), 1.5 * scale, Paint()..color = Colors.white);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 23 * scale), width: 3 * scale, height: 10 * scale), Radius.circular(1.5 * scale)), Paint()..color = mid);
    canvas.drawCircle(Offset(x, y - 28 * scale), 4 * scale, Paint()..color = glow.withAlpha((200 * glowIntensity).toInt())..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(x, y - 28 * scale), 2.5 * scale, Paint()..color = glow);
    canvas.drawCircle(Offset(x, y - 28 * scale), 1 * scale, Paint()..color = Colors.white);

    _drawEarPanel(canvas, x - 20 * scale, y - 4 * scale, glow, glowIntensity, scale);
    _drawEarPanel(canvas, x + 20 * scale, y - 4 * scale, glow, glowIntensity, scale);
  }

  void _drawEarPanel(Canvas canvas, double x, double y, Color glow, double glowIntensity, double scale) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 5 * scale, height: 14 * scale), Radius.circular(1.5 * scale)), Paint()..color = const Color(0xFF2d3436));
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(x, y - 4 * scale + (i * 4 * scale)), 1 * scale, Paint()..color = glow.withAlpha((150 * glowIntensity).toInt()));
    }
  }

  @override
  bool shouldRepaint(_FuturisticRobotPainter oldDelegate) {
    return oldDelegate.walkAnimation != walkAnimation || oldDelegate.armAnimation != armAnimation || oldDelegate.glowIntensity != glowIntensity || oldDelegate.isHovered != isHovered || oldDelegate.isChatOpen != isChatOpen || oldDelegate.isVoiceListening != isVoiceListening;
  }
}

class _AIChatDialog extends StatefulWidget {
  final VoidCallback onClose;
  final AiScreenContext screenContext;
  final void Function(Map<String, dynamic> payload)? onAddToCart;
  const _AIChatDialog({required this.onClose, required this.screenContext, this.onAddToCart});

  @override
  State<_AIChatDialog> createState() => _AIChatDialogState();
}

class _AIChatDialogState extends State<_AIChatDialog> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  String? _sessionId;
  bool _isLoading = false;
  bool _isInitializing = true;

  bool _ttsEnabled = false;

  @override
  void initState() {
    super.initState();
    _initChat();
    _initTts();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    voiceOutputService.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await voiceOutputService.initialize();
    if (mounted) {
      setState(() {
        _ttsEnabled = voiceOutputService.isEnabled;
      });
    }
  }

  void _toggleTts() {
    setState(() {
      _ttsEnabled = !_ttsEnabled;
    });
    voiceOutputService.setEnabled(_ttsEnabled);
  }

  Future<void> _initChat() async {
    final existingSessionId = await AiChatService.getActiveSessionId();
    if (!mounted) return;

    if (existingSessionId != null) {
      _sessionId = existingSessionId;
      final history = await AiChatService.getChatHistory(existingSessionId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(history
          .where((msg) {
            // Filter out internal context messages (not meant for display)
            final content = msg['content'] as String? ?? '';
            return !_isInternalMessage(content);
          })
          .map((msg) => _ChatMessage(
            role: msg['role'],
            content: msg['content'],
            timestamp: DateTime.tryParse(msg['created_at'] ?? ''),
          )));
      });
    } else {
      _messages.add(_ChatMessage(role: 'assistant', content: 'Merhaba! Size nasil yardimci olabilirim?', timestamp: DateTime.now()));
    }

    setState(() => _isInitializing = false);
    _scrollToBottom();
  }

  /// Check if a message is internal context (not meant for display)
  bool _isInternalMessage(String content) {
    return content.startsWith('[ARAMA_SONUÇLARI]') ||
           content.startsWith('[ARAMA_SONUCLARI]') ||
           content.startsWith('[SEPETE_EKLENDİ]') ||
           content.startsWith('[SEPETE_EKLENDI]');
  }

  /// Strip internal tags from AI response text
  String _cleanInternalTags(String text) {
    // Remove lines starting with internal tags
    final lines = text.split('\n');
    final cleaned = lines.where((line) => !_isInternalMessage(line.trim())).join('\n').trim();
    return cleaned.isEmpty ? text : cleaned;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: message, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    // Add placeholder assistant message for streaming
    final assistantMessage = _ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    setState(() => _messages.add(assistantMessage));
    _scrollToBottom();

    try {
      final stream = AiChatService.sendMessageStream(
        message: message,
        sessionId: _sessionId,
        screenContext: widget.screenContext.toJson(),
      );

      await for (final event in stream) {
        if (!mounted) return;

        switch (event.type) {
          case AiStreamEventType.session:
            _sessionId = event.sessionId;
            break;

          case AiStreamEventType.chunk:
            setState(() {
              assistantMessage.content += event.text!;
            });
            _scrollToBottom();
            break;

          case AiStreamEventType.searchResults:
            setState(() {
              assistantMessage.products = event.searchResults;
            });
            _scrollToBottom();
            break;

          case AiStreamEventType.rentalResults:
            setState(() {
              assistantMessage.rentalCars = event.rentalResults;
            });
            _scrollToBottom();
            break;

          case AiStreamEventType.actions:
            if (event.actions != null) {
              for (final action in event.actions!) {
                _handleAction(action);
              }
            }
            break;

          case AiStreamEventType.done:
            setState(() {
              assistantMessage.isStreaming = false;
              if (event.fullMessage != null && event.fullMessage!.isNotEmpty) {
                assistantMessage.content = _cleanInternalTags(event.fullMessage!);
              }
              _isLoading = false;
            });
            // TTS after streaming completes
            if (_ttsEnabled && assistantMessage.content.isNotEmpty) {
              voiceOutputService.speak(assistantMessage.content);
            }
            break;

          case AiStreamEventType.error:
            setState(() {
              assistantMessage.isStreaming = false;
              _isLoading = false;
              if (assistantMessage.content.isEmpty) {
                assistantMessage.content = 'Üzgünüm, ${event.error}';
              }
            });
            break;
        }
      }

      // If stream ended without a done event
      if (mounted && assistantMessage.isStreaming) {
        setState(() {
          assistantMessage.isStreaming = false;
          _isLoading = false;
          if (assistantMessage.content.isEmpty) {
            assistantMessage.content = 'Bağlantı kesildi.';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        assistantMessage.isStreaming = false;
        _isLoading = false;
        if (assistantMessage.content.isEmpty) {
          assistantMessage.content = 'Hata: $e';
        }
      });
    }
    _scrollToBottom();
  }

  void _handleAction(Map<String, dynamic> action) {
    final type = action['type'] as String?;
    final payload = action['payload'] as Map<String, dynamic>?;
    if (type == null || payload == null) return;

    switch (type) {
      case 'add_to_cart':
        _handleAddToCart(payload);
        break;
      case 'navigate':
        _handleNavigate(payload);
        break;
    }
  }

  void _handleAddToCart(Map<String, dynamic> payload) {
    final name = payload['name'] ?? 'Ürün';
    final price = payload['price'] ?? 0;
    final quantity = payload['quantity'] ?? 1;

    // Actually add to cart via parent callback
    widget.onAddToCart?.call(payload);

    setState(() {
      _messages.add(_ChatMessage(
        role: 'assistant',
        content: '🛒 $name ($quantity adet - $price TL) sepete eklendi!',
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _handleNavigate(Map<String, dynamic> payload) {
    final route = payload['route'] as String?;
    if (route == null) return;
    // Close chat and navigate
    widget.onClose();
    // Navigation happens after overlay is removed
    Future.delayed(const Duration(milliseconds: 300), () {
      // Access navigator through global key
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null) {
        GoRouter.of(navContext).go(route);
      }
    });
  }

  Future<void> _startNewChat() async {
    if (_sessionId != null) await AiChatService.closeSession(_sessionId!);
    if (!mounted) return;
    setState(() {
      _sessionId = null;
      _messages.clear();
      _messages.add(_ChatMessage(role: 'assistant', content: 'Yeni sohbet baslatildi. Size nasil yardimci olabilirim?', timestamp: DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return PopScope(
      canPop: !_isLoading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Container(
          width: isMobile ? screenSize.width - 24 : 380,
          height: isMobile ? screenSize.height * 0.75 : 520,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00D4FF).withAlpha(100), width: 1.5),
            boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(30), blurRadius: 25, spreadRadius: 3)],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isInitializing
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
              ),
              if (_messages.length <= 2) _buildQuickActions(),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(100), blurRadius: 8)],
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SuperCyp AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF00FF88), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00FF88), blurRadius: 4)])),
                    const SizedBox(width: 5),
                    Text('Cevrimici', style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(150))),
                  ],
                ),
              ],
            ),
          ),
          // TTS toggle
          IconButton(
            icon: Icon(
              _ttsEnabled ? Icons.volume_up : Icons.volume_off,
              color: _ttsEnabled ? const Color(0xFF00FF88) : Colors.white.withAlpha(150),
              size: 20,
            ),
            onPressed: _toggleTts,
            tooltip: _ttsEnabled ? 'Sesi kapat' : 'Sesi aç',
          ),
          IconButton(icon: Icon(Icons.refresh, color: Colors.white.withAlpha(150), size: 20), onPressed: _startNewChat),
          IconButton(icon: Icon(Icons.close, color: Colors.white.withAlpha(150), size: 20), onPressed: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.role == 'user';
    final hasProducts = !isUser && message.products != null && message.products!.isNotEmpty;
    final hasRentalCars = !isUser && message.rentalCars != null && message.rentalCars!.isNotEmpty;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(width: 26, height: 26, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.smart_toy, color: Colors.white, size: 16)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isUser ? const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF0099CC)]) : null,
                      color: isUser ? null : const Color(0xFF252540),
                      borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isUser ? 16 : 4), bottomRight: Radius.circular(isUser ? 4 : 16)),
                      border: isUser ? null : Border.all(color: const Color(0xFF00D4FF).withAlpha(30)),
                    ),
                    child: message.isStreaming && message.content.isEmpty
                        ? Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => _TypingDot(delay: i * 150)))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(child: Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 13))),
                              if (message.isStreaming) const _StreamingCursor(),
                            ],
                          ),
                  ),
                  if (hasProducts)
                    _AiProductCardList(
                      products: message.products!,
                      onAddToCart: (payload) => _handleAddToCart(payload),
                    ),
                  if (hasRentalCars)
                    _AiRentalCardList(
                      cars: message.rentalCars!,
                      onBookNow: (car) {
                        final carId = car['car_id'] as String? ?? '';
                        if (carId.isNotEmpty) {
                          context.push('/rental/car/$carId');
                        }
                      },
                    ),
                ],
              ),
            ),
            if (isUser) const SizedBox(width: 34),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final questions = ['Siparis durumu nedir?', 'Yardim almak istiyorum', 'Odeme nasil yapilir?'];
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: questions.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActionChip(
            label: Text(questions[index], style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: const Color(0xFF252540),
            side: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () { _messageController.text = questions[index]; _sendMessage(); },
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)))),
      child: Row(
        children: [
          Expanded(
            child: Theme(
              data: ThemeData.dark().copyWith(
                textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: Color(0xFF00D4FF),
                  selectionColor: Color(0xFF00D4FF),
                  selectionHandleColor: Color(0xFF00D4FF),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF252540), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00D4FF).withAlpha(30))),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  cursorColor: const Color(0xFF00D4FF),
                  decoration: InputDecoration(
                    hintText: 'Mesajinizi yazin...',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(120), fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(80), blurRadius: 8)]),
            child: IconButton(
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _controller.repeat(reverse: true); });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: 7, height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: Color.lerp(const Color(0xFF00D4FF).withAlpha(100), const Color(0xFF00D4FF), _controller.value), shape: BoxShape.circle),
      ),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: _controller.value,
        child: Container(
          width: 2, height: 14,
          margin: const EdgeInsets.only(left: 2),
          color: const Color(0xFF00D4FF),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  String content;
  final DateTime? timestamp;
  final bool isError;
  bool isStreaming;
  List<Map<String, dynamic>>? products;
  List<Map<String, dynamic>>? rentalCars;

  _ChatMessage({required this.role, required this.content, this.timestamp, this.isError = false, this.isStreaming = false, this.products, this.rentalCars});
}

class _AiProductCardList extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final void Function(Map<String, dynamic> payload) onAddToCart;

  const _AiProductCardList({required this.products, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final displayProducts = products.length > 8 ? products.sublist(0, 8) : products;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: displayProducts.map((product) {
          return _AiProductCard(
            product: product,
            onAddToCart: () {
              onAddToCart({
                'product_id': product['id'] ?? '',
                'name': product['name'] ?? '',
                'price': product['price'] ?? 0,
                'image_url': product['image_url'] ?? '',
                'merchant_id': product['merchant_id'] ?? '',
                'merchant_name': product['merchant_name'] ?? '',
                'merchant_type': product['merchant_type'] ?? 'restaurant',
                'quantity': 1,
              });
            },
          );
        }).toList(),
      ),
    );
  }
}

class _AiProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onAddToCart;

  const _AiProductCard({required this.product, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final name = product['name'] as String? ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final originalPrice = (product['original_price'] as num?)?.toDouble();
    final imageUrl = product['image_url'] as String? ?? '';
    final merchantName = product['merchant_name'] as String? ?? '';
    final hasDiscount = originalPrice != null && originalPrice > price;
    final hasId = (product['id'] as String? ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF252540),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00D4FF).withAlpha(40)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48, height: 48,
              color: const Color(0xFF1a1a2e),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: Color(0xFF555577), size: 22))
                  : const Icon(Icons.fastfood, color: Color(0xFF555577), size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(merchantName, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('${price.toStringAsFixed(2)} TL', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.bold)),
                    if (hasDiscount) ...[
                      const SizedBox(width: 4),
                      Text('${originalPrice.toStringAsFixed(2)} TL', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10, decoration: TextDecoration.lineThrough)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (hasId)
            GestureDetector(
              onTap: onAddToCart,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiRentalCardList extends StatelessWidget {
  final List<Map<String, dynamic>> cars;
  final void Function(Map<String, dynamic> car) onBookNow;

  const _AiRentalCardList({required this.cars, required this.onBookNow});

  @override
  Widget build(BuildContext context) {
    final displayCars = cars.length > 8 ? cars.sublist(0, 8) : cars;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: displayCars.map((car) {
          return _AiRentalCard(car: car, onBookNow: () => onBookNow(car));
        }).toList(),
      ),
    );
  }
}

class _AiRentalCard extends StatelessWidget {
  final Map<String, dynamic> car;
  final VoidCallback onBookNow;

  const _AiRentalCard({required this.car, required this.onBookNow});

  @override
  Widget build(BuildContext context) {
    final brand = car['brand'] as String? ?? '';
    final model = car['model'] as String? ?? '';
    final dailyPrice = (car['daily_price'] as num?)?.toDouble() ?? 0;
    final category = car['category'] as String? ?? '';
    final transmission = car['transmission'] as String? ?? '';
    final fuelType = car['fuel_type'] as String? ?? '';
    final companyName = car['company_name'] as String? ?? '';
    final imageUrl = car['image_url'] as String? ?? '';
    final hasId = (car['car_id'] as String? ?? '').isNotEmpty;

    String categoryLabel = category;
    if (category == 'economy') categoryLabel = 'Ekonomi';
    else if (category == 'compact') categoryLabel = 'Kompakt';
    else if (category == 'midsize') categoryLabel = 'Orta';
    else if (category == 'fullsize') categoryLabel = 'Büyük';
    else if (category == 'suv') categoryLabel = 'SUV';
    else if (category == 'luxury') categoryLabel = 'Lüks';
    else if (category == 'van') categoryLabel = 'Van';

    String transLabel = transmission;
    if (transmission == 'automatic') transLabel = 'Otomatik';
    else if (transmission == 'manual') transLabel = 'Manuel';

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF252540),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7C4DFF).withAlpha(50)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 52, height: 52,
              color: const Color(0xFF1a1a2e),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, color: Color(0xFF555577), size: 24))
                  : const Icon(Icons.directions_car, color: Color(0xFF555577), size: 24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$brand $model', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(companyName, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF7C4DFF).withAlpha(40), borderRadius: BorderRadius.circular(4)),
                      child: Text(categoryLabel, style: const TextStyle(color: Color(0xFF7C4DFF), fontSize: 9, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 4),
                    Text('$transLabel · $fuelType', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 3),
                Text('${dailyPrice.toStringAsFixed(0)} TL/gün', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (hasId)
            GestureDetector(
              onTap: onBookNow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFAB47BC)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Kirala', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
