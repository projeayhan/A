import 'package:flutter/material.dart';
import '../../models/car_sales/car_sales_models.dart';

/// Filtre seçim sheet'i - kompakt multi-select
class FilterSelectionSheet<T> extends StatefulWidget {
  final bool isDark;
  final String title;
  final List<T> items;
  final Set<String> selectedIds;
  final String Function(T) getLabel;
  final IconData Function(T) getIcon;
  final String Function(T) getId;
  final Color Function(T)? getColor;
  final void Function(Set<String>) onChanged;

  const FilterSelectionSheet({
    super.key,
    required this.isDark,
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.getLabel,
    required this.getIcon,
    required this.getId,
    this.getColor,
    required this.onChanged,
  });

  @override
  State<FilterSelectionSheet<T>> createState() => _FilterSelectionSheetState<T>();
}

class _FilterSelectionSheetState<T> extends State<FilterSelectionSheet<T>> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CarSalesColors.card(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(widget.isDark),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (_selected.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _selected.clear());
                        },
                        child: const Text(
                          'Temizle',
                          style: TextStyle(color: CarSalesColors.accent),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        widget.onChanged(_selected);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CarSalesColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text('Uygula${_selected.isNotEmpty ? ' (${_selected.length})' : ''}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Items
          Flexible(
            child: widget.items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final id = widget.getId(item);
                      final isSelected = _selected.contains(id);
                      final color = widget.getColor?.call(item) ?? CarSalesColors.primary;

                      return ListTile(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(id);
                            } else {
                              _selected.add(id);
                            }
                          });
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.15)
                                : CarSalesColors.surface(widget.isDark),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? color : CarSalesColors.border(widget.isDark),
                            ),
                          ),
                          child: Icon(
                            widget.getIcon(item),
                            size: 20,
                            color: isSelected ? color : CarSalesColors.textSecondary(widget.isDark),
                          ),
                        ),
                        title: Text(
                          widget.getLabel(item),
                          style: TextStyle(
                            color: CarSalesColors.textPrimary(widget.isDark),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: color)
                            : Icon(
                                Icons.circle_outlined,
                                color: CarSalesColors.border(widget.isDark),
                              ),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
