import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class FeatureCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDark;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.color = AppColors.cyan,
    this.isDark = true,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        transform: Matrix4.identity()..setTranslationRaw(0.0, _hovered ? -3.0 : 0.0, 0.0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppColors.surfaceDarkLight.withValues(alpha: 0.5)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? widget.color.withValues(alpha: 0.3)
                : widget.isDark
                    ? AppColors.glassBorder
                    : const Color(0xFFE2E8F0),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.1),
                    blurRadius: 20,
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.isDark
                    ? AppColors.textOnDark
                    : AppColors.textOnLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: widget.isDark
                    ? AppColors.textOnDarkSecondary
                    : AppColors.textOnLightSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
