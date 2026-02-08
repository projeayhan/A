import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Locations provider - fetches locations with car counts and active booking counts
final companyLocationsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  // Fetch locations, car counts, and booking counts in parallel
  final results = await Future.wait([
    client
        .from('rental_locations')
        .select('*')
        .eq('company_id', companyId)
        .order('created_at', ascending: false),
    client
        .from('rental_cars')
        .select('id, location_id')
        .eq('company_id', companyId),
    client
        .from('rental_bookings')
        .select('id, pickup_location_id, dropoff_location_id, status')
        .eq('company_id', companyId)
        .inFilter('status', ['active', 'confirmed']),
  ]);

  final locations = List<Map<String, dynamic>>.from(results[0]);
  final cars = List<Map<String, dynamic>>.from(results[1]);
  final bookings = List<Map<String, dynamic>>.from(results[2]);

  // Build car count map: location_id -> count
  final carCounts = <String, int>{};
  for (final car in cars) {
    final locId = car['location_id'] as String?;
    if (locId != null) {
      carCounts[locId] = (carCounts[locId] ?? 0) + 1;
    }
  }

  // Build active booking count map: location_id -> count
  // A booking counts for a location if it's either pickup or dropoff location
  final bookingCounts = <String, int>{};
  for (final booking in bookings) {
    final pickupId = booking['pickup_location_id'] as String?;
    final dropoffId = booking['dropoff_location_id'] as String?;
    final counted = <String>{};
    if (pickupId != null) counted.add(pickupId);
    if (dropoffId != null) counted.add(dropoffId);
    for (final locId in counted) {
      bookingCounts[locId] = (bookingCounts[locId] ?? 0) + 1;
    }
  }

  // Enrich locations with counts
  for (final location in locations) {
    final id = location['id'] as String;
    location['car_count'] = carCounts[id] ?? 0;
    location['active_booking_count'] = bookingCounts[id] ?? 0;
  }

  return locations;
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

            // Summary strip
            locationsAsync.when(
              data: (locations) => _SummaryStrip(locations: locations),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            locationsAsync.when(
              data: (locations) => locations.isNotEmpty
                  ? const SizedBox(height: 24)
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // Locations grid
            Expanded(
              child: locationsAsync.when(
                data: (locations) {
                  if (locations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
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
                      childAspectRatio: 1.15,
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

// ── Summary Strip ──────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final List<Map<String, dynamic>> locations;

  const _SummaryStrip({required this.locations});

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) return const SizedBox.shrink();

    final totalLocations = locations.length;
    final activeLocations =
        locations.where((l) => l['is_active'] == true).length;
    final totalCars = locations.fold<int>(
        0, (sum, l) => sum + ((l['car_count'] as int?) ?? 0));
    final airportLocations =
        locations.where((l) => l['is_airport'] == true).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.location_on,
            iconColor: AppColors.primary,
            label: 'Toplam Lokasyon',
            value: '$totalLocations',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.check_circle,
            iconColor: AppColors.success,
            label: 'Aktif Lokasyon',
            value: '$activeLocations',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.directions_car,
            iconColor: AppColors.info,
            label: 'Toplam Arac',
            value: '$totalCars',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.flight,
            iconColor: AppColors.warning,
            label: 'Havalimani',
            value: '$airportLocations',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location Card ──────────────────────────────────────────────────────

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
    final phone = (location['phone'] as String?) ?? '';
    final carCount = (location['car_count'] as int?) ?? 0;
    final activeBookingCount = (location['active_booking_count'] as int?) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: icon, name/city, active switch
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
                Switch(
                  value: isActive,
                  onChanged: (_) => onToggleActive(),
                  activeThumbColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 14),

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

            // Phone number
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Car count & booking count badges
            Row(
              children: [
                _buildCountBadge(
                  icon: Icons.directions_car,
                  label: '$carCount Arac',
                  color: AppColors.info,
                ),
                const SizedBox(width: 10),
                _buildCountBadge(
                  icon: Icons.calendar_month,
                  label: '$activeBookingCount Aktif Rez.',
                  color: AppColors.warning,
                ),
              ],
            ),
            const Spacer(),

            // Divider
            const Divider(
              color: AppColors.surfaceLight,
              height: 20,
              thickness: 1,
            ),

            // Tags & Actions
            Row(
              children: [
                if (isAirport) _buildTag('Havalimani', AppColors.info),
                if (is24Hours) _buildTag('7/24', AppColors.success),
                if (!isActive)
                  _buildTag('Pasif', AppColors.textMuted),
                const Spacer(),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 20),
                  color: AppColors.textSecondary,
                  tooltip: 'Duzenle',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 20),
                  color: AppColors.error,
                  tooltip: 'Sil',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
