import 'package:flutter/material.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../services/car_sales_service.dart';

/// Gelişmiş filtre sheet'i
class AdvancedFilterSheet extends StatefulWidget {
  final bool isDark;
  final Set<String> selectedBodyTypeIds;
  final Set<String> selectedFuelTypeIds;
  final Set<String> selectedTransmissionIds;
  final Set<String> selectedBrandIds;
  final RangeValues priceRange;
  final RangeValues yearRange;
  final RangeValues mileageRange;
  final List<CarBodyTypeData> bodyTypesData;
  final List<CarFuelTypeData> fuelTypesData;
  final List<CarTransmissionData> transmissionsData;
  final void Function(
    Set<String>,
    Set<String>,
    Set<String>,
    Set<String>,
    RangeValues,
    RangeValues,
    RangeValues,
  ) onApply;
  final VoidCallback onClear;

  const AdvancedFilterSheet({
    super.key,
    required this.isDark,
    required this.selectedBodyTypeIds,
    required this.selectedFuelTypeIds,
    required this.selectedTransmissionIds,
    required this.selectedBrandIds,
    required this.priceRange,
    required this.yearRange,
    required this.mileageRange,
    required this.bodyTypesData,
    required this.fuelTypesData,
    required this.transmissionsData,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<AdvancedFilterSheet> {
  late Set<String> _bodyTypeIds;
  late Set<String> _fuelTypeIds;
  late Set<String> _transmissionIds;
  late Set<String> _brandIds;
  late RangeValues _priceRange;
  late RangeValues _yearRange;
  late RangeValues _mileageRange;

  @override
  void initState() {
    super.initState();
    _bodyTypeIds = Set.from(widget.selectedBodyTypeIds);
    _fuelTypeIds = Set.from(widget.selectedFuelTypeIds);
    _transmissionIds = Set.from(widget.selectedTransmissionIds);
    _brandIds = Set.from(widget.selectedBrandIds);
    _priceRange = widget.priceRange;
    _yearRange = widget.yearRange;
    _mileageRange = widget.mileageRange;
  }

  String _formatPrice(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatMileage(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_bodyTypeIds.isNotEmpty) count++;
    if (_fuelTypeIds.isNotEmpty) count++;
    if (_transmissionIds.isNotEmpty) count++;
    if (_brandIds.isNotEmpty) count++;
    if (_priceRange.start > 0 || _priceRange.end < 50000000) count++;
    if (_yearRange.start > 2010 || _yearRange.end < DateTime.now().year) count++;
    if (_mileageRange.start > 0 || _mileageRange.end < 500000) count++;
    return count;
  }

  void _clearAll() {
    setState(() {
      _bodyTypeIds.clear();
      _fuelTypeIds.clear();
      _transmissionIds.clear();
      _brandIds.clear();
      _priceRange = const RangeValues(0, 50000000);
      _yearRange = RangeValues(2010, DateTime.now().year.toDouble());
      _mileageRange = const RangeValues(0, 500000);
    });
  }

  IconData _getIconDataForBodyType(String? iconName) {
    const iconMap = {
      'directions_car': Icons.directions_car,
      'directions_car_filled': Icons.directions_car_filled,
      'sports_motorsports': Icons.sports_motorsports,
      'wb_sunny': Icons.wb_sunny,
      'local_shipping': Icons.local_shipping,
      'airport_shuttle': Icons.airport_shuttle,
      'family_restroom': Icons.family_restroom,
      'speed': Icons.speed,
      'diamond': Icons.diamond,
    };
    return iconMap[iconName] ?? Icons.directions_car;
  }

  IconData _getIconDataForFuelType(String? iconName) {
    const iconMap = {
      'local_gas_station': Icons.local_gas_station,
      'electric_bolt': Icons.electric_bolt,
      'eco': Icons.eco,
      'power': Icons.power,
      'propane_tank': Icons.propane_tank,
    };
    return iconMap[iconName] ?? Icons.local_gas_station;
  }

  IconData _getIconDataForTransmission(String? iconName) {
    const iconMap = {
      'settings': Icons.settings,
      'settings_applications': Icons.settings_applications,
      'tune': Icons.tune,
    };
    return iconMap[iconName] ?? Icons.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: CarSalesColors.card(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: CarSalesColors.border(widget.isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: CarSalesColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Gelişmiş Filtreler',
                      style: TextStyle(
                        color: CarSalesColors.textPrimary(widget.isDark),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_activeFilterCount > 0)
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text(
                      'Temizle',
                      style: TextStyle(
                        color: CarSalesColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Filtreler
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fiyat Aralığı
                  _buildSectionTitle('Fiyat Aralığı'),
                  _buildRangeSlider(
                    value: _priceRange,
                    min: 0,
                    max: 50000000,
                    divisions: 100,
                    onChanged: (value) => setState(() => _priceRange = value),
                    formatLabel: _formatPrice,
                    suffix: ' TL',
                  ),

                  const SizedBox(height: 24),

                  // Yıl Aralığı
                  _buildSectionTitle('Model Yılı'),
                  _buildRangeSlider(
                    value: _yearRange,
                    min: 2000,
                    max: DateTime.now().year.toDouble(),
                    divisions: DateTime.now().year - 2000,
                    onChanged: (value) => setState(() => _yearRange = value),
                    formatLabel: (v) => v.toInt().toString(),
                    suffix: '',
                  ),

                  const SizedBox(height: 24),

                  // Kilometre Aralığı
                  _buildSectionTitle('Kilometre'),
                  _buildRangeSlider(
                    value: _mileageRange,
                    min: 0,
                    max: 500000,
                    divisions: 100,
                    onChanged: (value) => setState(() => _mileageRange = value),
                    formatLabel: _formatMileage,
                    suffix: ' km',
                  ),

                  const SizedBox(height: 24),

                  // Gövde Tipi
                  _buildSectionTitle('Gövde Tipi'),
                  _buildChipGroupData<CarBodyTypeData>(
                    items: widget.bodyTypesData,
                    selectedIds: _bodyTypeIds,
                    getLabel: (t) => t.name,
                    getIcon: (t) => _getIconDataForBodyType(t.icon),
                    getId: (t) => t.id,
                    onTap: (t) => setState(() {
                      if (_bodyTypeIds.contains(t.id)) {
                        _bodyTypeIds.remove(t.id);
                      } else {
                        _bodyTypeIds.add(t.id);
                      }
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Yakıt Tipi
                  _buildSectionTitle('Yakıt Tipi'),
                  _buildChipGroupData<CarFuelTypeData>(
                    items: widget.fuelTypesData,
                    selectedIds: _fuelTypeIds,
                    getLabel: (t) => t.name,
                    getIcon: (t) => _getIconDataForFuelType(t.icon),
                    getId: (t) => t.id,
                    onTap: (t) => setState(() {
                      if (_fuelTypeIds.contains(t.id)) {
                        _fuelTypeIds.remove(t.id);
                      } else {
                        _fuelTypeIds.add(t.id);
                      }
                    }),
                    getColor: (t) => t.colorValue,
                  ),

                  const SizedBox(height: 24),

                  // Vites Tipi
                  _buildSectionTitle('Vites Tipi'),
                  _buildChipGroupData<CarTransmissionData>(
                    items: widget.transmissionsData,
                    selectedIds: _transmissionIds,
                    getLabel: (t) => t.name,
                    getIcon: (t) => _getIconDataForTransmission(t.icon),
                    getId: (t) => t.id,
                    onTap: (t) => setState(() {
                      if (_transmissionIds.contains(t.id)) {
                        _transmissionIds.remove(t.id);
                      } else {
                        _transmissionIds.add(t.id);
                      }
                    }),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Alt butonlar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CarSalesColors.card(widget.isDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // İptal butonu
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CarSalesColors.textPrimary(widget.isDark),
                        side: BorderSide(color: CarSalesColors.border(widget.isDark)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'İptal',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Uygula butonu
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(
                          _bodyTypeIds,
                          _fuelTypeIds,
                          _transmissionIds,
                          _brandIds,
                          _priceRange,
                          _yearRange,
                          _mileageRange,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CarSalesColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _activeFilterCount > 0
                                ? 'Uygula ($_activeFilterCount)'
                                : 'Uygula',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: CarSalesColors.textPrimary(widget.isDark),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRangeSlider({
    required RangeValues value,
    required double min,
    required double max,
    required int divisions,
    required void Function(RangeValues) onChanged,
    required String Function(double) formatLabel,
    required String suffix,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CarSalesColors.surface(widget.isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${formatLabel(value.start)}$suffix',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(widget.isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '-',
              style: TextStyle(
                color: CarSalesColors.textSecondary(widget.isDark),
                fontSize: 18,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CarSalesColors.surface(widget.isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${formatLabel(value.end)}$suffix',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(widget.isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: CarSalesColors.primary,
            inactiveTrackColor: CarSalesColors.border(widget.isDark),
            thumbColor: CarSalesColors.primary,
            overlayColor: CarSalesColors.primary.withValues(alpha: 0.2),
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
          ),
          child: RangeSlider(
            values: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildChipGroupData<T>({
    required List<T> items,
    required Set<String> selectedIds,
    required String Function(T) getLabel,
    required IconData Function(T) getIcon,
    required String Function(T) getId,
    required void Function(T) onTap,
    Color Function(T)? getColor,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Yükleniyor...',
          style: TextStyle(color: CarSalesColors.textTertiary(widget.isDark)),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final itemId = getId(item);
        final isSelected = selectedIds.contains(itemId);
        final color = getColor?.call(item) ?? CarSalesColors.primary;

        return GestureDetector(
          onTap: () => onTap(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : CarSalesColors.surface(widget.isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : CarSalesColors.border(widget.isDark),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getIcon(item),
                  size: 18,
                  color: isSelected ? color : CarSalesColors.textSecondary(widget.isDark),
                ),
                const SizedBox(width: 8),
                Text(
                  getLabel(item),
                  style: TextStyle(
                    color: isSelected ? color : CarSalesColors.textSecondary(widget.isDark),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check, size: 16, color: color),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
