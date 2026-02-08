import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Packages provider
final companyPackagesProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_packages')
      .select('*')
      .eq('company_id', companyId)
      .order('sort_order');

  return List<Map<String, dynamic>>.from(response);
});

class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key});

  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
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
        return Icons.directions_car;
      case 'comfort':
        return Icons.star;
      case 'premium':
        return Icons.workspace_premium;
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
      final client = ref.read(supabaseClientProvider);
      final price = double.tryParse(_priceControllers[packageId]!.text) ?? 0;
      final desc = _descControllers[packageId]!.text;
      final isActive = _activeStates[packageId] ?? true;
      final services = _includedServices[packageId] ?? [];

      await client.from('rental_packages').update({
        'daily_price': price,
        'description': desc,
        'is_active': isActive,
        'included_services': services,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', packageId);

      ref.invalidate(companyPackagesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pkg['name']} paketi guncellendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(companyPackagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              children: [
                Icon(Icons.inventory_2, size: 32, color: AppColors.primary),
                SizedBox(width: 12),
                Text(
                  'Paketler',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kiralama paketlerinizin fiyatlarini ve iceriklerini yonetin',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Packages
            Expanded(
              child: packagesAsync.when(
                data: (packages) {
                  if (packages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Paket bulunamadi',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  _initControllers(packages);
                  return ListView.builder(
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      return _buildPackageCard(packages[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Hata: $e',
                      style: const TextStyle(color: AppColors.error)),
                ),
              ),
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
    final isPopular = pkg['is_popular'] as bool? ?? false;
    final isActive = _activeStates[id] ?? true;
    final services = _includedServices[id] ?? [];
    final color = _getTierColor(tier);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.3) : AppColors.surfaceLight,
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
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isPopular) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Onerilen',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          tier.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active toggle
                  Column(
                    children: [
                      Switch(
                        value: isActive,
                        onChanged: (val) {
                          setState(() => _activeStates[id] = val);
                        },
                        activeColor: AppColors.success,
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
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Gunluk Fiyat (TL)',
                        prefixText: '\u20BA ',
                        suffixText: '/gun',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Description
                  Expanded(
                    child: TextField(
                      controller: _descControllers[id],
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Aciklama',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Included services
              const Text(
                'Dahil Hizmetler',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...services.map((service) => Chip(
                        label: Text(service, style: const TextStyle(fontSize: 12)),
                        deleteIcon:
                            const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _includedServices[id]?.remove(service);
                          });
                        },
                        backgroundColor: color.withValues(alpha: 0.1),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                      )),
                  // Add new service
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 36,
                        child: TextField(
                          controller: _newServiceControllers[id],
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Yeni hizmet ekle...',
                            hintStyle: const TextStyle(fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
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
                          final text =
                              _newServiceControllers[id]!.text.trim();
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
                          child: Icon(Icons.add_circle,
                              size: 28, color: AppColors.primary),
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
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
