import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CollisionWarning extends StatelessWidget {
  final String agentName;

  const CollisionWarning({super.key, required this.agentName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$agentName de bu ticket üzerinde çalışıyor',
              style: const TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
