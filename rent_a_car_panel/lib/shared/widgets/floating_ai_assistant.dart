import 'package:flutter/material.dart';

import '../../core/services/ai_chat_service.dart';

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

  @override
  void initState() {
    super.initState();

    _walkController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this)..repeat(reverse: true);
    _legAnimation = Tween<double>(begin: -0.25, end: 0.25).animate(CurvedAnimation(parent: _walkController, curve: Curves.easeInOut));
    _armAnimation = Tween<double>(begin: 0.15, end: -0.15).animate(CurvedAnimation(parent: _walkController, curve: Curves.easeInOut));
    _bodyBounceAnimation = Tween<double>(begin: 0, end: 2).animate(CurvedAnimation(parent: _walkController, curve: Curves.easeInOut));

    _glowController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _moveController = AnimationController(duration: const Duration(seconds: 10), vsync: this)..repeat(reverse: true);
    _horizontalAnimation = Tween<double>(begin: 30, end: 300).animate(CurvedAnimation(parent: _moveController, curve: Curves.linear));
    _moveController.addListener(() {
      if (!_isManualPosition && !_isChatOpen) setState(() => _movingRight = _moveController.status == AnimationStatus.forward);
    });

    _hoverController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _walkController.dispose();
    _glowController.dispose();
    _moveController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _onTap() {
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
            onPanStart: (_) { setState(() => _isManualPosition = true); _walkController.stop(); _moveController.stop(); },
            onPanUpdate: (details) => setState(() => _position = Offset(_position.dx - details.delta.dx, _position.dy - details.delta.dy)),
            onPanEnd: (_) { if (!_isChatOpen) _walkController.repeat(reverse: true); },
            onTap: _onTap,
            child: MouseRegion(
              onEnter: (_) { setState(() => _isHovered = true); _hoverController.forward(); },
              onExit: (_) { setState(() => _isHovered = false); _hoverController.reverse(); },
              cursor: SystemMouseCursors.click,
              child: Transform.scale(
                scale: _hoverScaleAnimation.value,
                child: SizedBox(
                  width: 100,
                  height: 200,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(bottom: 0, left: 0, right: 0, child: Center(child: Container(width: 70, height: 15, decoration: BoxDecoration(gradient: RadialGradient(colors: [const Color(0xFF10B981).withAlpha((100 * _glowAnimation.value).toInt()), Colors.transparent]), borderRadius: BorderRadius.circular(35))))),
                      Positioned(bottom: 10, left: 0, right: 0, child: Center(child: Transform.translate(offset: Offset(0, _isChatOpen ? 0 : -_bodyBounceAnimation.value), child: Transform.flip(flipX: !_movingRight, child: _buildFuturisticRobot())))),
                      if (_isHovered && !_isChatOpen) Positioned(top: 0, left: -50, right: -50, child: Center(child: _buildSpeechBubble())),
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
      width: 90,
      height: 140,
      child: CustomPaint(
        painter: _FuturisticRobotPainter(
          walkAnimation: _isChatOpen ? 0 : _legAnimation.value,
          armAnimation: _isChatOpen ? 0 : _armAnimation.value,
          glowIntensity: _glowAnimation.value,
          isHovered: _isHovered,
        ),
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) => Transform.scale(scale: value, alignment: Alignment.bottomCenter, child: Opacity(opacity: value, child: child)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withAlpha(150), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withAlpha(60), blurRadius: 15, spreadRadius: 1)],
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
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0)..close();
    canvas.drawPath(path, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF16213e), Color(0xFF0f0f23)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0), Paint()..color = const Color(0xFF10B981).withAlpha(150)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FuturisticRobotPainter extends CustomPainter {
  final double walkAnimation, armAnimation, glowIntensity;
  final bool isHovered;

  _FuturisticRobotPainter({required this.walkAnimation, required this.armAnimation, required this.glowIntensity, required this.isHovered});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final metalDark = const Color(0xFF2d3436), metalMid = const Color(0xFF636e72), metalLight = const Color(0xFFb2bec3);
    final glowColor = isHovered ? const Color(0xFF00FF88) : const Color(0xFF10B981);
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

    _drawArm(canvas, centerX - 25, size.height - 90, armAnimation, metalDark, metalMid, glowColor);
    _drawArm(canvas, centerX + 25, size.height - 90, -armAnimation, metalDark, metalMid, glowColor);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, size.height - 105), width: 12, height: 8), const Radius.circular(2)), Paint()..color = metalDark);
    _drawHead(canvas, centerX, size.height - 130, metalDark, metalMid, metalLight, glowColor, glowIntensity, isHovered);
  }

  void _drawLeg(Canvas canvas, double x, double y, double angle, Color dark, Color mid, Color glow) {
    canvas.save(); canvas.translate(x, y); canvas.rotate(angle);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-5, 0, 10, 25), const Radius.circular(3)), Paint()..shader = LinearGradient(colors: [mid, dark], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(Rect.fromLTWH(-5, 0, 10, 25)));
    canvas.drawCircle(Offset(0, 25), 5, Paint()..color = dark); canvas.drawCircle(Offset(0, 25), 3, Paint()..color = glow.withAlpha(100));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4, 25, 8, 22), const Radius.circular(2)), Paint()..color = dark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-7, 45, 14, 6), const Radius.circular(2)), Paint()..color = mid);
    canvas.drawCircle(Offset(0, 48), 2, Paint()..color = glow);
    canvas.restore();
  }

  void _drawArm(Canvas canvas, double x, double y, double angle, Color dark, Color mid, Color glow) {
    canvas.save(); canvas.translate(x, y); canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, 6, Paint()..color = mid);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4, 0, 8, 20), const Radius.circular(3)), Paint()..color = dark);
    canvas.drawCircle(Offset(0, 20), 4, Paint()..color = mid); canvas.drawCircle(Offset(0, 20), 2, Paint()..color = glow.withAlpha(80));
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
      canvas.drawPath(Path()..moveTo(x - 12, y)..quadraticBezierTo(x - 8, y - 6, x - 4, y), Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      canvas.drawPath(Path()..moveTo(x + 4, y)..quadraticBezierTo(x + 8, y - 6, x + 12, y), Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
    } else {
      canvas.drawLine(Offset(x - 12, y - 2), Offset(x + 12, y - 2), Paint()..color = glow..strokeWidth = 3..strokeCap = StrokeCap.round..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * glowIntensity));
      canvas.drawCircle(Offset(x - 7, y - 2), 2, Paint()..color = Colors.white); canvas.drawCircle(Offset(x + 7, y - 2), 2, Paint()..color = Colors.white);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 28), width: 4, height: 12), const Radius.circular(2)), Paint()..color = mid);
    canvas.drawCircle(Offset(x, y - 35), 5, Paint()..color = glow.withAlpha((200 * glowIntensity).toInt())..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(x, y - 35), 3, Paint()..color = glow); canvas.drawCircle(Offset(x, y - 35), 1.5, Paint()..color = Colors.white);
    for (int i = 0; i < 3; i++) { canvas.drawCircle(Offset(x - 24, y - 10 + (i * 5)), 1.5, Paint()..color = glow.withAlpha((150 * glowIntensity).toInt())); canvas.drawCircle(Offset(x + 24, y - 10 + (i * 5)), 1.5, Paint()..color = glow.withAlpha((150 * glowIntensity).toInt())); }
  }

  @override
  bool shouldRepaint(_FuturisticRobotPainter oldDelegate) => oldDelegate.walkAnimation != walkAnimation || oldDelegate.armAnimation != armAnimation || oldDelegate.glowIntensity != glowIntensity || oldDelegate.isHovered != isHovered;
}

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

  @override
  void initState() { super.initState(); _initChat(); }

  @override
  void dispose() { _messageController.dispose(); _scrollController.dispose(); super.dispose(); }

  Future<void> _initChat() async {
    final existingSessionId = await AiChatService.getActiveSessionId();
    if (existingSessionId != null) {
      _sessionId = existingSessionId;
      final history = await AiChatService.getChatHistory(existingSessionId);
      setState(() => _messages.addAll(history.map((msg) => _ChatMessage(role: msg['role'], content: msg['content'], timestamp: DateTime.tryParse(msg['created_at'] ?? '')))));
    } else {
      _messages.add(_ChatMessage(role: 'assistant', content: 'Merhaba! Ben arac kiralama asistaniyim. Size nasil yardimci olabilirim?', timestamp: DateTime.now()));
    }
    setState(() => _isInitializing = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;
    _messageController.clear();
    setState(() { _messages.add(_ChatMessage(role: 'user', content: message, timestamp: DateTime.now())); _isLoading = true; });
    _scrollToBottom();
    final response = await AiChatService.sendMessage(message: message, sessionId: _sessionId);
    setState(() {
      _isLoading = false;
      if (response['success'] == true) { _sessionId = response['session_id']; _messages.add(_ChatMessage(role: 'assistant', content: response['message'], timestamp: DateTime.now())); }
      else { _messages.add(_ChatMessage(role: 'assistant', content: 'Uzgunum, bir hata olustu.', timestamp: DateTime.now(), isError: true)); }
    });
    _scrollToBottom();
  }

  Future<void> _startNewChat() async {
    if (_sessionId != null) await AiChatService.closeSession(_sessionId!);
    setState(() { _sessionId = null; _messages.clear(); _messages.add(_ChatMessage(role: 'assistant', content: 'Yeni sohbet baslatildi.', timestamp: DateTime.now())); });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 420, height: 580,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF10B981).withAlpha(100), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFF10B981).withAlpha(30), blurRadius: 30, spreadRadius: 5)],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _isInitializing ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))) : ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: _messages.length + (_isLoading ? 1 : 0), itemBuilder: (context, index) { if (index == _messages.length && _isLoading) return _buildTypingIndicator(); return _buildMessageBubble(_messages[index]); })),
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFF10B981).withAlpha(50)))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF10B981).withAlpha(100), blurRadius: 10)]), child: const Icon(Icons.smart_toy, color: Colors.white, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('AI Asistan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)), Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF00FF88), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00FF88), blurRadius: 6)])), const SizedBox(width: 6), Text('Cevrimici', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150)))])])),
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
        margin: const EdgeInsets.symmetric(vertical: 6), constraints: const BoxConstraints(maxWidth: 320),
        child: Row(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[Container(width: 30, height: 30, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.smart_toy, color: Colors.white, size: 18)), const SizedBox(width: 10)],
            Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(gradient: isUser ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]) : null, color: isUser ? null : const Color(0xFF252540), borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18)), border: isUser ? null : Border.all(color: const Color(0xFF10B981).withAlpha(30))), child: Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 14)))),
            if (isUser) const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 30, height: 30, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.smart_toy, color: Colors.white, size: 18)), const SizedBox(width: 10), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF252540), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF10B981).withAlpha(30))), child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => _TypingDot(delay: i * 150))))]));
  }

  Widget _buildQuickActions() {
    final questions = ['Arac nasil eklenir?', 'Rezervasyon nasil onaylanir?', 'Raporlar nerede?'];
    return SizedBox(height: 42, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: questions.length, itemBuilder: (context, index) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(questions[index], style: const TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: const Color(0xFF252540), side: BorderSide(color: const Color(0xFF10B981).withAlpha(50)), onPressed: () { _messageController.text = questions[index]; _sendMessage(); }))));
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: const Color(0xFF10B981).withAlpha(50)))),
      child: Row(
        children: [
          Expanded(child: Theme(data: ThemeData.dark().copyWith(textSelectionTheme: const TextSelectionThemeData(cursorColor: Color(0xFF10B981), selectionColor: Color(0xFF10B981), selectionHandleColor: Color(0xFF10B981))), child: Container(decoration: BoxDecoration(color: const Color(0xFF252540), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF10B981).withAlpha(30))), child: TextField(controller: _messageController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), cursorColor: const Color(0xFF10B981), decoration: InputDecoration(hintText: 'Mesajinizi yazin...', hintStyle: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)), onSubmitted: (_) => _sendMessage())))),
          const SizedBox(width: 10),
          Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF10B981).withAlpha(80), blurRadius: 10)]), child: IconButton(icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _isLoading ? null : _sendMessage)),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget { final int delay; const _TypingDot({required this.delay}); @override State<_TypingDot> createState() => _TypingDotState(); }
class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override void initState() { super.initState(); _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this); Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _controller.repeat(reverse: true); }); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _controller, builder: (context, _) => Container(width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: Color.lerp(const Color(0xFF10B981).withAlpha(100), const Color(0xFF10B981), _controller.value), shape: BoxShape.circle)));
}

class _ChatMessage { final String role, content; final DateTime? timestamp; final bool isError; _ChatMessage({required this.role, required this.content, this.timestamp, this.isError = false}); }
