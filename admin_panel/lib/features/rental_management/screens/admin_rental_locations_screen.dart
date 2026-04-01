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
        content: const Text('Bu lokasyonu silmek istediginize emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

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
    final openingTimeController = TextEditingController(text: location?['opening_time'] as String? ?? '09:00');
    final closingTimeController = TextEditingController(text: location?['closing_time'] as String? ?? '18:00');
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
                  _buildDialogField('Lokasyon Adi', nameController),
                  const SizedBox(height: 12),
                  _buildDialogField('Adres', addressController, maxLines: 2),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDialogField('Şehir', cityController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDialogField('Telefon', phoneController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDialogField('Açılış Saati', openingTimeController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDialogField('Kapanış Saati', closingTimeController)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: isAirport,
                          onChanged: (val) => setDialogState(() => isAirport = val ?? false),
                          title: const Text('Havalimani', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          value: is24Hours,
                          onChanged: (val) => setDialogState(() => is24Hours = val ?? false),
                          title: const Text('7/24 Acik', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
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
                  'opening_time': openingTimeController.text.trim(),
                  'closing_time': closingTimeController.text.trim(),
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
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
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
    final carsAsync = ref.watch(rentalCompanyCarsProvider(widget.companyId));

    // Build car count per location
    final carCountByLocation = <String, int>{};
    if (carsAsync.hasValue) {
      for (final car in carsAsync.value!) {
        final locId = car['location_id'] as String?;
        if (locId != null) {
          carCountByLocation[locId] = (carCountByLocation[locId] ?? 0) + 1;
        }
      }
    }

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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text('Henüz lokasyon eklenmemiş', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: locations.length,
                    itemBuilder: (context, index) => _buildLocationCard(locations[index], carCountByLocation),
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

  Widget _buildLocationCard(Map<String, dynamic> location, Map<String, int> carCounts) {
    final id = location['id'] as String? ?? '';
    final name = location['name'] as String? ?? '';
    final address = location['address'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    final phone = location['phone'] as String? ?? '';
    final is24h = location['is_24_hours'] as bool? ?? false;
    final workingHours = is24h ? '7/24' : '${location['opening_time'] ?? '09:00'} - ${location['closing_time'] ?? '18:00'}';
    final isAirport = location['is_airport'] as bool? ?? false;
    final is24Hours = location['is_24_hours'] as bool? ?? false;
    final isActive = location['is_active'] as bool? ?? true;
    final carCount = carCounts[id] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.surfaceLight : AppColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isAirport
                              ? AppColors.info.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isAirport ? Icons.flight : Icons.location_on,
                          size: 20,
                          color: isAirport ? AppColors.info : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                    ],
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
                      onPressed: () => _deleteLocation(id),
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      tooltip: 'Sil',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Address
            if (address.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pin_drop, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (city.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 20),
                child: Text(city, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),

            const SizedBox(height: 8),

            // Phone
            if (phone.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),

            // Working hours
            if (workingHours.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(workingHours, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),

            const Spacer(),

            // Bottom: badges + car count + active toggle
            Row(
              children: [
                // Car count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '$carCount arac',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isAirport)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flight, size: 12, color: AppColors.info),
                        SizedBox(width: 4),
                        Text('Havalimani', style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (is24Hours)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('7/24', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                const Spacer(),
                Switch(
                  value: isActive,
                  onChanged: (val) => _toggleLocationActive(id, val),
                  activeThumbColor: AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
