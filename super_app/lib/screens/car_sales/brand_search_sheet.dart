import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/car_sales/car_sales_models.dart';

/// Marka arama ve seçme sheet'i
class BrandSearchSheet extends StatefulWidget {
  final bool isDark;
  final Set<String> selectedBrandIds;
  final void Function(String) onBrandSelected;

  const BrandSearchSheet({
    super.key,
    required this.isDark,
    required this.selectedBrandIds,
    required this.onBrandSelected,
  });

  @override
  State<BrandSearchSheet> createState() => _BrandSearchSheetState();
}

class _BrandSearchSheetState extends State<BrandSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCountry = 'Tümü';

  final List<String> _countries = ['Tümü', 'Almanya', 'Japonya', 'ABD', 'G. Kore', 'Fransa', 'İtalya', 'İngiltere'];

  List<CarBrand> get _filteredBrands {
    var brands = CarBrand.allBrands;

    // Ülke filtresi
    if (_selectedCountry != 'Tümü') {
      brands = brands.where((b) => b.country == _selectedCountry).toList();
    }

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      brands = brands
          .where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return brands;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Text(
                  'Marka Seç',
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(widget.isDark),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.selectedBrandIds.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '${widget.selectedBrandIds.length} Seçili',
                      style: const TextStyle(
                        color: CarSalesColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Arama
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Marka ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: CarSalesColors.surface(widget.isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Ülke filtreleri
          Container(
            height: 44,
            margin: const EdgeInsets.only(top: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _countries.length,
              itemBuilder: (context, index) {
                final country = _countries[index];
                final isSelected = _selectedCountry == country;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCountry = country),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CarSalesColors.primary
                          : CarSalesColors.surface(widget.isDark),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      country,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : CarSalesColors.textSecondary(widget.isDark),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Marka listesi
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredBrands.length,
              itemBuilder: (context, index) {
                final brand = _filteredBrands[index];
                final isSelected = widget.selectedBrandIds.contains(brand.id);

                return GestureDetector(
                  onTap: () {
                    widget.onBrandSelected(brand.id);
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CarSalesColors.primary.withValues(alpha: 0.1)
                          : CarSalesColors.surface(widget.isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? CarSalesColors.primary
                            : CarSalesColors.border(widget.isDark),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: brand.logoUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => Center(
                                child: Text(
                                  brand.name.substring(0, 1),
                                  style: const TextStyle(
                                    color: CarSalesColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  brand.name.substring(0, 1),
                                  style: const TextStyle(
                                    color: CarSalesColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          brand.name.length > 8
                              ? '${brand.name.substring(0, 7)}..'
                              : brand.name,
                          style: TextStyle(
                            color: isSelected
                                ? CarSalesColors.primary
                                : CarSalesColors.textPrimary(widget.isDark),
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: CarSalesColors.primary,
                            size: 14,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Alt buton
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CarSalesColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.selectedBrandIds.isEmpty
                        ? 'Kapat'
                        : '${widget.selectedBrandIds.length} Marka Seçildi - Uygula',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
