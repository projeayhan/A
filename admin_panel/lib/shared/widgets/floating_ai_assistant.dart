import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/ai_chat_service.dart';
import '../../core/services/voice_input_service.dart';
import '../../core/services/voice_output_service.dart';

class FloatingAIAssistant extends StatefulWidget {
  const FloatingAIAssistant({super.key});

  @override
  State<FloatingAIAssistant> createState() => _FloatingAIAssistantState();
}

class _FloatingAIAssistantState extends State<FloatingAIAssistant>
    with TickerProviderStateMixin {
  late AnimationController _walkController;
  late AnimationController _glowController;
  late AnimationController _moveController;
  late AnimationController _hoverController;

  late Animation<double> _legAnimation;
  late Animation<double> _armAnimation;
  late Animation<double> _bodyBounceAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _horizontalAnimation;
  late Animation<double> _hoverScaleAnimation;

  bool _isHovered = false;
  bool _movingRight = true;
  Offset _position = const Offset(30, 80);
  bool _isManualPosition = false;
  bool _isChatOpen = false;

  // Voice mode state
  bool _isVoiceMode = false;
  bool _isVoicePreparing = false;
  bool _isStoppingVoice = false;
  bool _pendingRelease = false;
  String _voicePartialText = '';
  String _voiceResponseText = '';
  bool _isVoiceProcessing = false;
  bool _showVoiceResponse = false;
  Timer? _longPressTimer;
  Timer? _voiceResponseDismissTimer;
  String? _voiceSessionId;

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
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _horizontalAnimation = Tween<double>(begin: 30, end: 300).animate(
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
  }

  @override
  void dispose() {
    _walkController.dispose();
    _glowController.dispose();
    _moveController.dispose();
    _hoverController.dispose();
    _longPressTimer?.cancel();
    _voiceResponseDismissTimer?.cancel();
    voiceInputService.stopListening();
    voiceOutputService.stop();
    super.dispose();
  }

  void _onTap() {
    if (_isVoiceMode || _isVoicePreparing) return;
    if (_showVoiceResponse) {
      _dismissVoiceResponse();
      return;
    }

    setState(() => _isChatOpen = true);
    _walkController.stop();
    _moveController.stop();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _AIChatDialog(onClose: () => Navigator.of(context).pop()),
    ).then((_) {
      if (mounted) {
        setState(() => _isChatOpen = false);
        if (!_isManualPosition) _moveController.repeat(reverse: true);
        _walkController.repeat(reverse: true);
      }
    });
  }

  void _onHoverStart() {
    setState(() => _isHovered = true);
    _hoverController.forward();
  }

  void _onHoverEnd() {
    setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  // ==================== VOICE MODE ====================

  void _onLongPressStart() {
    if (_isChatOpen) return;
    _isStoppingVoice = false;
    _pendingRelease = false;
    if (_showVoiceResponse) _dismissVoiceResponse();
    setState(() => _isVoicePreparing = true);
    _longPressTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _startVoiceMode();
    });
  }

  void _onLongPressEnd() {
    _longPressTimer?.cancel();
    if (_isVoiceMode && !_isStoppingVoice) {
      _stopVoiceAndSend();
    } else if (_isVoicePreparing) {
      _pendingRelease = true;
    }
  }

  Future<void> _startVoiceMode() async {
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    _walkController.stop();
    _moveController.stop();
    await voiceOutputService.stop();

    final initialized = await voiceInputService.initialize();
    if (!mounted) return;

    if (_pendingRelease) {
      setState(() => _isVoicePreparing = false);
      _resumeAnimations();
      return;
    }

    if (!initialized) {
      setState(() {
        _isVoicePreparing = false;
        _voiceResponseText = 'Ses tanima baslatilamadi. Mikrofon izni verdiginizden emin olun.';
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
        if (mounted && _isVoiceMode && !_isStoppingVoice) _stopVoiceAndSend();
      },
    );

    if (!started && mounted) {
      setState(() {
        _isVoiceMode = false;
        _voiceResponseText = 'Ses dinleme baslatilamadi: ${voiceInputService.lastError}';
        _showVoiceResponse = true;
      });
      _voiceResponseDismissTimer?.cancel();
      _voiceResponseDismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) _dismissVoiceResponse();
      });
      _resumeAnimations();
      return;
    }

    if (_pendingRelease && _isVoiceMode) _stopVoiceAndSend();
  }

  Future<void> _stopVoiceAndSend() async {
    if (_isStoppingVoice) return;
    _isStoppingVoice = true;
    setState(() => _isVoiceMode = false);
    await Future.delayed(const Duration(milliseconds: 600));
    await voiceInputService.stopListening();
    final text = _voicePartialText.trim();
    setState(() => _voicePartialText = '');

    if (text.isEmpty) {
      setState(() {
        _voiceResponseText = 'Ses algilanamadi. Basili tutarken konusun.';
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

    setState(() => _isVoiceProcessing = true);

    try {
      final response = await AiChatService.sendMessage(
        message: text,
        sessionId: _voiceSessionId,
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
        _voiceResponseDismissTimer?.cancel();
        _voiceResponseDismissTimer = Timer(const Duration(seconds: 60), () {
          if (mounted) _dismissVoiceResponse();
        });
      } else {
        setState(() {
          _isVoiceProcessing = false;
          _voiceResponseText = 'Uzgunum, bir hata olustu.';
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
        _voiceResponseText = 'Baglanti hatasi.';
        _showVoiceResponse = true;
      });
      _voiceResponseDismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) _dismissVoiceResponse();
      });
    }

    _resumeAnimations();
    _isStoppingVoice = false;
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
    if (!_isManualPosition && !_isChatOpen) _moveController.repeat(reverse: true);
    if (!_isChatOpen) _walkController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_horizontalAnimation, _walkController, _glowAnimation, _hoverScaleAnimation]),
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
                _position = Offset(_position.dx - details.delta.dx, _position.dy - details.delta.dy);
              });
            },
            onPanEnd: _isVoiceMode || _isVoicePreparing ? null : (_) {
              if (!_isChatOpen) _walkController.repeat(reverse: true);
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
                child: SizedBox(
                  width: 100,
                  height: 200,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Ground glow
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Center(
                          child: Container(
                            width: 70, height: 15,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(colors: [
                                const Color(0xFF00D4FF).withAlpha((100 * _glowAnimation.value).toInt()),
                                Colors.transparent,
                              ]),
                              borderRadius: BorderRadius.circular(35),
                            ),
                          ),
                        ),
                      ),
                      // Robot
                      Positioned(
                        bottom: 10, left: 0, right: 0,
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
                      // Hover bubble
                      if (_isHovered && !_isChatOpen && !_isVoicePreparing && !_isVoiceMode && !_isVoiceProcessing && !_showVoiceResponse)
                        Positioned(top: 0, left: -50, right: -50, child: Center(child: _buildSpeechBubble())),
                      // Voice preparing
                      if (_isVoicePreparing && !_isVoiceMode)
                        Positioned(top: 0, left: -50, right: -50, child: Center(child: _buildVoicePreparingBubble())),
                      // Voice listening
                      if (_isVoiceMode)
                        Positioned(top: -10, left: -60, right: -60, child: Center(child: _buildVoiceListeningBubble())),
                      // Voice processing
                      if (_isVoiceProcessing && !_isVoiceMode)
                        Positioned(top: 0, left: -60, right: -60, child: Center(child: _buildVoiceProcessingBubble())),
                      // Voice response
                      if (_showVoiceResponse && !_isVoiceProcessing)
                        Positioned(top: -15, left: -80, right: -80, child: Center(child: _buildVoiceResponseBubble())),
                    ],
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
      width: 90, height: 140,
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
        return Transform.scale(scale: value, alignment: Alignment.bottomCenter, child: Opacity(opacity: value, child: child));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00D4FF).withAlpha(150), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(60), blurRadius: 15, spreadRadius: 1)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF00FF88), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00FF88), blurRadius: 6)])),
                const SizedBox(width: 8),
                const Flexible(child: Text('Yardim ister misiniz?', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          CustomPaint(size: const Size(16, 10), painter: _BubbleTailPainter()),
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
        return Transform.scale(scale: value, alignment: Alignment.bottomCenter, child: Opacity(opacity: value.clamp(0.0, 1.0), child: child));
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
                Text('Basili tutun...', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
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
        return Transform.scale(scale: value, alignment: Alignment.bottomCenter, child: Opacity(opacity: value.clamp(0.0, 1.0), child: child));
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
                      fontSize: 11, fontWeight: FontWeight.w500,
                      fontStyle: _voicePartialText.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 3, overflow: TextOverflow.ellipsis,
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
              Text('Dusunuyor...', style: TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
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
        return Transform.scale(scale: value, alignment: Alignment.bottomCenter, child: Opacity(opacity: value.clamp(0.0, 1.0), child: child));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () { _dismissVoiceResponse(); _onTap(); },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00FF88).withAlpha(200), width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFF00FF88).withAlpha(80), blurRadius: 16, spreadRadius: 2)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.smart_toy, color: Color(0xFF00FF88), size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(_voiceResponseText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 5, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4, right: 4,
                child: GestureDetector(
                  onTap: _dismissVoiceResponse,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(color: Colors.black.withAlpha(100), shape: BoxShape.circle),
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

// ==================== PAINTERS ====================

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0)..close();
    canvas.drawPath(path, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF16213e), Color(0xFF0f0f23)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final borderPath = Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0);
    canvas.drawPath(borderPath, Paint()..color = const Color(0xFF00D4FF).withAlpha(150)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VoiceBubbleTailPainter extends CustomPainter {
  final Color color;
  const _VoiceBubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0)..close();
    canvas.drawPath(path, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF16213e), Color(0xFF0f0f23)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final borderPath = Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0);
    canvas.drawPath(borderPath, Paint()..color = color.withAlpha(200)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_VoiceBubbleTailPainter oldDelegate) => oldDelegate.color != color;
}

