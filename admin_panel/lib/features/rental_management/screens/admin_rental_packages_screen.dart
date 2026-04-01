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
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 0);

  // Inline editing state
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _descControllers = {};
  final Map<String, TextEditingController> _newServiceControllers = {};
  final Map<String, bool> _activeStates = {};
  final Map<String, List<String>> _includedServices = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final c in _descControllers.values) {
      c.dispose();
    }
    for (final c in _newServiceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(List<Map<String, dynamic>> packages) {
    for (final pkg in packages) {
      final id = pkg['id'] as String;
      if (!_priceControllers.containsKey(id)) {
        _priceControllers[id] = TextEditingController(
          text: (pkg['daily_price'] as num?)?.toStringAsFixed(0) ?? '0',
        );
        _descControllers[id] = TextEditingController(
          text: pkg['description'] as String? ?? '',
        );
        _newServiceControllers[id] = TextEditingController();
        _activeStates[id] = pkg['is_active'] as bool? ?? true;
        final services = pkg['included_services'];
        if (services is List) {
          _includedServices[id] = services.map((e) => e.toString()).toList();
        } else {
          _includedServices[id] = [];
        }
      }
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier) {
      case 'basic':
        return Icons.shield;
      case 'comfort':
        return Icons.star;
      case 'premium':
        return Icons.diamond;
      default:
        return Icons.inventory_2;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'basic':
        return AppColors.info;
      case 'comfort':
        return AppColors.warning;
      case 'premium':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTierLabel(String tier) {
    switch (tier) {
      case 'basic':
        return 'BASIC';
      case 'comfort':
        return 'COMFORT';
      case 'premium':
        return 'PREMIUM';
      default:
        return tier.toUpperCase();
    }
  }

  Future<void> _savePackage(String packageId, Map<String, dynamic> pkg) async {
    // Auto-add any text left in the new service field
    final pendingText = _newServiceControllers[packageId]?.text.trim() ?? '';
    if (pendingText.isNotEmpty) {
      _includedServices[packageId]?.add(pendingText);
      _newServiceControllers[packageId]!.clear();
    }

    setState(() {
      _saving = true;
    });
    try {
      final supabase = ref.read(supabaseProvider);
      final price = double.tryParse(_priceControllers[packageId]!.text) ?? 0;
      if (price <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fiyat 0\'dan büyük olmalıdır')),
          );
        }
        return;
      }
      final desc = _descControllers[packageId]!.text;
      final isActive = _activeStates[packageId] ?? true;
      final services = _includedServices[packageId] ?? [];

      await supabase
          .from('rental_packages')
          .update({
            'daily_price': price,
            'description': desc,
            'is_active': isActive,
            'included_services': services,
          })
          .eq('id', packageId);

      ref.invalidate(rentalCompanyPackagesProvider(widget.companyId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pkg['name']} paketi güncellendi'),
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
    } finally {
      setState(() => _saving = false);
    }
  }

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
                  _buildDialogField('Paket Adi', nameController),
                  const SizedBox(height: 12),
                  _buildDialogField('Açıklama', descriptionController, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildDialogField('Günlük Fiyat (TL)', priceController),
                  const SizedBox(height: 12),
                  _buildDialogField('Dahil Hizmetler (virgul ile ayirin)', servicesController, maxLines: 2),
                  const SizedBox(height: 12),
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
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedTier = val);
                          }
                        },
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
                final services = servicesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                final data = {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'daily_price': double.tryParse(priceController.text.trim()) ?? 0,
                  'tier': selectedTier,
                  'included_services': services,
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
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
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
                  _buildDialogField('Hizmet Adi', nameController),
                  const SizedBox(height: 12),
                  _buildDialogField('Açıklama', descriptionController, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildDialogField('Fiyat (TL)', priceController),
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
                          DropdownMenuItem(value: 'per_rental', child: Text('Kiralama Basi')),
                          DropdownMenuItem(value: 'per_km', child: Text('Km Basi')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedPriceType = val);
                          }
                        },
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
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
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
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 32, color: AppColors.primary),
                        SizedBox(width: 12),
                        Text(
                          'Paketler ve Hizmetler',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kiralama paketlerini ve ek hizmetleri yonetin',
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
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showPackageDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Paket Ekle'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ==================== PACKAGES ====================
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
                _initControllers(packages);
                return Column(
                  children: packages.map((pkg) => _buildPackageCard(pkg)).toList(),
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
    final id = pkg['id'] as String;
    final tier = pkg['tier'] as String? ?? 'basic';
    final name = pkg['name'] as String? ?? '';
    final isActive = _activeStates[id] ?? true;
    final services = _includedServices[id] ?? [];
    final color = _getTierColor(tier);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.3)
              : AppColors.surfaceLight,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getTierIcon(tier), color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          _getTierLabel(tier),
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  // Edit button
                  IconButton(
                    onPressed: () => _showPackageDialog(package: pkg),
                    icon: const Icon(Icons.edit, size: 18, color: AppColors.textMuted),
                    tooltip: 'Düzenle',
                  ),
                  const SizedBox(width: 8),
                  // Active toggle
                  Column(
                    children: [
                      Switch(
                        value: isActive,
                        onChanged: (val) {
                          setState(() => _activeStates[id] = val);
                          _togglePackageActive(id, val);
                        },
                        activeThumbColor: AppColors.success,
                      ),
                      Text(
                        isActive ? 'Aktif' : 'Pasif',
                        style: TextStyle(
                          color: isActive ? AppColors.success : AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Price + Description row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily price
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _priceControllers[id],
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Günlük Fiyat (TL)',
                        prefixText: '\u20BA ',
                        suffixText: '/gun',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Description
                  Expanded(
                    child: TextField(
                      controller: _descControllers[id],
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Açıklama',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Included services
              const Text(
                'Dahil Hizmetler',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...services.map(
                    (service) => Chip(
                      label: Text(service, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _includedServices[id]?.remove(service);
                        });
                      },
                      backgroundColor: color.withValues(alpha: 0.1),
                      side: BorderSide(color: color.withValues(alpha: 0.3)),
                    ),
                  ),
                  // Add new service inline
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 36,
                        child: TextField(
                          controller: _newServiceControllers[id],
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Yeni hizmet ekle...',
                            hintStyle: const TextStyle(fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) {
                              setState(() {
                                _includedServices[id]?.add(text.trim());
                                _newServiceControllers[id]!.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          final text = _newServiceControllers[id]!.text.trim();
                          if (text.isNotEmpty) {
                            setState(() {
                              _includedServices[id]?.add(text);
                              _newServiceControllers[id]!.clear();
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.add_circle, size: 28, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Save button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : () => _savePackage(id, pkg),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text('Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        label = 'Kiralama Basi';
        break;
      case 'per_km':
        label = 'Km Basi';
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
