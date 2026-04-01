import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';
import '../../../shared/widgets/pagination_controls.dart';
import '../../invoices/screens/web_download_helper.dart' if (dart.library.io) '../../invoices/screens/io_download_helper.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Timer? _debounce;

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;

  // Sorting
  String _sortColumn = 'created_at';
  bool _sortAscending = false;

  // Data
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  // Bulk operations
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);

      // Get total count
      final countResponse = await supabase
          .from('users')
          .select('id')
          .count();
      _totalCount = countResponse.count;

      // Get paginated data
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      final response = await supabase
          .from('users')
          .select()
          .order(_sortColumn, ascending: _sortAscending)
          .range(from, to);

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 999999);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
                      'Kullanıcılar',
                      style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tüm kullanıcıları yönetin',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_isSelectionMode && _selectedIds.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_selectedIds.length} seçili',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _bulkBanUsers,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Toplu Yasakla'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _bulkExportSelected,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Seçileni Dışa Aktar'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() {
                          _isSelectionMode = false;
                          _selectedIds.clear();
                        }),
                        icon: const Icon(Icons.close),
                        tooltip: 'Seçimi İptal Et',
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _isSelectionMode = !_isSelectionMode),
                        icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist, size: 18),
                        label: Text(_isSelectionMode ? 'Seçimi Kapat' : 'Toplu İşlem'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _showAddUserInfo,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Kullanıcı Ekle'),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            setState(() => _searchQuery = value);
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Kullanıcı ara...',
                        prefixIcon: Icon(Icons.search, color: textMuted),
                        filled: true,
                        fillColor: bgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: surfaceColor,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tüm Durumlar')),
                          DropdownMenuItem(value: 'active', child: Text('Aktif')),
                          DropdownMenuItem(value: 'inactive', child: Text('Pasif')),
                          DropdownMenuItem(value: 'banned', child: Text('Yasaklı')),
                        ],
                        onChanged: (value) => setState(() => _statusFilter = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _handleExport,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Dışa Aktar'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Expanded(child: _buildDataTable(textPrimary, textMuted, bgColor)),
                          PaginationControls(
                            currentPage: _currentPage,
                            totalPages: _totalPages,
                            totalCount: _totalCount,
                            pageSize: _pageSize,
                            onPrevious: () {
                              setState(() => _currentPage--);
                              _fetchUsers();
                            },
                            onNext: () {
                              setState(() => _currentPage++);
                              _fetchUsers();
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(Color textPrimary, Color textMuted, Color bgColor) {
    var filteredUsers = _users.where((user) {
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());

      if (_statusFilter == 'all') return matchesSearch;
      if (_statusFilter == 'banned') return matchesSearch && (user['is_banned'] == true);
      return matchesSearch && user['status'] == _statusFilter;
    }).toList();

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: 900,
      headingRowColor: WidgetStateProperty.all(bgColor),
      headingTextStyle: TextStyle(color: textMuted, fontWeight: FontWeight.w600, fontSize: 12),
      dataTextStyle: TextStyle(color: textPrimary, fontSize: 14),
      sortColumnIndex: _getSortColumnIndex(),
      sortAscending: _sortAscending,
      columns: [
        if (_isSelectionMode)
          DataColumn2(
            label: Checkbox(
              value: _selectedIds.length == filteredUsers.length && filteredUsers.isNotEmpty,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.addAll(filteredUsers.map((u) => u['id'].toString()));
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
            fixedWidth: 50,
          ),
        DataColumn2(
          label: const Text('KULLANICI'),
          size: ColumnSize.L,
          onSort: (_, ascending) => _onSort('full_name', ascending),
        ),
        DataColumn2(
          label: const Text('E-POSTA'),
          size: ColumnSize.L,
          onSort: (_, ascending) => _onSort('email', ascending),
        ),
        DataColumn2(
          label: const Text('TELEFON'),
          size: ColumnSize.M,
        ),
        DataColumn2(
          label: const Text('KAYIT TARİHİ'),
          size: ColumnSize.M,
          onSort: (_, ascending) => _onSort('created_at', ascending),
        ),
        const DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        const DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.S),
      ],
      rows: filteredUsers.map((user) {
        final userId = user['id'].toString();
        return DataRow2(
          selected: _selectedIds.contains(userId),
          onSelectChanged: _isSelectionMode
              ? (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.add(userId);
                    } else {
                      _selectedIds.remove(userId);
                    }
                  });
                }
              : null,
          cells: [
            if (_isSelectionMode)
              DataCell(
                Checkbox(
                  value: _selectedIds.contains(userId),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedIds.add(userId);
                      } else {
                        _selectedIds.remove(userId);
                      }
                    });
                  },
                ),
              ),
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                    child: user['avatar_url'] == null
                        ? Text(
                            () { final n = (user['full_name']?.toString() ?? '').trim(); return n.isEmpty ? 'U' : n[0].toUpperCase(); }(),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user['full_name'] ?? 'İsimsiz',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            DataCell(Text(user['email'] ?? '-', overflow: TextOverflow.ellipsis)),
            DataCell(Text(user['phone'] ?? '-')),
            DataCell(Text(_formatDate(user['created_at']))),
            DataCell(_buildStatusBadge(user)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showUserDetails(user),
                    icon: const Icon(Icons.visibility, size: 18),
                    color: textMuted,
                    tooltip: 'Görüntüle',
                  ),
                  IconButton(
                    onPressed: () => _showEditUserDialog(user),
                    icon: const Icon(Icons.edit, size: 18),
                    color: AppColors.info,
                    tooltip: 'Düzenle',
                  ),
                  IconButton(
                    onPressed: user['is_banned'] == true ? null : () => _banUser(user),
                    icon: const Icon(Icons.block, size: 18),
                    color: user['is_banned'] == true ? textMuted : AppColors.error,
                    tooltip: user['is_banned'] == true ? 'Zaten yasaklı' : 'Yasakla',
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  int? _getSortColumnIndex() {
    final offset = _isSelectionMode ? 1 : 0;
    switch (_sortColumn) {
      case 'full_name': return 0 + offset;
      case 'email': return 1 + offset;
      case 'created_at': return 3 + offset;
      default: return null;
    }
  }

  void _onSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _currentPage = 0;
    });
    _fetchUsers();
  }

  Widget _buildStatusBadge(Map<String, dynamic> user) {
    if (user['is_banned'] == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Yasaklı', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500)),
      );
    }

    final status = user['status'] ?? 'active';
    Color color;
    String text;
    switch (status) {
      case 'active': color = AppColors.success; text = 'Aktif'; break;
      case 'inactive': color = AppColors.warning; text = 'Pasif'; break;
      case 'banned': color = AppColors.error; text = 'Yasaklı'; break;
      default: color = AppColors.textMuted; text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return '-';
    }
  }

  void _showAddUserInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kullanıcılar uygulama üzerinden kayıt olur'), backgroundColor: AppColors.info),
    );
  }

  Future<void> _handleExport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel hazırlanıyor...'), backgroundColor: AppColors.info),
      );

      final supabase = ref.read(supabaseProvider);
      final allUsers = await supabase.from('users').select().order('created_at', ascending: false);
      final users = List<Map<String, dynamic>>.from(allUsers);
      final bytes = await InvoiceService.exportUsersToExcel(users);
      downloadFile(Uint8List.fromList(bytes), 'kullanicilar_${DateTime.now().millisecondsSinceEpoch}.xlsx');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel başarıyla indirildi'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dışa aktarma hatası: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _bulkExportSelected() async {
    final selected = _users.where((u) => _selectedIds.contains(u['id'].toString())).toList();
    if (selected.isEmpty) return;

    try {
      final bytes = await InvoiceService.exportUsersToExcel(selected);
      downloadFile(Uint8List.fromList(bytes), 'secili_kullanicilar_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seçili kullanıcılar dışa aktarıldı'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _bulkBanUsers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu Yasaklama'),
        content: Text('${_selectedIds.length} kullanıcıyı yasaklamak istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yasakla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      final bannedIds = List<String>.from(_selectedIds);

      for (final id in bannedIds) {
        await supabase.from('users').update({
          'is_banned': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      }

      if (!mounted) return;

      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${bannedIds.length} kullanıcı yasaklandı'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Geri Al',
            textColor: Colors.white,
            onPressed: () async {
              for (final id in bannedIds) {
                await supabase.from('users').update({
                  'is_banned': false,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', id);
              }
              _fetchUsers();
            },
          ),
        ),
      );

      _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _banUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Yasakla'),
        content: Text('${user['full_name'] ?? 'Bu kullanıcı'}\'yı yasaklamak istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yasakla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      final userId = user['id'];

      await supabase.from('users').update({
        'is_banned': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['full_name'] ?? 'Kullanıcı'} yasaklandı'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Geri Al',
            textColor: Colors.white,
            onPressed: () async {
              await supabase.from('users').update({
                'is_banned': false,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', userId);
              _fetchUsers();
            },
          ),
        ),
      );

      _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcı Detayları'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Ad Soyad', user['full_name'] ?? '-'),
              const SizedBox(height: 12),
              _buildDetailRow('E-posta', user['email'] ?? '-'),
              const SizedBox(height: 12),
              _buildDetailRow('Telefon', user['phone'] ?? '-'),
              const SizedBox(height: 12),
              _buildDetailRow('Kayıt Tarihi', _formatDate(user['created_at'])),
              const SizedBox(height: 12),
              _buildDetailRow('Durum', user['is_banned'] == true ? 'Yasaklı' : (user['status'] ?? 'active')),
              const SizedBox(height: 12),
              _buildDetailRow('Kullanıcı ID', user['id'] ?? '-'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary))),
      ],
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['full_name'] ?? '');
    final phoneController = TextEditingController(text: user['phone'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcı Düzenle'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefon',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ad Soyad boş olamaz'), backgroundColor: AppColors.error),
                );
                return;
              }
              try {
                final supabase = ref.read(supabaseProvider);
                await supabase.from('users').update({
                  'full_name': name,
                  'phone': phone.isEmpty ? null : phone,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', user['id']);
                if (!context.mounted) return;
                Navigator.pop(context);
                _fetchUsers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı başarıyla güncellendi'), backgroundColor: AppColors.success),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
