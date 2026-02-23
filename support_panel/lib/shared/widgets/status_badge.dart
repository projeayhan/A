import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  final Color? color;

  const StatusBadge({super.key, required this.status, required this.label, this.color});

  factory StatusBadge.ticketStatus(String status) {
    Color color;
    String label;
    switch (status) {
      case 'open': color = AppColors.warning; label = 'Açık'; break;
      case 'assigned': color = AppColors.info; label = 'Atanmış'; break;
      case 'pending': color = AppColors.warning; label = 'Beklemede'; break;
      case 'waiting_customer': color = const Color(0xFF8B5CF6); label = 'Müşteri Bekleniyor'; break;
      case 'resolved': color = AppColors.success; label = 'Çözüldü'; break;
      case 'closed': color = AppColors.textMuted; label = 'Kapalı'; break;
      default: color = AppColors.textMuted; label = status;
    }
    return StatusBadge(status: status, label: label, color: color);
  }

  factory StatusBadge.priority(String priority) {
    Color color;
    String label;
    switch (priority) {
      case 'low': color = AppColors.priorityLow; label = 'Düşük'; break;
      case 'normal': color = AppColors.priorityNormal; label = 'Normal'; break;
      case 'high': color = AppColors.priorityHigh; label = 'Yüksek'; break;
      case 'urgent': color = AppColors.priorityUrgent; label = 'Acil'; break;
      default: color = AppColors.textMuted; label = priority;
    }
    return StatusBadge(status: priority, label: label, color: color);
  }

  factory StatusBadge.serviceType(String serviceType) {
    String label;
    switch (serviceType) {
      case 'food': label = 'Yemek'; break;
      case 'market': label = 'Market'; break;
      case 'store': label = 'Mağaza'; break;
      case 'taxi': label = 'Taksi'; break;
      case 'rental': label = 'Kiralama'; break;
      case 'emlak': label = 'Emlak'; break;
      case 'car_sales': label = 'Araç Satış'; break;
      case 'general': label = 'Genel'; break;
      case 'account': label = 'Hesap'; break;
      default: label = serviceType;
    }
    return StatusBadge(status: serviceType, label: label, color: AppColors.primary);
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
