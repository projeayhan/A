import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          height: 1,
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.symmetric(horizontal: 60),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withAlpha(0),
                AppColors.primary.withAlpha(60),
                AppColors.cyan.withAlpha(100),
                AppColors.primary.withAlpha(60),
                AppColors.primary.withAlpha(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
