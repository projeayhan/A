import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Cars provider
final carsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_cars')
      .select('*, rental_locations(name, city)')
      .eq('company_id', companyId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

// Locations provider for dropdown
final locationsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_locations')
      .select('id, name, city')
      .eq('company_id', companyId)
      .eq('is_active', true)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});

class CarsScreen extends ConsumerStatefulWidget {
  const CarsScreen({super.key});

  @override
  ConsumerState<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends ConsumerState<CarsScreen> {
  String _searchQuery = '';
  String? _statusFilter;
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(carsProvider);

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
                  'Araçlar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddCarDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Araç Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Araç ara (marka, model, plaka)',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Status filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Durum',
                          border: InputBorder.none,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tümü')),
                          DropdownMenuItem(value: 'available', child: Text('Müsait')),
                          DropdownMenuItem(value: 'rented', child: Text('Kirada')),
                          DropdownMenuItem(value: 'maintenance', child: Text('Bakımda')),
                          DropdownMenuItem(value: 'inactive', child: Text('Pasif')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Category filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _categoryFilter,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: InputBorder.none,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tümü')),
                          DropdownMenuItem(value: 'economy', child: Text('Ekonomi')),
                          DropdownMenuItem(value: 'compact', child: Text('Kompakt')),
                          DropdownMenuItem(value: 'midsize', child: Text('Orta')),
                          DropdownMenuItem(value: 'fullsize', child: Text('Büyük')),
                          DropdownMenuItem(value: 'suv', child: Text('SUV')),
                          DropdownMenuItem(value: 'luxury', child: Text('Lüks')),
                          DropdownMenuItem(value: 'van', child: Text('Van')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _categoryFilter = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cars list
            Expanded(
              child: carsAsync.when(
                data: (cars) {
                  // Apply filters
                  var filteredCars = cars.where((car) {
                    if (_searchQuery.isNotEmpty) {
                      final brand = (car['brand'] ?? '').toString().toLowerCase();
                      final model = (car['model'] ?? '').toString().toLowerCase();
                      final plate = (car['plate'] ?? '').toString().toLowerCase();
                      if (!brand.contains(_searchQuery) &&
                          !model.contains(_searchQuery) &&
                          !plate.contains(_searchQuery)) {
                        return false;
                      }
                    }
                    if (_statusFilter != null && car['status'] != _statusFilter) {
                      return false;
                    }
                    if (_categoryFilter != null && car['category'] != _categoryFilter) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filteredCars.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Araç bulunamadı',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Card(
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 50), // Image
                              SizedBox(width: 12),
                              Expanded(flex: 2, child: Text('Araç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Expanded(flex: 1, child: Text('Plaka', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Expanded(flex: 1, child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Expanded(flex: 1, child: Text('Günlük Fiyat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Expanded(flex: 1, child: Text('Lokasyon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              SizedBox(width: 100, child: Text('Durum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              SizedBox(width: 50), // Actions
                            ],
                          ),
                        ),
                        // Table body
                        Expanded(
                          child: ListView.separated(
                            itemCount: filteredCars.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              return _CarRow(
                                car: filteredCars[index],
                                onTap: () => context.go('/cars/${filteredCars[index]['id']}'),
                                onStatusChange: (newStatus) => _updateCarStatus(
                                  filteredCars[index]['id'],
                                  newStatus,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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

  Future<void> _updateCarStatus(String carId, String status) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('rental_cars')
          .update({'status': status})
          .eq('id', carId);

      ref.invalidate(carsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Araç durumu güncellendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _showAddCarDialog(BuildContext context) async {
    final locations = await ref.read(locationsProvider.future);

    if (locations.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Önce bir lokasyon eklemelisiniz'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _AddCarDialog(
        locations: locations,
        onSave: (carData) async {
          try {
            final client = ref.read(supabaseClientProvider);
            final companyId = await ref.read(companyIdProvider.future);

            await client.from('rental_cars').insert({
              ...carData,
              'company_id': companyId,
            });

            ref.invalidate(carsProvider);

            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Araç eklendi')),
              );
            }
          } catch (e) {
            if (mounted) {
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

class _CarRow extends StatelessWidget {
  final Map<String, dynamic> car;
  final VoidCallback onTap;
  final Function(String) onStatusChange;

  const _CarRow({
    required this.car,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
    final location = car['rental_locations'] as Map<String, dynamic>?;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Image
            Container(
              width: 50,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: car['image_url'] != null
                  ? Image.network(
                      car['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_car,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    )
                  : const Icon(
                      Icons.directions_car,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
            ),
            const SizedBox(width: 12),
            // Car name
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${car['brand']} ${car['model']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${car['year']} • ${car['transmission'] == 'automatic' ? 'Otomatik' : 'Manuel'}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Plate
            Expanded(
              flex: 1,
              child: Text(
                car['plate'] ?? '-',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Category
            Expanded(
              flex: 1,
              child: Text(
                _getCategoryLabel(car['category']),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            // Price
            Expanded(
              flex: 1,
              child: Text(
                '${formatter.format(car['daily_price'] ?? 0)}/gün',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            // Location
            Expanded(
              flex: 1,
              child: Text(
                location?['city'] ?? '-',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status
            SizedBox(
              width: 100,
              child: _buildStatusBadge(car['status'] ?? ''),
            ),
            // Actions
            SizedBox(
              width: 50,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                padding: EdgeInsets.zero,
                onSelected: (action) {
                  if (action == 'maintenance') {
                    onStatusChange('maintenance');
                  } else if (action == 'available') {
                    onStatusChange('available');
                  } else if (action == 'inactive') {
                    onStatusChange('inactive');
                  }
                },
                itemBuilder: (context) {
                  final status = car['status'] ?? '';
                  return [
                    if (status == 'available') ...[
                      const PopupMenuItem(
                        value: 'maintenance',
                        child: Row(
                          children: [
                            Icon(Icons.build, size: 18, color: AppColors.warning),
                            SizedBox(width: 8),
                            Text('Bakıma Al'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'inactive',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_off, size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Pasife Al'),
                          ],
                        ),
                      ),
                    ],
                    if (status == 'maintenance') ...[
                      const PopupMenuItem(
                        value: 'available',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: AppColors.success),
                            SizedBox(width: 8),
                            Text('Bakımdan Çıkar'),
                          ],
                        ),
                      ),
                    ],
                    if (status == 'inactive') ...[
                      const PopupMenuItem(
                        value: 'available',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 18, color: AppColors.success),
                            SizedBox(width: 8),
                            Text('Aktif Yap'),
                          ],
                        ),
                      ),
                    ],
                    if (status == 'rented') ...[
                      const PopupMenuItem(
                        enabled: false,
                        child: Row(
                          children: [
                            Icon(Icons.info, size: 18, color: AppColors.textMuted),
                            SizedBox(width: 8),
                            Text('Kirada - İşlem yapılamaz'),
                          ],
                        ),
                      ),
                    ],
                  ];
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String? category) {
    switch (category) {
      case 'economy':
        return 'Ekonomi';
      case 'compact':
        return 'Kompakt';
      case 'midsize':
        return 'Orta';
      case 'fullsize':
        return 'Büyük';
      case 'suv':
        return 'SUV';
      case 'luxury':
        return 'Lüks';
      case 'van':
        return 'Van';
      default:
        return category ?? '-';
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'available':
        color = AppColors.success;
        label = 'Müsait';
        break;
      case 'rented':
        color = AppColors.info;
        label = 'Kirada';
        break;
      case 'maintenance':
        color = AppColors.warning;
        label = 'Bakımda';
        break;
      case 'inactive':
        color = AppColors.error;
        label = 'Pasif';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _AddCarDialog extends StatefulWidget {
  final List<Map<String, dynamic>> locations;
  final Function(Map<String, dynamic>) onSave;

  const _AddCarDialog({
    required this.locations,
    required this.onSave,
  });

  @override
  State<_AddCarDialog> createState() => _AddCarDialogState();
}

class _AddCarDialogState extends State<_AddCarDialog> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _dailyPriceController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _selectedLocationId;
  String _category = 'economy';
  String _transmission = 'manual';
  String _fuelType = 'gasoline';
  int _seats = 5;
  int _doors = 4;

  bool _isLoading = false;

  // Image upload state
  String _imageSource = 'url'; // 'url' or 'upload'
  PlatformFile? _selectedFile;
  bool _isUploadingImage = false;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _dailyPriceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Yeni Araç Ekle',
                      style: TextStyle(
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

                // Brand & Model
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(labelText: 'Marka *'),
                        validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(labelText: 'Model *'),
                        validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Year & Plate
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        decoration: const InputDecoration(labelText: 'Yıl *'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _plateController,
                        decoration: const InputDecoration(labelText: 'Plaka *'),
                        validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Location & Price
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedLocationId,
                        decoration: const InputDecoration(labelText: 'Lokasyon *'),
                        items: widget.locations
                            .map((loc) => DropdownMenuItem(
                                  value: loc['id'] as String,
                                  child: Text('${loc['name']} - ${loc['city']}'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedLocationId = v),
                        validator: (v) => v == null ? 'Lokasyon seçin' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _dailyPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Günlük Fiyat (₺) *',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category & Transmission
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'Kategori'),
                        items: const [
                          DropdownMenuItem(value: 'economy', child: Text('Ekonomi')),
                          DropdownMenuItem(value: 'compact', child: Text('Kompakt')),
                          DropdownMenuItem(value: 'midsize', child: Text('Orta')),
                          DropdownMenuItem(value: 'fullsize', child: Text('Büyük')),
                          DropdownMenuItem(value: 'suv', child: Text('SUV')),
                          DropdownMenuItem(value: 'luxury', child: Text('Lüks')),
                          DropdownMenuItem(value: 'van', child: Text('Van')),
                        ],
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _transmission,
                        decoration: const InputDecoration(labelText: 'Vites'),
                        items: const [
                          DropdownMenuItem(value: 'manual', child: Text('Manuel')),
                          DropdownMenuItem(value: 'automatic', child: Text('Otomatik')),
                        ],
                        onChanged: (v) => setState(() => _transmission = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fuel & Seats & Doors
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _fuelType,
                        decoration: const InputDecoration(labelText: 'Yakıt'),
                        items: const [
                          DropdownMenuItem(value: 'gasoline', child: Text('Benzin')),
                          DropdownMenuItem(value: 'diesel', child: Text('Dizel')),
                          DropdownMenuItem(value: 'hybrid', child: Text('Hibrit')),
                          DropdownMenuItem(value: 'electric', child: Text('Elektrik')),
                          DropdownMenuItem(value: 'lpg', child: Text('LPG')),
                        ],
                        onChanged: (v) => setState(() => _fuelType = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _seats,
                        decoration: const InputDecoration(labelText: 'Koltuk'),
                        items: [2, 4, 5, 7, 8, 9]
                            .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                            .toList(),
                        onChanged: (v) => setState(() => _seats = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _doors,
                        decoration: const InputDecoration(labelText: 'Kapı'),
                        items: [2, 3, 4, 5]
                            .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                            .toList(),
                        onChanged: (v) => setState(() => _doors = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Image section
                const Text(
                  'Araç Görseli',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),

                // Image source toggle
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('URL ile ekle'),
                      selected: _imageSource == 'url',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _imageSource = 'url';
                            _selectedFile = null;
                            _uploadedImageUrl = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Dosya yükle'),
                      selected: _imageSource == 'upload',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _imageSource = 'upload';
                            _imageUrlController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // URL input or file upload
                if (_imageSource == 'url')
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Görsel URL',
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.link),
                    ),
                  )
                else
                  _buildImageUploadSection(),
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
                          : const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (_selectedFile != null || _uploadedImageUrl != null) ...[
            // Preview
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: _uploadedImageUrl != null
                  ? Image.network(
                      _uploadedImageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                    )
                  : _selectedFile?.bytes != null
                      ? Image.memory(
                          _selectedFile!.bytes!,
                          fit: BoxFit.contain,
                        )
                      : const Icon(
                          Icons.image,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_uploadedImageUrl != null)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 16),
                      SizedBox(width: 4),
                      Text('Yüklendi', style: TextStyle(color: AppColors.success)),
                    ],
                  )
                else if (_selectedFile != null)
                  Text(
                    _selectedFile!.name,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                      _uploadedImageUrl = null;
                    });
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Kaldır'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ),
          ] else ...[
            // Upload button
            InkWell(
              onTap: _isUploadingImage ? null : _pickImage,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _isUploadingImage
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Yükleniyor...'),
                          ],
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 40,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Resim seçmek için tıklayın',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'JPG, PNG, GIF, WEBP (max 5MB)',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (max 5MB)
        if (file.size > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dosya boyutu 5MB\'dan küçük olmalıdır'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
        });

        // Upload to Supabase Storage
        await _uploadImage(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya seçilirken hata: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage(PlatformFile file) async {
    if (file.bytes == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = 'cars/$fileName';

      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(path, file.bytes!);

      final publicUrl = Supabase.instance.client.storage
          .from('images')
          .getPublicUrl(path);

      setState(() {
        _uploadedImageUrl = publicUrl;
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Determine image URL
    String? imageUrl;
    if (_imageSource == 'url') {
      imageUrl = _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim();
    } else {
      imageUrl = _uploadedImageUrl;
    }

    setState(() => _isLoading = true);

    widget.onSave({
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'year': int.tryParse(_yearController.text) ?? DateTime.now().year,
      'plate': _plateController.text.trim(),
      'location_id': _selectedLocationId,
      'daily_price': double.tryParse(_dailyPriceController.text) ?? 0,
      'category': _category,
      'transmission': _transmission,
      'fuel_type': _fuelType,
      'seats': _seats,
      'doors': _doors,
      'image_url': imageUrl,
      'status': 'available',
      'is_active': true,
    });
  }
}
