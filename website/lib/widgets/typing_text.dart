import 'dart:async';
import 'package:flutter/material.dart';

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final VoidCallback? onComplete;
  const TypingText({super.key, required this.text, this.style, this.charDuration = const Duration(milliseconds: 40), this.onComplete});

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  int _charIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.charDuration, (timer) {
      if (_charIndex < widget.text.length) {
        setState(() => _charIndex++);
      } else {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: widget.text.substring(0, _charIndex), style: widget.style ?? Theme.of(context).textTheme.bodyMedium),
          if (_charIndex < widget.text.length)
            TextSpan(text: '|', style: (widget.style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }
}
