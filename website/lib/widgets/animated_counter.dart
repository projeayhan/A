import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AnimatedCounter extends StatefulWidget {
  final int value;
  final String label;
  final String suffix;
  const AnimatedCounter({super.key, required this.value, required this.label, this.suffix = '+'});

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      onVisible: () {
        if (!_started) setState(() => _started = true);
      },
      child: Column(
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: _started ? widget.value : 0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '$value${widget.suffix}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onVisible;
  const VisibilityDetector({super.key, required this.child, required this.onVisible});

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  final _key = GlobalKey();
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_detected) return;
    final obj = _key.currentContext?.findRenderObject();
    if (obj != null && obj.attached) {
      final box = obj as RenderBox;
      final pos = box.localToGlobal(Offset.zero);
      final screen = MediaQuery.of(context).size;
      if (pos.dy < screen.height && pos.dy + box.size.height > 0) {
        _detected = true;
        widget.onVisible();
      } else {
        Future.delayed(const Duration(milliseconds: 200), _check);
      }
    } else {
      Future.delayed(const Duration(milliseconds: 200), _check);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(key: _key, child: widget.child);
  }
}
