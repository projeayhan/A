import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/rental_management_providers.dart';

class AdminRentalLocationsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminRentalLocationsScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminRentalLocationsScreen> createState() => _AdminRentalLocationsScreenState();
}

class _AdminRentalLocationsScreenState extends ConsumerState<AdminRentalLocationsScreen> {
  Future<void> _toggleLocationActive(String locationId, bool isActive) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('rental_locations').update({'is_active': isActive}).eq('id', locationId);
      ref.invalidate(rentalCompanyLocationsProvider(widget.companyId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteLocation(String locationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Lokasyonu Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Bu lokasyonu silmek istediğinize emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('rental_locations').delete().eq('id', locationId);
      ref.invalidate(rentalCompanyLocationsProvider(widget.companyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasyon silindi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showLocationDialog({Map<String, dynamic>? location}) {
    final isEdit = location != null;
    final nameController = TextEditingController(text: location?['name'] as String? ?? '');
    final addressController = TextEditingController(text: location?['address'] as String? ?? '');
    final cityController = TextEditingController(text: location?['city'] as String? ?? '');
    final phoneController = TextEditingController(text: location?['phone'] as String? ?? '');
    bool isAirport = location?['is_airport'] as bool? ?? false;
    bool is24Hours = location?['is_24_hours'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isEdit ? 'Lokasyonu Düzenle' : 'Yeni Lokasyon Ekle',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogField('Lokasyon Adı', nameController),
                  const SizedBox(height: 12),
                  _buildDialogField('Adres', addressController, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildDialogField('Şehir', cityController),
                  const SizedBox(height: 12),
                  _buildDialogField('Telefon', phoneController),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: isAirport,
                          onChanged: (val) => setDialogState(() => isAirport = val ?? false),
                          title: const Text('Havalimanı', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          value: is24Hours,
                          onChanged: (val) => setDialogState(() => is24Hours = val ?? false),
                          title: const Text('7/24 Açık', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text.trim(),
                  'address': addressController.text.trim(),
                  'city': cityController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'is_airport': isAirport,
                  'is_24_hours': is24Hours,
                  'company_id': widget.companyId,
                };

                try {
                  final supabase = ref.read(supabaseProvider);
                  if (isEdit) {
                    await supabase.from('rental_locations').update(data).eq('id', location['id']);
                  } else {
                    await supabase.from('rental_locations').insert(data);
                  }
                  ref.invalidate(rentalCompanyLocationsProvider(widget.companyId));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Lokasyon güncellendi' : 'Lokasyon eklendi'),
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
    final locationsAsync = ref.watch(rentalCompanyLocationsProvider(widget.companyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
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
                      'Lokasyonlar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Teslim alma ve iade noktalarını yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(rentalCompanyLocationsProvider(widget.companyId)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showLocationDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Lokasyon Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Grid
            Expanded(
              child: locationsAsync.when(
                data: (locations) {
                  if (locations.isEmpty) {
                    return const Center(
                      child: Text('Henüz lokasyon eklenmemiş', style: TextStyle(color: AppColors.textMuted)),
                    );
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: locations.length,
                    itemBuilder: (context, index) => _buildLocationCard(locations[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location) {
    final name = location['name'] as String? ?? '';
    final address = location['address'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    final phone = location['phone'] as String? ?? '';
    final isAirport = location['is_airport'] as bool? ?? false;
    final is24Hours = location['is_24_hours'] as bool? ?? false;
    final isActive = location['is_active'] as bool? ?? true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showLocationDialog(location: location),
                    icon: const Icon(Icons.edit, size: 18, color: AppColors.textMuted),
                    tooltip: 'Düzenle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteLocation(location['id']),
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    tooltip: 'Sil',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Address & City
          if (address.isNotEmpty)
            Text(address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (city.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(city, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          if (phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),

          const Spacer(),

          // Bottom: badges + active toggle
          Row(
            children: [
              if (isAirport)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flight, size: 12, color: AppColors.info),
                      const SizedBox(width: 4),
                      const Text('Havalimanı', style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (is24Hours)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('7/24', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              Switch(
                value: isActive,
                onChanged: (val) => _toggleLocationActive(location['id'], val),
                activeThumbColor: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
