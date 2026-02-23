import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/business_proxy_service.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/router/app_router.dart';

class BusinessSearchScreen extends ConsumerStatefulWidget {
  const BusinessSearchScreen({super.key});

  @override
  ConsumerState<BusinessSearchScreen> createState() => _BusinessSearchScreenState();
}

class _BusinessSearchScreenState extends ConsumerState<BusinessSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _searchType = 'merchant';
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  final _typeLabels = const {
    'merchant': 'İşletme (Yemek/Market/Mağaza)',
    'rental': 'Rent-a-Car',
    'realtor': 'Emlakçı',
    'dealer': 'Araç Satış Bayii',
    'taxi_driver': 'Taksi Sürücüsü',
    'courier': 'Kurye',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      final service = ref.read(businessProxyServiceProvider);
      List<Map<String, dynamic>> results;
      switch (_searchType) {
        case 'rental': results = await service.searchRentalCompanies(q); break;
        case 'realtor': results = await service.searchRealtors(q); break;
        case 'dealer': results = await service.searchDealers(q); break;
        case 'taxi_driver': results = await service.searchTaxiDrivers(q); break;
        case 'courier': results = await service.searchCouriers(q); break;
        default: results = await service.searchMerchants(q);
      }
      setState(() { _results = results; _isLoading = false; });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              // Type selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _searchType,
                    icon: Icon(Icons.arrow_drop_down, color: textMuted, size: 18),
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    dropdownColor: cardColor,
                    items: _typeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _searchType = v!),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Search field
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'İşletme adı veya telefon ile ara...',
                    hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search, color: textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text('Ara'),
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_hasSearched
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store_mall_directory, size: 64, color: textMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('İşletme aramak için yukarıdaki alanı kullanın', style: TextStyle(color: textMuted)),
                        ],
                      ),
                    )
                  : _results.isEmpty
                      ? Center(child: Text('Sonuç bulunamadı', style: TextStyle(color: textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final biz = _results[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  ref.read(selectedBusinessProvider.notifier).state = SelectedBusiness(
                                    id: biz['id'],
                                    name: biz['business_name'] ?? biz['company_name'] ?? biz['full_name'] ?? biz['name'] ?? '-',
                                    type: _searchType,
                                    data: biz,
                                  );
                                  context.go('${AppRoutes.businesses}/ops');
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                                        child: Icon(
                                          _searchType == 'merchant' ? Icons.restaurant :
                                          _searchType == 'rental' ? Icons.car_rental :
                                          _searchType == 'realtor' ? Icons.home_work :
                                          _searchType == 'taxi_driver' ? Icons.local_taxi :
                                          _searchType == 'courier' ? Icons.delivery_dining :
                                          Icons.directions_car,
                                          color: AppColors.warning, size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              biz['business_name'] ?? biz['company_name'] ?? biz['full_name'] ?? biz['name'] ?? '-',
                                              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${biz['phone'] ?? '-'} • ${_typeLabels[_searchType]}',
                                              style: TextStyle(color: textMuted, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (biz['is_open'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: (biz['is_open'] == true ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            biz['is_open'] == true ? 'Açık' : 'Kapalı',
                                            style: TextStyle(color: biz['is_open'] == true ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chevron_right, color: textMuted, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
