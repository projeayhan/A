import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/rental_management_providers.dart';

class AdminRentalPackagesScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminRentalPackagesScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminRentalPackagesScreen> createState() => _AdminRentalPackagesScreenState();
}

class _AdminRentalPackagesScreenState extends ConsumerState<AdminRentalPackagesScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

  // ==================== PACKAGE OPERATIONS ====================

  Future<void> _togglePackageActive(String packageId, bool isActive) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('rental_packages').update({'is_active': isActive}).eq('id', packageId);
      ref.invalidate(rentalCompanyPackagesProvider(widget.companyId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showPackageDialog({Map<String, dynamic>? package}) {
    final isEdit = package != null;
    final nameController = TextEditingController(text: package?['name'] as String? ?? '');
    final descriptionController = TextEditingController(text: package?['description'] as String? ?? '');
    final priceController = TextEditingController(text: (package?['daily_price'] as num?)?.toString() ?? '');
    final servicesController = TextEditingController(
      text: (package?['included_services'] as List<dynamic>?)?.join(', ') ?? '',
    );
    String selectedTier = package?['tier'] as String? ?? 'basic';
    bool isPopular = package?['is_popular'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isEdit ? 'Paketi Düzenle' : 'Yeni Paket Ekle',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogField('Paket Adı', nameController),
                  const SizedBox(height: 12),
                  _buildDialogField('Açıklama', descriptionController, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildDialogField('Günlük Fiyat (₺)', priceController),
                  const SizedBox(height: 12),
                  _buildDialogField('Dahil Hizmetler (virgülle ayırın)', servicesController, maxLines: 2),
                  const SizedBox(height: 12),
                  // Tier Selection
                  Row(
                    children: [
                      const Text('Seviye: ', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: selectedTier,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(value: 'basic', child: Text('Basic')),
                          DropdownMenuItem(value: 'comfort', child: Text('Comfort')),
                          DropdownMenuItem(value: 'premium', child: Text('Premium')),
                        ],
                        onChanged: (val) => setDialogState(() => selectedTier = val!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isPopular,
                    onChanged: (val) => setDialogState(() => isPopular = val ?? false),
                    title: const Text('Popüler', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final services = servicesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                final data = {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'daily_price': double.tryParse(priceController.text.trim()) ?? 0,
                  'tier': selectedTier,
                  'included_services': services,
                  'is_popular': isPopular,
                  'company_id': widget.companyId,
                };

                try {
                  final supabase = ref.read(supabaseProvider);
                  if (isEdit) {
                    await supabase.from('rental_packages').update(data).eq('id', package['id']);
                  } else {
                    await supabase.from('rental_packages').insert(data);
                  }
                  ref.invalidate(rentalCompanyPackagesProvider(widget.companyId));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Paket güncellendi' : 'Paket eklendi'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SERVICE OPERATIONS ====================

  Future<void> _toggleServiceActive(String serviceId, bool isActive) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('rental_services').update({'is_active': isActive}).eq('id', serviceId);
      ref.invalidate(rentalCompanyServicesProvider(widget.companyId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showServiceDialog({Map<String, dynamic>? service}) {
    final isEdit = service != null;
    final nameController = TextEditingController(text: service?['name'] as String? ?? '');
    final descriptionController = TextEditingController(text: service?['description'] as String? ?? '');
    final priceController = TextEditingController(text: (service?['price'] as num?)?.toString() ?? '');
    String selectedPriceType = service?['price_type'] as String? ?? 'per_day';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isEdit ? 'Hizmeti Düzenle' : 'Yeni Hizmet Ekle',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogField('Hizmet Adı', nameController),
                  const SizedBox(height: 12),
                  _buildDialogField('Açıklama', descriptionController, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildDialogField('Fiyat (₺)', priceController),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Fiyat Tipi: ', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: selectedPriceType,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(value: 'per_day', child: Text('Günlük')),
                          DropdownMenuItem(value: 'per_rental', child: Text('Kiralama Başı')),
                          DropdownMenuItem(value: 'per_km', child: Text('Km Başı')),
                        ],
                        onChanged: (val) => setDialogState(() => selectedPriceType = val!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': double.tryParse(priceController.text.trim()) ?? 0,
                  'price_type': selectedPriceType,
                  'company_id': widget.companyId,
                };

                try {
                  final supabase = ref.read(supabaseProvider);
                  if (isEdit) {
                    await supabase.from('rental_services').update(data).eq('id', service['id']);
                  } else {
                    await supabase.from('rental_services').insert(data);
                  }
                  ref.invalidate(rentalCompanyServicesProvider(widget.companyId));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Hizmet güncellendi' : 'Hizmet eklendi'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(rentalCompanyPackagesProvider(widget.companyId));
    final servicesAsync = ref.watch(rentalCompanyServicesProvider(widget.companyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paketler ve Hizmetler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kiralama paketlerini ve ek hizmetleri yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(rentalCompanyPackagesProvider(widget.companyId));
                        ref.invalidate(rentalCompanyServicesProvider(widget.companyId));
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ==================== PACKAGES SECTION ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Paketler',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showPackageDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Paket Ekle'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 16),

            packagesAsync.when(
              data: (packages) {
                if (packages.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: const Center(
                      child: Text('Henüz paket eklenmemiş', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: packages.map((pkg) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _buildPackageCard(pkg),
                    ),
                  )).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),

            const SizedBox(height: 40),

            // ==================== SERVICES SECTION ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ek Hizmetler',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showServiceDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Hizmet Ekle'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 16),

            servicesAsync.when(
              data: (services) {
                if (services.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: const Center(
                      child: Text('Henüz hizmet eklenmemiş', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return _buildServicesTable(services);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final name = pkg['name'] as String? ?? '';
    final tier = pkg['tier'] as String? ?? 'basic';
    final dailyPrice = (pkg['daily_price'] as num?)?.toDouble() ?? 0;
    final description = pkg['description'] as String? ?? '';
    final includedServices = List<String>.from(pkg['included_services'] as List<dynamic>? ?? []);
    final isPopular = pkg['is_popular'] as bool? ?? false;
    final isActive = pkg['is_active'] as bool? ?? true;

    Color tierColor;
    String tierLabel;
    switch (tier) {
      case 'basic':
        tierColor = AppColors.textMuted;
        tierLabel = 'Basic';
        break;
      case 'comfort':
        tierColor = AppColors.info;
        tierLabel = 'Comfort';
        break;
      case 'premium':
        tierColor = AppColors.warning;
        tierLabel = 'Premium';
        break;
      default:
        tierColor = AppColors.textMuted;
        tierLabel = tier;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier badge + popular
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tierLabel, style: TextStyle(color: tierColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Row(
                children: [
                  if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text('Popüler', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  IconButton(
                    onPressed: () => _showPackageDialog(package: pkg),
                    icon: const Icon(Icons.edit, size: 18, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name
          Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),

          const SizedBox(height: 4),

          // Price
          Text(
            '${_currencyFormat.format(dailyPrice)} / gün',
            style: TextStyle(color: tierColor, fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          // Description
          if (description.isNotEmpty)
            Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),

          const SizedBox(height: 12),

          // Included services
          if (includedServices.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: includedServices.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 12, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(s, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              )).toList(),
            ),

          const SizedBox(height: 12),

          // Active toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Aktif', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Switch(
                value: isActive,
                onChanged: (val) => _togglePackageActive(pkg['id'], val),
                activeThumbColor: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTable(List<Map<String, dynamic>> services) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background.withValues(alpha: 0.5)),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        columns: const [
          DataColumn(label: Text('Hizmet', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Açıklama', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Fiyat', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Fiyat Tipi', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Aktif', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('İşlem', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        ],
        rows: services.map((s) {
          final name = s['name'] as String? ?? '';
          final description = s['description'] as String? ?? '';
          final price = (s['price'] as num?)?.toDouble() ?? 0;
          final priceType = s['price_type'] as String? ?? '';
          final isActive = s['is_active'] as bool? ?? true;

          return DataRow(cells: [
            DataCell(Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
            DataCell(Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
            DataCell(Text(_currencyFormat.format(price), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(_buildPriceTypeBadge(priceType)),
            DataCell(
              Switch(
                value: isActive,
                onChanged: (val) => _toggleServiceActive(s['id'], val),
                activeThumbColor: AppColors.success,
              ),
            ),
            DataCell(
              IconButton(
                onPressed: () => _showServiceDialog(service: s),
                icon: const Icon(Icons.edit, size: 18, color: AppColors.textMuted),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildPriceTypeBadge(String priceType) {
    String label;
    switch (priceType) {
      case 'per_day':
        label = 'Günlük';
        break;
      case 'per_rental':
        label = 'Kiralama Başı';
        break;
      case 'per_km':
        label = 'Km Başı';
        break;
      default:
        label = priceType;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
