import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/models/sector_type.dart';
import '../../../core/theme/app_theme.dart';
import '../services/business_service.dart';

class BusinessListingScreen extends ConsumerStatefulWidget {
  final SectorType sector;

  const BusinessListingScreen({super.key, required this.sector});

  @override
  ConsumerState<BusinessListingScreen> createState() => _BusinessListingScreenState();
}

class _BusinessListingScreenState extends ConsumerState<BusinessListingScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Timer? _debounce;

  int _currentPage = 0;
  final int _pageSize = 25;
  int _totalCount = 0;

  List<Map<String, dynamic>> _businesses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant BusinessListingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sector != widget.sector) {
      _currentPage = 0;
      _searchQuery = '';
      _statusFilter = 'all';
      _fetchData();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(businessServiceProvider);
      final result = await service.fetchBusinesses(
        sector: widget.sector,
        searchQuery: _searchQuery,
        statusFilter: _statusFilter,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _businesses = result.data;
        _totalCount = result.totalCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = value;
        _currentPage = 0;
      });
      _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(widget.sector.icon, size: 28, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                widget.sector.label,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => context.go('${widget.sector.baseRoute}/ayarlar'),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Sektör Ayarları'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '${widget.sector.label} ara... (ad, email, telefon)',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tüm Durumlar')),
                    DropdownMenuItem(value: 'active', child: Text('Aktif')),
                    DropdownMenuItem(value: 'inactive', child: Text('Pasif')),
                    DropdownMenuItem(value: 'pending', child: Text('Beklemede')),
                    DropdownMenuItem(value: 'suspended', child: Text('Askıda')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value ?? 'all';
                      _currentPage = 0;
                    });
                    _fetchData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Data Table
          Expanded(
            child: _buildTable(isDark),
          ),

          // Pagination
          if (!_isLoading && _businesses.isNotEmpty)
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildTable(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Hata: $_error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _fetchData, child: const Text('Tekrar Dene')),
          ],
        ),
      );
    }

    if (_businesses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.sector.icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '${widget.sector.label} bulunamadı',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0),
        ),
      ),
      child: DataTable2(
        columnSpacing: 16,
        horizontalMargin: 16,
        minWidth: 700,
        headingRowColor: WidgetStateProperty.all(
          isDark ? AppColors.surfaceLight.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        ),
        columns: [
          const DataColumn2(label: Text('Ad', style: TextStyle(fontWeight: FontWeight.bold)), size: ColumnSize.L),
          const DataColumn2(label: Text('Durum', style: TextStyle(fontWeight: FontWeight.bold)), size: ColumnSize.S),
          const DataColumn2(label: Text('Kayıt Tarihi', style: TextStyle(fontWeight: FontWeight.bold)), size: ColumnSize.M),
          DataColumn2(label: Text(widget.sector.countLabel, style: const TextStyle(fontWeight: FontWeight.bold)), size: ColumnSize.S),
        ],
        rows: _businesses.map((business) {
          final name = business[widget.sector.nameField] ?? business['name'] ?? business['full_name'] ?? business['company_name'] ?? business['business_name'] ?? '-';
          final status = business['status'] as String? ?? (business['is_approved'] == true ? 'active' : (business['is_approved'] == false ? 'inactive' : 'unknown'));
          final createdAt = business['created_at'] ?? '';
          final dateStr = createdAt.toString().length >= 10 ? createdAt.toString().substring(0, 10) : '-';

          return DataRow2(
            onTap: () {
              final id = business[widget.sector.idField]?.toString() ?? '';
              if (id.isNotEmpty) {
                context.go('${widget.sector.baseRoute}/$id');
              }
            },
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(widget.sector.icon, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          if (business['email'] != null)
                            Text(business['email'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(_buildStatusChip(status)),
              DataCell(Text(dateStr)),
              DataCell(Text('${widget.sector.countField != null ? (business[widget.sector.countField] ?? 0) : 0}')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = AppColors.success;
        label = 'Aktif';
      case 'inactive':
        color = Colors.grey;
        label = 'Pasif';
      case 'pending':
        color = AppColors.warning;
        label = 'Beklemede';
      case 'suspended':
        color = AppColors.error;
        label = 'Askıda';
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_currentPage * _pageSize + 1}-${(_currentPage + 1) * _pageSize > _totalCount ? _totalCount : (_currentPage + 1) * _pageSize} / $_totalCount kayıt',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () {
                        setState(() => _currentPage--);
                        _fetchData();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_currentPage + 1} / $totalPages'),
              IconButton(
                onPressed: _currentPage < totalPages - 1
                    ? () {
                        setState(() => _currentPage++);
                        _fetchData();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
