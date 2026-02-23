import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/emlak_models.dart';
import '../../../providers/property_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/property_list_item.dart';
import '../widgets/property_filter_bar.dart';

/// Listings management screen -- shows all user properties with
/// filtering by status and text search, plus grid/list toggle.
class ListingsScreen extends ConsumerStatefulWidget {
  const ListingsScreen({super.key});

  @override
  ConsumerState<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends ConsumerState<ListingsScreen> {
  String _searchQuery = '';
  String? _selectedStatus; // null = all
  bool _isGridView = false;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _statusColor(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.active:
        return AppColors.success;
      case PropertyStatus.pending:
        return AppColors.warning;
      case PropertyStatus.sold:
        return AppColors.error;
      case PropertyStatus.rented:
        return AppColors.info;
      case PropertyStatus.reserved:
        return AppColors.accent;
    }
  }

  List<Property> _filterProperties(List<Property> all) {
    var filtered = all;

    // Status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((p) => p.status.name == _selectedStatus).toList();
    }

    // Text search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.location.shortAddress.toLowerCase().contains(q) ||
            p.location.fullAddress.toLowerCase().contains(q) ||
            p.formattedPrice.toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  String _formatFullPrice(double price, String? currency) {
    final cur = currency ?? 'TL';
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted $cur';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final userProperties = ref.watch(userPropertiesProvider);
    final allProperties = userProperties.allProperties;
    final filtered = _filterProperties(allProperties);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Column(
      children: [
        // Filter bar
        PropertyFilterBar(
          selectedStatus: _selectedStatus,
          onStatusChanged: (status) => setState(() => _selectedStatus = status),
          searchQuery: _searchQuery,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          isGridView: _isGridView,
          onToggleView: () => setState(() => _isGridView = !_isGridView),
        ),

        Divider(height: 1, color: AppColors.border(isDark)),

        // Content area
        Expanded(
          child: userProperties.isLoading
              ? const Center(child: CircularProgressIndicator())
              : allProperties.isEmpty
                  ? EmptyState(
                      message: 'Henuz ilaniniz yok',
                      icon: Icons.home_work_outlined,
                      buttonText: 'Yeni Ilan Ekle',
                      onPressed: () => context.push('/listings/add'),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: AppColors.textMuted(isDark),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Filtrelere uygun ilan bulunamadi',
                                style: TextStyle(
                                  color: AppColors.textSecondary(isDark),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : isDesktop
                          ? _buildDesktopTable(filtered, isDark)
                          : _buildMobileList(filtered),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile list view
  // ---------------------------------------------------------------------------

  Widget _buildMobileList(List<Property> properties) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return PropertyListItem(
          property: property,
          onTap: () => context.push('/listings/${property.id}'),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop DataTable view
  // ---------------------------------------------------------------------------

  Widget _buildDesktopTable(List<Property> properties, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(isDark)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
            ),
            headingTextStyle: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            dataTextStyle: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontSize: 14,
            ),
            columnSpacing: 24,
            horizontalMargin: 20,
            columns: const [
              DataColumn(label: Text('Ilan')),
              DataColumn(label: Text('Konum')),
              DataColumn(label: Text('Fiyat')),
              DataColumn(label: Text('Durum')),
              DataColumn(label: Text('Goruntulenme')),
              DataColumn(label: Text('Islemler')),
            ],
            rows: properties.map((property) {
              void goToDetail() =>
                  context.push('/listings/${property.id}');

              return DataRow(
                cells: [
                  // Photo + title
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: property.images.isNotEmpty
                              ? Image.network(
                                  property.images.first,
                                  width: 48,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _buildTablePlaceholder(isDark),
                                )
                              : _buildTablePlaceholder(isDark),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                property.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(isDark),
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                property.type.label,
                                style: TextStyle(
                                  color: AppColors.textMuted(isDark),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: goToDetail,
                  ),

                  // Location
                  DataCell(
                    Text(
                      property.location.shortAddress,
                      style: TextStyle(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 13,
                      ),
                    ),
                    onTap: goToDetail,
                  ),

                  // Price
                  DataCell(
                    Text(
                      _formatFullPrice(property.price, property.currency),
                      style: const TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onTap: goToDetail,
                  ),

                  // Status badge
                  DataCell(
                    StatusBadge(
                      label: property.status.label,
                      color: _statusColor(property.status),
                    ),
                    onTap: goToDetail,
                  ),

                  // View count
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppColors.textMuted(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${property.viewCount}',
                          style: TextStyle(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    onTap: goToDetail,
                  ),

                  // Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Duzenle',
                          onPressed: goToDetail,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          tooltip: 'Sil',
                          onPressed: () =>
                              _showDeleteConfirmation(property),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
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
    );
  }

  Widget _buildTablePlaceholder(bool isDark) {
    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.home,
        size: 18,
        color: AppColors.textMuted(isDark),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete confirmation
  // ---------------------------------------------------------------------------

  void _showDeleteConfirmation(Property property) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Ilani Sil',
          style: TextStyle(color: AppColors.textPrimary(isDark)),
        ),
        content: Text(
          '"${property.title}" ilanini silmek istediginize emin misiniz? Bu islem geri alinamaz.',
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Iptal',
              style: TextStyle(color: AppColors.textMuted(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(userPropertiesProvider.notifier).deleteProperty(property.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