// ==================== ROBOT PAINTER ====================

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
    final metalDark = const Color(0xFF2d3436);
    final metalMid = const Color(0xFF636e72);
    final metalLight = const Color(0xFFb2bec3);
    final glowColor = isVoiceListening ? const Color(0xFFFF4444) : isHovered ? const Color(0xFF00FF88) : const Color(0xFF00D4FF);
    final glowColorDim = glowColor.withAlpha((150 * glowIntensity).toInt());

    _drawLeg(canvas, centerX - 12, size.height - 55, walkAnimation, metalDark, metalMid, glowColor);
    _drawLeg(canvas, centerX + 12, size.height - 55, -walkAnimation, metalDark, metalMid, glowColor);

    final bodyRect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, size.height - 80), width: 40, height: 45), const Radius.circular(8));
    canvas.drawRRect(bodyRect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [metalLight, metalMid, metalDark]).createShader(bodyRect.outerRect));
    canvas.drawRRect(bodyRect, Paint()..color = glowColorDim..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final chestCenter = Offset(centerX, size.height - 80);
    canvas.drawCircle(chestCenter, 12, Paint()..shader = RadialGradient(colors: [glowColor, glowColor.withAlpha((100 * glowIntensity).toInt()), Colors.transparent]).createShader(Rect.fromCircle(center: chestCenter, radius: 15)));
    canvas.drawCircle(chestCenter, 6, Paint()..color = glowColor);
    canvas.drawCircle(chestCenter, 3, Paint()..color = Colors.white);

    _drawArm(canvas, centerX - 25, size.height - 90, armAnimation, metalDark, metalMid, glowColor, true);
    _drawArm(canvas, centerX + 25, size.height - 90, -armAnimation, metalDark, metalMid, glowColor, false);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, size.height - 105), width: 12, height: 8), const Radius.circular(2)), Paint()..color = metalDark);

    _drawHead(canvas, centerX, size.height - 130, metalDark, metalMid, metalLight, glowColor, glowIntensity, isHovered);
  }

  void _drawLeg(Canvas canvas, double x, double y, double angle, Color dark, Color mid, Color glow) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final upperLeg = RRect.fromRectAndRadius(Rect.fromLTWH(-5, 0, 10, 25), const Radius.circular(3));
    canvas.drawRRect(upperLeg, Paint()..shader = LinearGradient(colors: [mid, dark], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(upperLeg.outerRect));
    canvas.drawCircle(Offset(0, 25), 5, Paint()..color = dark);
    canvas.drawCircle(Offset(0, 25), 3, Paint()..color = glow.withAlpha(100));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4, 25, 8, 22), const Radius.circular(2)), Paint()..color = dark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-7, 45, 14, 6), const Radius.circular(2)), Paint()..color = mid);
    canvas.drawCircle(Offset(0, 48), 2, Paint()..color = glow);
    canvas.restore();
  }

  void _drawArm(Canvas canvas, double x, double y, double angle, Color dark, Color mid, Color glow, bool isLeft) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, 6, Paint()..color = mid);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4, 0, 8, 20), const Radius.circular(3)), Paint()..color = dark);
    canvas.drawCircle(Offset(0, 20), 4, Paint()..color = mid);
    canvas.drawCircle(Offset(0, 20), 2, Paint()..color = glow.withAlpha(80));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-3, 20, 6, 18), const Radius.circular(2)), Paint()..color = dark);
    canvas.drawCircle(Offset(0, 40), 5, Paint()..color = mid);
    canvas.drawCircle(Offset(0, 40), 2, Paint()..color = glow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.restore();
  }

  void _drawHead(Canvas canvas, double x, double y, Color dark, Color mid, Color light, Color glow, double glowIntensity, bool isHovered) {
    final headPath = Path()..moveTo(x - 18, y + 15)..lineTo(x - 22, y - 5)..quadraticBezierTo(x - 22, y - 20, x - 10, y - 22)..lineTo(x + 10, y - 22)..quadraticBezierTo(x + 22, y - 20, x + 22, y - 5)..lineTo(x + 18, y + 15)..close();
    canvas.drawPath(headPath, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light, mid, dark]).createShader(Rect.fromCenter(center: Offset(x, y), width: 44, height: 40)));
    canvas.drawPath(headPath, Paint()..color = glow.withAlpha((100 * glowIntensity).toInt())..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 2), width: 34, height: 22), const Radius.circular(5)), Paint()..color = const Color(0xFF0a0a0f));

    if (isHovered) {
      final leftEyePath = Path()..moveTo(x - 12, y)..quadraticBezierTo(x - 8, y - 6, x - 4, y);
      canvas.drawPath(leftEyePath, Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      final rightEyePath = Path()..moveTo(x + 4, y)..quadraticBezierTo(x + 8, y - 6, x + 12, y);
      canvas.drawPath(rightEyePath, Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
    } else {
      canvas.drawLine(Offset(x - 12, y - 2), Offset(x + 12, y - 2), Paint()..color = glow..strokeWidth = 3..strokeCap = StrokeCap.round..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * glowIntensity));
      canvas.drawCircle(Offset(x - 7, y - 2), 2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x + 7, y - 2), 2, Paint()..color = Colors.white);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 28), width: 4, height: 12), const Radius.circular(2)), Paint()..color = mid);
    canvas.drawCircle(Offset(x, y - 35), 5, Paint()..color = glow.withAlpha((200 * glowIntensity).toInt())..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(x, y - 35), 3, Paint()..color = glow);
    canvas.drawCircle(Offset(x, y - 35), 1.5, Paint()..color = Colors.white);

    _drawEarPanel(canvas, x - 24, y - 5, glow, glowIntensity);
    _drawEarPanel(canvas, x + 24, y - 5, glow, glowIntensity);
  }

  void _drawEarPanel(Canvas canvas, double x, double y, Color glow, double glowIntensity) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 6, height: 18), const Radius.circular(2)), Paint()..color = const Color(0xFF2d3436));
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(x, y - 5 + (i * 5)), 1.5, Paint()..color = glow.withAlpha((150 * glowIntensity).toInt()));
    }
  }

  @override
  bool shouldRepaint(_FuturisticRobotPainter oldDelegate) {
    return oldDelegate.walkAnimation != walkAnimation || oldDelegate.armAnimation != armAnimation || oldDelegate.glowIntensity != glowIntensity || oldDelegate.isHovered != isHovered || oldDelegate.isChatOpen != isChatOpen || oldDelegate.isVoiceListening != isVoiceListening;
  }
}

