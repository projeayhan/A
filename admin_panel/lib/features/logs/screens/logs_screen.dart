import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

// Logs Provider with filters
final logsFilterProvider = StateProvider<LogsFilter>((ref) => LogsFilter());

class LogsFilter {
  final String? actionType;
  final String? severity;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;

  LogsFilter({
    this.actionType,
    this.severity,
    this.startDate,
    this.endDate,
    this.searchQuery,
  });

  LogsFilter copyWith({
    String? actionType,
    String? severity,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    bool clearActionType = false,
    bool clearSeverity = false,
  }) {
    return LogsFilter(
      actionType: clearActionType ? null : (actionType ?? this.actionType),
      severity: clearSeverity ? null : (severity ?? this.severity),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final logsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final filter = ref.watch(logsFilterProvider);

  // Build query with filters first, then order/limit
  var query = supabase.from('admin_logs').select('*');

  if (filter.actionType != null && filter.actionType!.isNotEmpty) {
    query = query.eq('action_type', filter.actionType!);
  }

  if (filter.severity != null && filter.severity!.isNotEmpty) {
    query = query.eq('severity', filter.severity!);
  }

  if (filter.startDate != null) {
    query = query.gte('created_at', filter.startDate!.toIso8601String());
  }

  if (filter.endDate != null) {
    query = query.lte(
      'created_at',
      filter.endDate!.add(const Duration(days: 1)).toIso8601String(),
    );
  }

  final response = await query.order('created_at', ascending: false).limit(500);
  var logs = List<Map<String, dynamic>>.from(response);

  // Client-side search filtering
  if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
    final searchLower = filter.searchQuery!.toLowerCase();
    logs = logs.where((log) {
      final description = (log['description'] ?? '').toString().toLowerCase();
      final action = (log['action'] ?? '').toString().toLowerCase();
      final adminName = (log['admin_name'] ?? '').toString().toLowerCase();
      final targetName = (log['target_name'] ?? '').toString().toLowerCase();
      return description.contains(searchLower) ||
          action.contains(searchLower) ||
          adminName.contains(searchLower) ||
          targetName.contains(searchLower);
    }).toList();
  }

  return logs;
});

