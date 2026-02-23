import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class ServiceCard extends StatefulWidget {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const ServiceCard({
    super.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
    this.onTap,
  });

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
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
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..setTranslationRaw(0.0, _hovered ? -4.0 : 0.0, 0.0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.4)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _hovered ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _hovered
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.3),
                            blurRadius: 12,
                          )
                        ]
                      : [],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                widget.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textOnLightSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
