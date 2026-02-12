import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const SectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      children: [
        Container(width: 60, height: 3, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan]), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: isMobile ? 28 : 36), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 48),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0);
  }
}
