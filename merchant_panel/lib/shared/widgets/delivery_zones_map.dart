import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_dialogs.dart';

// Delivery Zone Model
class DeliveryZone {
  final String id;
  final String merchantId;
  final String zoneName;
  final double radiusKm;
  final double deliveryFee;
  final double minOrderAmount;
  final bool isActive;
  final String color;
  final int sortOrder;

  DeliveryZone({
    required this.id,
    required this.merchantId,
    required this.zoneName,
    required this.radiusKm,
    required this.deliveryFee,
    required this.minOrderAmount,
    required this.isActive,
    required this.color,
    required this.sortOrder,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'] ?? '',
      merchantId: json['merchant_id'] ?? '',
      zoneName: json['zone_name'] ?? 'Bolge',
      radiusKm: (json['radius_km'] ?? 2).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 15).toDouble(),
      minOrderAmount: (json['min_order_amount'] ?? 50).toDouble(),
      isActive: json['is_active'] ?? true,
      color: json['color'] ?? '#4CAF50',
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'merchant_id': merchantId,
    'zone_name': zoneName,
    'radius_km': radiusKm,
    'delivery_fee': deliveryFee,
    'min_order_amount': minOrderAmount,
    'is_active': isActive,
    'color': color,
    'sort_order': sortOrder,
  };

