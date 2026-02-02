import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

// Surge Zones Provider
final surgeZonesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('surge_zones').select().order('name');
  return List<Map<String, dynamic>>.from(response);
});

class SurgeScreen extends ConsumerStatefulWidget {
  const SurgeScreen({super.key});

  @override
  ConsumerState<SurgeScreen> createState() => _SurgeScreenState();
}

class _SurgeScreenState extends ConsumerState<SurgeScreen> {
  @override
  Widget build(BuildContext context) {
    final surgeZonesAsync = ref.watch(surgeZonesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Surge Pricing Yonetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dinamik fiyatlandirma bolgelerini yonetin',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showSurgeZoneDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Bolge Ekle'),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: surgeZonesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Hata: $err')),
              data: (zones) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Stats Row
                    Row(
                      children: [
                        _buildStatCard(
                          'Toplam Bolge',
                          zones.length.toString(),
                          Icons.map,
                          AppColors.primary,
                        ),
                        const SizedBox(width: 16),
                        _buildStatCard(
                          'Aktif Surge',
                          zones
                              .where((z) => (z['current_multiplier'] ?? 1) > 1)
                              .length
                              .toString(),
                          Icons.trending_up,
                          AppColors.warning,
                        ),
                        const SizedBox(width: 16),
                        _buildStatCard(
                          'Ort. Carpan',
                          'x${_calculateAvgMultiplier(zones).toStringAsFixed(2)}',
                          Icons.speed,
                          AppColors.info,
                        ),
                        const SizedBox(width: 16),
                        _buildStatCard(
                          'Toplam Talep',
                          zones
                              .fold<int>(
                                0,
                                (sum, z) =>
                                    sum + ((z['current_demand'] as int?) ?? 0),
                              )
                              .toString(),
                          Icons.people,
                          AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Zones Table
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            columns: const [
                              DataColumn2(
                                label: Text('Bolge Adi'),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text('Konum'),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text('Yaricap'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Mevcut Carpan'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Min/Maks'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Talep'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Surucueler'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Oto Surge'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Durum'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Islemler'),
                                size: ColumnSize.S,
                              ),
                            ],
                            rows: zones.map((zone) {
                              final multiplier =
                                  double.tryParse(
                                    zone['current_multiplier']?.toString() ??
                                        '1',
                                  ) ??
                                  1;
                              return DataRow2(
                                cells: [
                                  DataCell(Text(zone['name'] ?? '')),
                                  DataCell(
                                    Text(
                                      '${zone['center_latitude']?.toStringAsFixed(4)}, ${zone['center_longitude']?.toStringAsFixed(4)}',
                                    ),
                                  ),
                                  DataCell(Text('${zone['radius_km']} km')),
                                  DataCell(_buildMultiplierBadge(multiplier)),
                                  DataCell(
                                    Text(
                                      'x${zone['min_multiplier']} - x${zone['max_multiplier']}',
                                    ),
                                  ),
                                  DataCell(
                                    Text('${zone['current_demand'] ?? 0}'),
                                  ),
                                  DataCell(
                                    Text('${zone['available_drivers'] ?? 0}'),
                                  ),
                                  DataCell(
                                    Switch(
                                      value: zone['auto_surge_enabled'] == true,
                                      onChanged: (value) =>
                                          _toggleAutoSurge(zone, value),
                                      activeThumbColor: AppColors.primary,
                                    ),
                                  ),
                                  DataCell(
                                    _buildStatusBadge(
                                      zone['is_active'] == true,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _showSurgeZoneDialog(zone: zone),
                                          tooltip: 'Duzenle',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.speed,
                                            size: 18,
                                            color: AppColors.warning,
                                          ),
                                          onPressed: () =>
                                              _showManualSurgeDialog(zone),
                                          tooltip: 'Manuel Surge',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            zone['is_active'] == true
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _toggleZoneStatus(zone),
                                          tooltip: zone['is_active'] == true
                                              ? 'Devre Disi Birak'
                                              : 'Etkinlestir',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplierBadge(double multiplier) {
    Color color;
    if (multiplier >= 2) {
      color = AppColors.error;
    } else if (multiplier >= 1.5) {
      color = AppColors.warning;
    } else if (multiplier > 1) {
      color = AppColors.info;
    } else {
      color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (multiplier > 1) Icon(Icons.trending_up, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'x${multiplier.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  double _calculateAvgMultiplier(List<Map<String, dynamic>> zones) {
    if (zones.isEmpty) return 1;
    final total = zones.fold<double>(
      0,
      (sum, z) =>
          sum +
          (double.tryParse(z['current_multiplier']?.toString() ?? '1') ?? 1),
    );
    return total / zones.length;
  }

  void _showSurgeZoneDialog({Map<String, dynamic>? zone}) {
    final isEditing = zone != null;
    final nameController = TextEditingController(text: zone?['name'] ?? '');
    final latController = TextEditingController(
      text: zone?['center_latitude']?.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: zone?['center_longitude']?.toString() ?? '',
    );
    final radiusController = TextEditingController(
      text: zone?['radius_km']?.toString() ?? '5',
    );
    final minMultiplierController = TextEditingController(
      text: zone?['min_multiplier']?.toString() ?? '1',
    );
    final maxMultiplierController = TextEditingController(
      text: zone?['max_multiplier']?.toString() ?? '3',
    );
    final demandThresholdController = TextEditingController(
      text: zone?['demand_threshold']?.toString() ?? '10',
    );
    bool autoSurge = zone?['auto_surge_enabled'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Bolgeyi Duzenle' : 'Yeni Surge Bolgesi'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Bolge Adi'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Enlem (Latitude)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: lngController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Boylam (Longitude)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Yaricap (km)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minMultiplierController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min. Carpan',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: maxMultiplierController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maks. Carpan',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: demandThresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Talep Esigi',
                      helperText:
                          'Bu sayida talebi gecince otomatik surge baslar',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Otomatik Surge'),
                    subtitle: const Text('Talebe gore otomatik fiyat ayarla'),
                    value: autoSurge,
                    onChanged: (value) =>
                        setDialogState(() => autoSurge = value),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text,
                  'center_latitude': double.tryParse(latController.text),
                  'center_longitude': double.tryParse(lngController.text),
                  'radius_km': double.tryParse(radiusController.text),
                  'min_multiplier': double.tryParse(
                    minMultiplierController.text,
                  ),
                  'max_multiplier': double.tryParse(
                    maxMultiplierController.text,
                  ),
                  'demand_threshold': int.tryParse(
                    demandThresholdController.text,
                  ),
                  'auto_surge_enabled': autoSurge,
                  'current_multiplier': isEditing
                      ? zone['current_multiplier']
                      : 1,
                  'is_active': true,
                };

                final supabase = ref.read(supabaseProvider);
                try {
                  if (isEditing) {
                    await supabase
                        .from('surge_zones')
                        .update(data)
                        .eq('id', zone['id']);
                  } else {
                    await supabase.from('surge_zones').insert(data);
                  }

                  ref.invalidate(surgeZonesProvider);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                }
              },
              child: Text(isEditing ? 'Guncelle' : 'Olustur'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualSurgeDialog(Map<String, dynamic> zone) {
    double multiplier =
        double.tryParse(zone['current_multiplier']?.toString() ?? '1') ?? 1;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manuel Surge: ${zone['name']}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Surge carpanini ayarlayin'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (multiplier > 1) {
                          setDialogState(() => multiplier -= 0.1);
                        }
                      },
                      icon: const Icon(Icons.remove_circle, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'x${multiplier.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {
                        final max =
                            double.tryParse(
                              zone['max_multiplier']?.toString() ?? '3',
                            ) ??
                            3;
                        if (multiplier < max) {
                          setDialogState(() => multiplier += 0.1);
                        }
                      },
                      icon: const Icon(Icons.add_circle, size: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Slider(
                  value: multiplier,
                  min: 1,
                  max:
                      double.tryParse(
                        zone['max_multiplier']?.toString() ?? '3',
                      ) ??
                      3,
                  divisions: 20,
                  label: 'x${multiplier.toStringAsFixed(2)}',
                  onChanged: (value) =>
                      setDialogState(() => multiplier = value),
                  activeColor: AppColors.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  _getSurgePriceExample(multiplier),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Iptal'),
            ),
            OutlinedButton(
              onPressed: () async {
                final supabase = ref.read(supabaseProvider);
                await supabase
                    .from('surge_zones')
                    .update({'current_multiplier': 1})
                    .eq('id', zone['id']);
                ref.invalidate(surgeZonesProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Surge Kapat'),
            ),
            ElevatedButton(
              onPressed: () async {
                final supabase = ref.read(supabaseProvider);
                await supabase
                    .from('surge_zones')
                    .update({'current_multiplier': multiplier})
                    .eq('id', zone['id']);
                ref.invalidate(surgeZonesProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  String _getSurgePriceExample(double multiplier) {
    final basePrice = 50.0;
    final surgedPrice = basePrice * multiplier;
    return 'Ornek: 50 TL yolculuk -> ${surgedPrice.toStringAsFixed(2)} TL olur';
  }

  Future<void> _toggleAutoSurge(Map<String, dynamic> zone, bool value) async {
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('surge_zones')
        .update({'auto_surge_enabled': value})
        .eq('id', zone['id']);
    ref.invalidate(surgeZonesProvider);
  }

  Future<void> _toggleZoneStatus(Map<String, dynamic> zone) async {
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('surge_zones')
        .update({'is_active': !(zone['is_active'] == true)})
        .eq('id', zone['id']);
    ref.invalidate(surgeZonesProvider);
  }
}
