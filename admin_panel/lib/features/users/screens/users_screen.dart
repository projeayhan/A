import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Users provider
final usersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('users')
      .select()
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(response);
});

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kullanıcılar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tüm kullanıcıları yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Kullanıcı Ekle'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  // Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Kullanıcı ara...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Status Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.surface,
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
                  // Export Button
                  OutlinedButton.icon(
                    onPressed: () {},
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: usersAsync.when(
                  data: (users) => _buildDataTable(users),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Hata: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> users) {
    // Filter users
    var filteredUsers = users.where((user) {
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());

      if (_statusFilter == 'all') return matchesSearch;
      return matchesSearch && user['status'] == _statusFilter;
    }).toList();

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: 800,
      headingRowColor: WidgetStateProperty.all(AppColors.background),
      headingTextStyle: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      dataTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      columns: const [
        DataColumn2(label: Text('KULLANICI'), size: ColumnSize.L),
        DataColumn2(label: Text('E-POSTA'), size: ColumnSize.L),
        DataColumn2(label: Text('TELEFON'), size: ColumnSize.M),
        DataColumn2(label: Text('KAYIT TARİHİ'), size: ColumnSize.M),
        DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.S),
      ],
      rows: filteredUsers.map((user) {
        return DataRow2(
          cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundImage: user['avatar_url'] != null
                        ? NetworkImage(user['avatar_url'])
                        : null,
                    child: user['avatar_url'] == null
                        ? Text(
                            (user['full_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
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
            DataCell(_buildStatusBadge(user['status'] ?? 'active')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Görüntüle',
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 18),
                    color: AppColors.info,
                    tooltip: 'Düzenle',
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.block, size: 18),
                    color: AppColors.error,
                    tooltip: 'Yasakla',
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'active':
        color = AppColors.success;
        text = 'Aktif';
        break;
      case 'inactive':
        color = AppColors.warning;
        text = 'Pasif';
        break;
      case 'banned':
        color = AppColors.error;
        text = 'Yasaklı';
        break;
      default:
        color = AppColors.textMuted;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
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
}
