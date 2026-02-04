import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum DialogType { error, warning, success, info }

class AppDialogs {
  static Future<void> showError(
    BuildContext context,
    String message, {
    String? title,
  }) {
    return _showDialog(
      context,
      message: message,
      title: title ?? 'Hata',
      type: DialogType.error,
    );
  }

  static Future<void> showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) {
    return _showDialog(
      context,
      message: message,
      title: title ?? 'Uyarı',
      type: DialogType.warning,
    );
  }

  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    return _showDialog(
      context,
      message: message,
      title: title ?? 'Başarılı',
      type: DialogType.success,
    );
  }

  static Future<void> showInfo(
    BuildContext context,
    String message, {
    String? title,
  }) {
    return _showDialog(
      context,
      message: message,
      title: title ?? 'Bilgi',
      type: DialogType.info,
    );
  }

  static Future<void> _showDialog(
    BuildContext context, {
    required String message,
    required String title,
    required DialogType type,
  }) {
    Color getColor() {
      switch (type) {
        case DialogType.error:
          return AppColors.error;
        case DialogType.warning:
          return AppColors.warning;
        case DialogType.success:
          return AppColors.success;
        case DialogType.info:
          return AppColors.info;
      }
    }

    IconData getIcon() {
      switch (type) {
        case DialogType.error:
          return Icons.error_outline_rounded;
        case DialogType.warning:
          return Icons.warning_amber_rounded;
        case DialogType.success:
          return Icons.check_circle_outline_rounded;
        case DialogType.info:
          return Icons.info_outline_rounded;
      }
    }

    final color = getColor();
    final icon = getIcon();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Tamam',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