// ==================== AI CHAT DIALOG ====================

class _AIChatDialog extends StatefulWidget {
  final VoidCallback onClose;
  const _AIChatDialog({required this.onClose});

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
    if (mounted) setState(() => _ttsEnabled = voiceOutputService.isEnabled);
  }

  void _toggleTts() {
    setState(() => _ttsEnabled = !_ttsEnabled);
    voiceOutputService.setEnabled(_ttsEnabled);
  }

  Future<void> _initChat() async {
    final existingSessionId = await AiChatService.getActiveSessionId();

    if (existingSessionId != null) {
      _sessionId = existingSessionId;
      final history = await AiChatService.getChatHistory(existingSessionId);
      setState(() {
        _messages.addAll(history
            .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
            .map((msg) => _ChatMessage(
                  role: msg['role'],
                  content: msg['content'] ?? '',
                  timestamp: DateTime.tryParse(msg['created_at'] ?? ''),
                )));
      });
    } else {
      _messages.add(_ChatMessage(
        role: 'assistant',
        content: 'Merhaba! Ben admin AI asistani. Platform yonetimi, istatistikler, kullanici/isletme/siparis islemleri ile ilgili sorularinizi yanitlayabilirim.',
        timestamp: DateTime.now(),
      ));
    }

    setState(() => _isInitializing = false);
    _scrollToBottom();
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

    // Streaming placeholder
    final assistantMessage = _ChatMessage(role: 'assistant', content: '', timestamp: DateTime.now(), isStreaming: true);
    setState(() => _messages.add(assistantMessage));
    _scrollToBottom();

    try {
      final stream = AiChatService.sendMessageStream(message: message, sessionId: _sessionId);

      await for (final event in stream) {
        if (!mounted) return;
        switch (event.type) {
          case AiStreamEventType.session:
            _sessionId = event.sessionId;
            break;
          case AiStreamEventType.chunk:
            setState(() => assistantMessage.content += event.text!);
            _scrollToBottom();
            break;
          case AiStreamEventType.actions:
            break;
          case AiStreamEventType.done:
            setState(() {
              assistantMessage.isStreaming = false;
              if (event.fullMessage != null && event.fullMessage!.isNotEmpty) {
                assistantMessage.content = event.fullMessage!;
              }
              _isLoading = false;
            });
            if (_ttsEnabled && assistantMessage.content.isNotEmpty) {
              voiceOutputService.speak(assistantMessage.content);
            }
            break;
          case AiStreamEventType.error:
            setState(() {
              assistantMessage.isStreaming = false;
              _isLoading = false;
              if (assistantMessage.content.isEmpty) assistantMessage.content = 'Uzgunum, ${event.error}';
            });
            break;
        }
      }

      if (mounted && assistantMessage.isStreaming) {
        setState(() {
          assistantMessage.isStreaming = false;
          _isLoading = false;
          if (assistantMessage.content.isEmpty) assistantMessage.content = 'Baglanti kesildi.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        assistantMessage.isStreaming = false;
        _isLoading = false;
        if (assistantMessage.content.isEmpty) assistantMessage.content = 'Hata: $e';
      });
    }
    _scrollToBottom();
  }

  Future<void> _startNewChat() async {
    if (_sessionId != null) await AiChatService.closeSession(_sessionId!);
    setState(() {
      _sessionId = null;
      _messages.clear();
      _messages.add(_ChatMessage(role: 'assistant', content: 'Yeni sohbet baslatildi. Size nasil yardimci olabilirim?', timestamp: DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 500,
        height: 620,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF00D4FF).withAlpha(100), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(30), blurRadius: 30, spreadRadius: 5)],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isInitializing
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                    ),
            ),
            if (_messages.length <= 2) _buildQuickActions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(100), blurRadius: 10)],
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin AI Asistan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF00FF88), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00FF88), blurRadius: 6)])),
                    const SizedBox(width: 6),
                    Text('Platform Yonetimi', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150))),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off, color: _ttsEnabled ? const Color(0xFF00FF88) : Colors.white.withAlpha(150)),
            onPressed: _toggleTts,
            tooltip: _ttsEnabled ? 'Sesi kapat' : 'Sesi ac',
          ),
          IconButton(icon: Icon(Icons.refresh, color: Colors.white.withAlpha(150)), onPressed: _startNewChat),
          IconButton(icon: Icon(Icons.close, color: Colors.white.withAlpha(150)), onPressed: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(width: 30, height: 30, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isUser ? const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF0099CC)]) : null,
                  color: isUser ? null : const Color(0xFF252540),
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18)),
                  border: isUser ? null : Border.all(color: const Color(0xFF00D4FF).withAlpha(30)),
                ),
                child: message.isStreaming && message.content.isEmpty
                    ? Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => _TypingDot(delay: i * 150)))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(child: Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 14))),
                          if (message.isStreaming) const _StreamingCursor(),
                        ],
                      ),
              ),
            ),
            if (isUser) const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final questions = [
      'Bugunun siparis istatistikleri',
      'Onay bekleyen isletmeler',
      'Son 7 gun gelir raporu',
      'Aktif promosyonlar',
    ];
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: questions.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(questions[index], style: const TextStyle(fontSize: 11, color: Colors.white)),
            backgroundColor: const Color(0xFF252540),
            side: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)),
            onPressed: () { _messageController.text = questions[index]; _sendMessage(); },
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)))),
      child: Row(
        children: [
          Expanded(
            child: Theme(
              data: ThemeData.dark().copyWith(
                textSelectionTheme: const TextSelectionThemeData(cursorColor: Color(0xFF00D4FF), selectionColor: Color(0xFF00D4FF), selectionHandleColor: Color(0xFF00D4FF)),
              ),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF252540), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF00D4FF).withAlpha(30))),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  cursorColor: const Color(0xFF00D4FF),
                  decoration: InputDecoration(hintText: 'Komut veya soru yazin...', hintStyle: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(80), blurRadius: 10)]),
            child: IconButton(
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== HELPER WIDGETS ====================

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
        width: 8, height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
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
        child: Container(width: 2, height: 14, margin: const EdgeInsets.only(left: 2), color: const Color(0xFF00D4FF)),
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

  _ChatMessage({required this.role, required this.content, this.timestamp, this.isError = false, this.isStreaming = false});
}
