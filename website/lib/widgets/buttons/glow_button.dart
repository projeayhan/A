import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final bool outlined;
  final double fontSize;

  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    required this.gradient,
    this.onTap,
    this.outlined = false,
    this.fontSize = 16,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: widget.outlined
                ? null
                : LinearGradient(colors: widget.gradient),
            borderRadius: BorderRadius.circular(12),
            border: widget.outlined
                ? Border.all(
                    color: widget.gradient.first.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
            boxShadow: _hovered && !widget.outlined
                ? [
                    BoxShadow(
                      color: widget.gradient.first.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: widget.outlined
                        ? widget.gradient.first
                        : Colors.white,
                    size: widget.fontSize + 2),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  color: widget.outlined
                      ? widget.gradient.first
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