  DeliveryZone copyWith({
    String? id,
    String? merchantId,
    String? zoneName,
    double? radiusKm,
    double? deliveryFee,
    double? minOrderAmount,
    bool? isActive,
    String? color,
    int? sortOrder,
  }) {
    return DeliveryZone(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      zoneName: zoneName ?? this.zoneName,
      radiusKm: radiusKm ?? this.radiusKm,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

// Color helper
Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

class DeliveryZonesMap extends ConsumerStatefulWidget {
  const DeliveryZonesMap({super.key});

  @override
  ConsumerState<DeliveryZonesMap> createState() => _DeliveryZonesMapState();
}

class _DeliveryZonesMapState extends ConsumerState<DeliveryZonesMap> {
  GoogleMapController? _mapController;
  List<DeliveryZone> _zones = [];
  bool _isLoading = true;
  DeliveryZone? _selectedZone;

  // Default location (Istanbul)
  LatLng _merchantLocation = const LatLng(41.0082, 28.9784);

  // Zone colors
  final List<String> _availableColors = [
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#F44336', // Red
    '#2196F3', // Blue
    '#9C27B0', // Purple
    '#00BCD4', // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final supabase = ref.read(supabaseProvider);

      // Get merchant location
      if (merchant.latitude != null && merchant.longitude != null) {
        _merchantLocation = LatLng(merchant.latitude!, merchant.longitude!);
      }

      // Load zones
      final response = await supabase
          .from('merchant_delivery_zones')
          .select()
          .eq('merchant_id', merchant.id)
          .order('sort_order');

      if (response.isEmpty) {
        // Initialize default zones
        await supabase.rpc(
          'initialize_merchant_delivery_zones',
          params: {'p_merchant_id': merchant.id},
        );

        final newResponse = await supabase
            .from('merchant_delivery_zones')
            .select()
            .eq('merchant_id', merchant.id)
            .order('sort_order');

        if (mounted) {
          setState(() {
            _zones = newResponse.map<DeliveryZone>((e) => DeliveryZone.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _zones = response.map<DeliveryZone>((e) => DeliveryZone.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialogs.showError(context, 'Bolge yuklenemedi: $e');
      }
    }
  }

  Set<Circle> _buildCircles() {
    final circles = <Circle>{};

    // Sort zones by radius descending so smaller circles appear on top
    final sortedZones = List<DeliveryZone>.from(_zones)
      ..sort((a, b) => b.radiusKm.compareTo(a.radiusKm));

    for (final zone in sortedZones) {
      if (!zone.isActive) continue;

      final color = hexToColor(zone.color);
      circles.add(Circle(
        circleId: CircleId(zone.id),
        center: _merchantLocation,
        radius: zone.radiusKm * 1000, // Convert km to meters
        fillColor: color.withAlpha(50),
        strokeColor: color,
        strokeWidth: 2,
        consumeTapEvents: true,
        onTap: () {
          setState(() => _selectedZone = zone);
        },
      ));
    }

    return circles;
  }

  Future<void> _addZone() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    final nextSortOrder = _zones.isEmpty ? 1 : _zones.map((z) => z.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final nextRadius = _zones.isEmpty ? 2.0 : _zones.map((z) => z.radiusKm).reduce((a, b) => a > b ? a : b) + 3;
    final colorIndex = _zones.length % _availableColors.length;

    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase.from('merchant_delivery_zones').insert({
        'merchant_id': merchant.id,
        'zone_name': 'Bolge $nextSortOrder',
        'radius_km': nextRadius,
        'delivery_fee': 15 + (nextSortOrder * 10),
        'min_order_amount': 50 + (nextSortOrder * 25),
        'color': _availableColors[colorIndex],
        'sort_order': nextSortOrder,
      }).select().single();

      setState(() {
        _zones.add(DeliveryZone.fromJson(response));
        _selectedZone = DeliveryZone.fromJson(response);
      });

      _fitMapToZones();
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Bolge eklenemedi: $e');
      }
    }
  }

  Future<void> _updateZone(DeliveryZone zone) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('merchant_delivery_zones').update({
        'zone_name': zone.zoneName,
        'radius_km': zone.radiusKm,
        'delivery_fee': zone.deliveryFee,
        'min_order_amount': zone.minOrderAmount,
        'is_active': zone.isActive,
        'color': zone.color,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', zone.id);

      setState(() {
        final index = _zones.indexWhere((z) => z.id == zone.id);
        if (index != -1) {
          _zones[index] = zone;
        }
        _selectedZone = zone;
      });

      _fitMapToZones();
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Bolge guncellenemedi: $e');
      }
    }
  }

  Future<void> _deleteZone(DeliveryZone zone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bolge Sil'),
        content: Text('${zone.zoneName} bolgesini silmek istediginize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('merchant_delivery_zones').delete().eq('id', zone.id);

      setState(() {
        _zones.removeWhere((z) => z.id == zone.id);
        if (_selectedZone?.id == zone.id) {
          _selectedZone = null;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bolge silindi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Bolge silinemedi: $e');
      }
    }
  }

  void _fitMapToZones() {
    if (_mapController == null || _zones.isEmpty) return;

    final maxRadius = _zones.map((z) => z.radiusKm).reduce((a, b) => a > b ? a : b);

    // Calculate zoom level based on max radius
    // Approximate: zoom 14 = 1km, zoom 13 = 2km, zoom 12 = 4km, etc.
    double zoom = 14 - (maxRadius / 2).clamp(0, 8);
    if (zoom < 8) zoom = 8;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _merchantLocation, zoom: zoom),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teslimat Bolgeleri',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Haritada kademeli teslimat bolgelerini belirleyin',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _addZone,
              icon: const Icon(Icons.add),
              label: const Text('Bolge Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Map and Zone List
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map
            Expanded(
              flex: 2,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _merchantLocation,
                        zoom: 12,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _fitMapToZones();
                      },
                      circles: _buildCircles(),
                      markers: {
                        Marker(
                          markerId: const MarkerId('merchant'),
                          position: _merchantLocation,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          infoWindow: const InfoWindow(title: 'Isletme Konumu'),
                        ),
                      },
                      mapType: MapType.normal,
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: false,
                    ),
                    // Legend
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withAlpha(230),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: _zones.where((z) => z.isActive).map((zone) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: hexToColor(zone.color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${zone.zoneName} (${zone.radiusKm} km)',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Zone List
            Expanded(
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Zone List Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Bolgeler (${_zones.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Zone List
                    Expanded(
                      child: _zones.isEmpty
                          ? Center(
                              child: Text(
                                'Henuz bolge eklenmedi',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _zones.length,
                              itemBuilder: (context, index) {
                                final zone = _zones[index];
                                final isSelected = _selectedZone?.id == zone.id;
                                return _ZoneListItem(
                                  zone: zone,
                                  isSelected: isSelected,
                                  onTap: () => setState(() => _selectedZone = zone),
                                  onEdit: () => _showEditDialog(zone),
                                  onDelete: () => _deleteZone(zone),
                                  onToggle: (value) {
                                    _updateZone(zone.copyWith(isActive: value));
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Selected Zone Details
        if (_selectedZone != null) ...[
          const SizedBox(height: 24),
          _ZoneEditCard(
            zone: _selectedZone!,
            availableColors: _availableColors,
            onUpdate: _updateZone,
            onDelete: () => _deleteZone(_selectedZone!),
          ),
        ],
      ],
    );
  }

  void _showEditDialog(DeliveryZone zone) {
    setState(() => _selectedZone = zone);
  }
}

class _ZoneListItem extends StatelessWidget {
  final DeliveryZone zone;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _ZoneListItem({
    required this.zone,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withAlpha(20) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: hexToColor(zone.color).withAlpha(50),
            shape: BoxShape.circle,
            border: Border.all(color: hexToColor(zone.color), width: 2),
          ),
          child: Center(
            child: Text(
              '${zone.radiusKm.toInt()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: hexToColor(zone.color),
              ),
            ),
          ),
        ),
        title: Text(
          zone.zoneName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: zone.isActive ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        subtitle: Text(
          '${zone.deliveryFee.toInt()} TL • Min ${zone.minOrderAmount.toInt()} TL',
          style: TextStyle(
            fontSize: 12,
            color: zone.isActive ? AppColors.textSecondary : AppColors.textMuted,
          ),
        ),
        trailing: Switch(
          value: zone.isActive,
          onChanged: onToggle,
          activeTrackColor: AppColors.success,
        ),
      ),
    );
  }
}

class _ZoneEditCard extends StatefulWidget {
  final DeliveryZone zone;
  final List<String> availableColors;
  final Function(DeliveryZone) onUpdate;
  final VoidCallback onDelete;

  const _ZoneEditCard({
    required this.zone,
    required this.availableColors,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_ZoneEditCard> createState() => _ZoneEditCardState();
}

class _ZoneEditCardState extends State<_ZoneEditCard> {
  late TextEditingController _nameController;
  late TextEditingController _radiusController;
  late TextEditingController _feeController;
  late TextEditingController _minOrderController;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(_ZoneEditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone.id != widget.zone.id) {
      _initControllers();
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.zone.zoneName);
    _radiusController = TextEditingController(text: widget.zone.radiusKm.toString());
    _feeController = TextEditingController(text: widget.zone.deliveryFee.toInt().toString());
    _minOrderController = TextEditingController(text: widget.zone.minOrderAmount.toInt().toString());
    _selectedColor = widget.zone.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    _feeController.dispose();
    _minOrderController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    widget.onUpdate(widget.zone.copyWith(
      zoneName: _nameController.text.trim(),
      radiusKm: double.tryParse(_radiusController.text) ?? widget.zone.radiusKm,
      deliveryFee: double.tryParse(_feeController.text) ?? widget.zone.deliveryFee,
      minOrderAmount: double.tryParse(_minOrderController.text) ?? widget.zone.minOrderAmount,
      color: _selectedColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: hexToColor(_selectedColor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bolge Duzenle',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.error,
                tooltip: 'Bolgeyi Sil',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Form Fields
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Bolge Adi',
                    hintText: 'Ornek: Yakin Bolge',
                  ),
                  onChanged: (_) => _saveChanges(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Yaricap (km)',
                    suffixText: 'km',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _saveChanges(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _feeController,
                  decoration: const InputDecoration(
                    labelText: 'Teslimat Ucreti',
                    suffixText: 'TL',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _saveChanges(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _minOrderController,
                  decoration: const InputDecoration(
                    labelText: 'Min. Siparis Tutari',
                    suffixText: 'TL',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _saveChanges(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Color Picker
          Text('Bolge Rengi', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.availableColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedColor = color);
                  _saveChanges();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hexToColor(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.textPrimary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: hexToColor(color).withAlpha(100), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