// Log stats provider
final logStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);

  final todayLogs = await supabase
      .from('admin_logs')
      .select('id')
      .gte('created_at', todayStart.toIso8601String())
      .count();

  final errorLogs = await supabase
      .from('admin_logs')
      .select('id')
      .eq('severity', 'error')
      .gte(
        'created_at',
        todayStart.subtract(const Duration(days: 7)).toIso8601String(),
      )
      .count();

  final criticalLogs = await supabase
      .from('admin_logs')
      .select('id')
      .eq('severity', 'critical')
      .gte(
        'created_at',
        todayStart.subtract(const Duration(days: 7)).toIso8601String(),
      )
      .count();

  final totalLogs = await supabase.from('admin_logs').select('id').count();

  return {
    'today': todayLogs.count,
    'errors': errorLogs.count,
    'critical': criticalLogs.count,
    'total': totalLogs.count,
  };
});

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(logsProvider);
    final statsAsync = ref.watch(logStatsProvider);
    final filter = ref.watch(logsFilterProvider);

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
                      'Log Kayitlari',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sistem ve admin islem kayitlari',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _exportLogs(),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Disa Aktar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(logsProvider);
                        ref.invalidate(logStatsProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: statsAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Hata: $e'),
              data: (stats) => Row(
                children: [
                  _buildStatCard(
                    'Bugun',
                    stats['today'] ?? 0,
                    Icons.today,
                    AppColors.primary,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Toplam',
                    stats['total'] ?? 0,
                    Icons.list_alt,
                    AppColors.info,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Hatalar (7 gun)',
                    stats['errors'] ?? 0,
                    Icons.error_outline,
                    AppColors.warning,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Kritik (7 gun)',
                    stats['critical'] ?? 0,
                    Icons.warning_amber,
                    AppColors.error,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Ara...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          ref.read(logsFilterProvider.notifier).state = filter
                              .copyWith(searchQuery: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Action Type Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: filter.actionType,
                        decoration: InputDecoration(
                          labelText: 'Islem Tipi',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Tumunu Goster'),
                          ),
                          DropdownMenuItem(
                            value: 'user',
                            child: Text('Kullanici'),
                          ),
                          DropdownMenuItem(
                            value: 'merchant',
                            child: Text('Isletme'),
                          ),
                          DropdownMenuItem(
                            value: 'order',
                            child: Text('Siparis'),
                          ),
                          DropdownMenuItem(
                            value: 'courier',
                            child: Text('Kurye'),
                          ),
                          DropdownMenuItem(value: 'taxi', child: Text('Taksi')),
                          DropdownMenuItem(
                            value: 'settings',
                            child: Text('Ayarlar'),
                          ),
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('Sistem'),
                          ),
                          DropdownMenuItem(
                            value: 'auth',
                            child: Text('Oturum'),
                          ),
                        ],
                        onChanged: (value) {
                          ref
                              .read(logsFilterProvider.notifier)
                              .state = value == null
                              ? filter.copyWith(clearActionType: true)
                              : filter.copyWith(actionType: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Severity Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: filter.severity,
                        decoration: InputDecoration(
                          labelText: 'Onem',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Tumunu Goster'),
                          ),
                          DropdownMenuItem(value: 'info', child: Text('Bilgi')),
                          DropdownMenuItem(
                            value: 'warning',
                            child: Text('Uyari'),
                          ),
                          DropdownMenuItem(value: 'error', child: Text('Hata')),
                          DropdownMenuItem(
                            value: 'critical',
                            child: Text('Kritik'),
                          ),
                        ],
                        onChanged: (value) {
                          ref
                              .read(logsFilterProvider.notifier)
                              .state = value == null
                              ? filter.copyWith(clearSeverity: true)
                              : filter.copyWith(severity: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Clear Filters
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        ref.read(logsFilterProvider.notifier).state =
                            LogsFilter();
                      },
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Filtreleri Temizle',
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Logs Table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                child: logsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Hata: $e')),
                  data: (logs) => logs.isEmpty
                      ? const Center(child: Text('Log kaydi bulunamadi'))
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 1000,
                            columns: const [
                              DataColumn2(
                                label: Text('Tarih'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(label: Text('Onem'), fixedWidth: 80),
                              DataColumn2(
                                label: Text('Islem'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(label: Text('Tip'), fixedWidth: 100),
                              DataColumn2(
                                label: Text('Aciklama'),
                                size: ColumnSize.L,
                              ),
                              DataColumn2(
                                label: Text('Admin'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(label: Text('Detay'), fixedWidth: 60),
                            ],
                            rows: logs.map((log) => _buildLogRow(log)).toList(),
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DataRow2 _buildLogRow(Map<String, dynamic> log) {
    final createdAt = DateTime.tryParse(log['created_at'] ?? '');
    final dateStr = createdAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt)
        : '-';
    final severity = log['severity'] ?? 'info';
    final action = log['action'] ?? '-';
    final actionType = log['action_type'] ?? '-';
    final description = log['description'] ?? '-';
    final adminName = log['admin_name'] ?? '-';

    return DataRow2(
      cells: [
        DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
        DataCell(_buildSeverityBadge(severity)),
        DataCell(
          Text(_formatAction(action), style: const TextStyle(fontSize: 12)),
        ),
        DataCell(_buildActionTypeBadge(actionType)),
        DataCell(
          Tooltip(
            message: description,
            child: Text(
              description.length > 50
                  ? '${description.substring(0, 50)}...'
                  : description,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(adminName, style: const TextStyle(fontSize: 12))),
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility, size: 18),
            onPressed: () => _showLogDetails(log),
            tooltip: 'Detay',
          ),
        ),
      ],
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    String text;
    IconData icon;

    switch (severity) {
      case 'critical':
        color = AppColors.error;
        text = 'Kritik';
        icon = Icons.error;
        break;
      case 'error':
        color = AppColors.error;
        text = 'Hata';
        icon = Icons.error_outline;
        break;
      case 'warning':
        color = AppColors.warning;
        text = 'Uyari';
        icon = Icons.warning_amber;
        break;
      default:
        color = AppColors.info;
        text = 'Bilgi';
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTypeBadge(String actionType) {
    Color color;
    switch (actionType) {
      case 'user':
        color = AppColors.info;
        break;
      case 'merchant':
        color = AppColors.success;
        break;
      case 'order':
        color = AppColors.primary;
        break;
      case 'courier':
        color = AppColors.warning;
        break;
      case 'system':
        color = AppColors.textMuted;
        break;
      case 'auth':
        color = const Color(0xFF9C27B0);
        break;
      default:
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatActionType(actionType),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatAction(String action) {
    final actions = {
      'create': 'Olusturma',
      'update': 'Guncelleme',
      'delete': 'Silme',
      'login': 'Giris',
      'logout': 'Cikis',
      'approve': 'Onaylama',
      'reject': 'Reddetme',
      'system_start': 'Sistem Baslat',
      'migration_run': 'Migrasyon',
    };
    return actions[action] ?? action;
  }

  String _formatActionType(String actionType) {
    final types = {
      'user': 'Kullanici',
      'merchant': 'Isletme',
      'order': 'Siparis',
      'courier': 'Kurye',
      'taxi': 'Taksi',
      'settings': 'Ayarlar',
      'system': 'Sistem',
      'auth': 'Oturum',
    };
    return types[actionType] ?? actionType;
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _buildSeverityBadge(log['severity'] ?? 'info'),
            const SizedBox(width: 12),
            const Text('Log Detayi'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Tarih', _formatDateTime(log['created_at'])),
                _buildDetailRow('Islem', _formatAction(log['action'] ?? '-')),
                _buildDetailRow(
                  'Tip',
                  _formatActionType(log['action_type'] ?? '-'),
                ),
                _buildDetailRow('Aciklama', log['description'] ?? '-'),
                _buildDetailRow('Admin', log['admin_name'] ?? '-'),
                _buildDetailRow('Admin Email', log['admin_email'] ?? '-'),
                _buildDetailRow('Hedef Tablo', log['target_table'] ?? '-'),
                _buildDetailRow('Hedef ID', log['target_id'] ?? '-'),
                _buildDetailRow('Hedef Ad', log['target_name'] ?? '-'),
                _buildDetailRow('IP Adresi', log['ip_address'] ?? '-'),
                if (log['old_data'] != null) ...[
                  const Divider(),
                  const Text(
                    'Eski Veri:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _formatJson(log['old_data']),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (log['new_data'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Yeni Veri:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _formatJson(log['new_data']),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('dd.MM.yyyy HH:mm:ss').format(date);
  }

  String _formatJson(dynamic data) {
    if (data == null) return '-';
    try {
      if (data is String) return data;
      return data.toString();
    } catch (e) {
      return data.toString();
    }
  }

  void _exportLogs() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log kayitlari disa aktariliyor...')),
    );
    // TODO: Implement export functionality
  }
}
