import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Locations provider
final companyLocationsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_locations')
      .select('*')
      .eq('company_id', companyId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(companyLocationsProvider);

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
                const Text(
                  'Lokasyonlar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddLocationDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Lokasyon'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Locations grid
            Expanded(
              child: locationsAsync.when(
                data: (locations) {
                  if (locations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Henüz lokasyon eklenmemiş',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddLocationDialog(context, ref),
                            icon: const Icon(Icons.add),
                            label: const Text('İlk Lokasyonu Ekle'),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: locations.length,
                    itemBuilder: (context, index) {
                      return _LocationCard(
                        location: locations[index],
                        onToggleActive: () => _toggleActive(ref, locations[index]),
                        onEdit: () => _showEditLocationDialog(context, ref, locations[index]),
                        onDelete: () => _deleteLocation(context, ref, locations[index]['id']),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, Map<String, dynamic> location) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('rental_locations')
          .update({'is_active': !(location['is_active'] ?? false)})
          .eq('id', location['id']);

      ref.invalidate(companyLocationsProvider);
    } catch (e) {
      debugPrint('Error toggling location: $e');
    }
  }

  Future<void> _deleteLocation(BuildContext context, WidgetRef ref, String locationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasyonu Sil'),
        content: const Text('Bu lokasyonu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(supabaseClientProvider);
        await client.from('rental_locations').delete().eq('id', locationId);
        ref.invalidate(companyLocationsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  void _showAddLocationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _LocationDialog(
        onSave: (data) async {
          try {
            final client = ref.read(supabaseClientProvider);
            final companyId = await ref.read(companyIdProvider.future);

            await client.from('rental_locations').insert({
              ...data,
              'company_id': companyId,
            });

            ref.invalidate(companyLocationsProvider);
            if (context.mounted) Navigator.pop(context);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Hata: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditLocationDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => _LocationDialog(
        location: location,
        onSave: (data) async {
          try {
            final client = ref.read(supabaseClientProvider);
            await client
                .from('rental_locations')
                .update(data)
                .eq('id', location['id']);

            ref.invalidate(companyLocationsProvider);
            if (context.mounted) Navigator.pop(context);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Hata: $e')),
              );
            }
          }
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final Map<String, dynamic> location;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LocationCard({
    required this.location,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = location['is_active'] ?? false;
    final isAirport = location['is_airport'] ?? false;
    final is24Hours = location['is_24_hours'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAirport
                        ? AppColors.info.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isAirport ? Icons.flight : Icons.location_on,
                    color: isAirport ? AppColors.info : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        location['city'] ?? '',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status switch
                Switch(
                  value: isActive,
                  onChanged: (_) => onToggleActive(),
                  activeColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Address
            Row(
              children: [
                const Icon(Icons.place, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location['address'] ?? '',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Tags & Actions
            Row(
              children: [
                if (isAirport)
                  _buildTag('Havalimanı', AppColors.info),
                if (is24Hours)
                  _buildTag('7/24', AppColors.success),
                const Spacer(),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 20),
                  color: AppColors.textSecondary,
                  tooltip: 'Düzenle',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 20),
                  color: AppColors.error,
                  tooltip: 'Sil',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LocationDialog extends StatefulWidget {
  final Map<String, dynamic>? location;
  final Function(Map<String, dynamic>) onSave;

  const _LocationDialog({
    this.location,
    required this.onSave,
  });

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _phoneController;

  late bool _isAirport;
  late bool _is24Hours;
  late bool _isActive;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location?['name'] ?? '');
    _addressController = TextEditingController(text: widget.location?['address'] ?? '');
    _cityController = TextEditingController(text: widget.location?['city'] ?? '');
    _phoneController = TextEditingController(text: widget.location?['phone'] ?? '');
    _isAirport = widget.location?['is_airport'] ?? false;
    _is24Hours = widget.location?['is_24_hours'] ?? false;
    _isActive = widget.location?['is_active'] ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.location != null;

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Lokasyon Düzenle' : 'Yeni Lokasyon',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Lokasyon Adı *'),
                validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Adres *'),
                maxLines: 2,
                validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'Şehir *'),
                      validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Telefon'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Options
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Havalimanı'),
                      value: _isAirport,
                      onChanged: (v) => setState(() => _isAirport = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('7/24 Açık'),
                      value: _is24Hours,
                      onChanged: (v) => setState(() => _is24Hours = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Aktif'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? 'Güncelle' : 'Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    widget.onSave({
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'phone': _phoneController.text.trim(),
      'is_airport': _isAirport,
      'is_24_hours': _is24Hours,
      'is_active': _isActive,
    });
  }
}
