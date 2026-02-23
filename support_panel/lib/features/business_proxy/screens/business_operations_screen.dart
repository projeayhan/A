import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/router/app_router.dart';
import '../widgets/merchant_ops_panel.dart';
import '../widgets/rental_ops_panel.dart';
import '../widgets/emlak_ops_panel.dart';
import '../widgets/car_sales_ops_panel.dart';
import '../widgets/taxi_courier_ops_panel.dart';

class BusinessOperationsScreen extends ConsumerWidget {
  const BusinessOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedBusinessProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    if (selected == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store, size: 48, color: textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Önce bir işletme seçin', style: TextStyle(color: textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.businesses),
              child: const Text('İşletme Ara'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Business info header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => context.go(AppRoutes.businesses),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                child: Icon(
                  selected.type == 'merchant' ? Icons.restaurant :
                  selected.type == 'rental' ? Icons.car_rental :
                  selected.type == 'realtor' ? Icons.home_work :
                  Icons.directions_car,
                  color: AppColors.warning, size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selected.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(_getTypeLabel(selected.type), style: TextStyle(color: textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Proxy Modu',
                  style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Business operations panel
        Expanded(
          child: _buildOpsPanel(selected),
        ),
      ],
    );
  }

  Widget _buildOpsPanel(SelectedBusiness biz) {
    switch (biz.type) {
      case 'merchant': return MerchantOpsPanel(businessId: biz.id, data: biz.data ?? {});
      case 'rental': return RentalOpsPanel(businessId: biz.id, data: biz.data ?? {});
      case 'realtor': return EmlakOpsPanel(businessId: biz.id, data: biz.data ?? {});
      case 'dealer': return CarSalesOpsPanel(businessId: biz.id, data: biz.data ?? {});
      case 'taxi_driver': return TaxiCourierOpsPanel(businessId: biz.id, businessType: 'taxi_driver', data: biz.data ?? {});
      case 'courier': return TaxiCourierOpsPanel(businessId: biz.id, businessType: 'courier', data: biz.data ?? {});
      default: return const Center(child: Text('Desteklenmeyen işletme tipi'));
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'merchant': return 'İşletme (Yemek/Market/Mağaza)';
      case 'rental': return 'Rent-a-Car';
      case 'realtor': return 'Emlakçı';
      case 'dealer': return 'Araç Satış Bayii';
      case 'taxi_driver': return 'Taksi Sürücüsü';
      case 'courier': return 'Kurye';
      default: return type;
    }
  }
}
