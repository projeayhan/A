import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../invoices/screens/web_download_helper.dart'
    if (dart.library.io) '../../invoices/screens/io_download_helper.dart';

// ── Filter State ──
final logsFilterProvider = StateProvider<LogsFilter>((ref) => LogsFilter());

class LogsFilter {
  final String? appName;
  final String? level;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;

  LogsFilter({
    this.appName,
    this.level,
    this.startDate,
    this.endDate,
    this.searchQuery,
  });

  LogsFilter copyWith({
    String? appName,
    String? level,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    bool clearAppName = false,
    bool clearLevel = false,
  }) {
    return LogsFilter(
      appName: clearAppName ? null : (appName ?? this.appName),
      level: clearLevel ? null : (level ?? this.level),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// ── Logs Data Provider ──
final logsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final filter = ref.watch(logsFilterProvider);

  var query = supabase.from('app_logs').select('*');

  if (filter.appName != null && filter.appName!.isNotEmpty) {
    query = query.eq('app_name', filter.appName!);
  }
  if (filter.level != null && filter.level!.isNotEmpty) {
    query = query.eq('level', filter.level!);
  }
  if (filter.startDate != null) {
    query = query.gte('created_at', filter.startDate!.toIso8601String());
  }
  if (filter.endDate != null) {
    query = query.lte('created_at',
        filter.endDate!.add(const Duration(days: 1)).toIso8601String());
  }

  final response = await query.order('created_at', ascending: false).limit(500);
  var logs = List<Map<String, dynamic>>.from(response);

  if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
    final q = filter.searchQuery!.toLowerCase();
    logs = logs.where((log) {
      final msg = (log['message'] ?? '').toString().toLowerCase();
      final src = (log['source'] ?? '').toString().toLowerCase();
      final detail = (log['error_detail'] ?? '').toString().toLowerCase();
      return msg.contains(q) || src.contains(q) || detail.contains(q);
    }).toList();
  }

  return logs;
});

// ── Stats Provider ──
final logStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final weekAgo = todayStart.subtract(const Duration(days: 7));

  final todayCount = await supabase
      .from('app_logs')
      .select('id')
      .gte('created_at', todayStart.toIso8601String())
      .count();
  final errorsCount = await supabase
      .from('app_logs')
      .select('id')
      .eq('level', 'error')
      .gte('created_at', weekAgo.toIso8601String())
      .count();
  final warnsCount = await supabase
      .from('app_logs')
      .select('id')
      .eq('level', 'warn')
      .gte('created_at', weekAgo.toIso8601String())
      .count();
  final totalCount = await supabase.from('app_logs').select('id').count();
  final topErrorData = await supabase
      .from('app_logs')
      .select('app_name')
      .eq('level', 'error')
      .gte('created_at', todayStart.toIso8601String())
      .limit(100);

  // Find top error app
  final errorLogs = List<Map<String, dynamic>>.from(topErrorData);
  final appCounts = <String, int>{};
  for (final log in errorLogs) {
    final app = log['app_name'] as String? ?? '';
    appCounts[app] = (appCounts[app] ?? 0) + 1;
  }
  String? topErrorApp;
  int topErrorCount = 0;
  for (final entry in appCounts.entries) {
    if (entry.value > topErrorCount) {
      topErrorCount = entry.value;
      topErrorApp = entry.key;
    }
  }

  return {
    'today': todayCount.count,
    'errors_week': errorsCount.count,
    'warns_week': warnsCount.count,
    'total': totalCount.count,
    'top_error_app': topErrorApp,
    'top_error_count': topErrorCount,
  };
});

// ── Screen ──
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final _searchController = TextEditingController();
  StreamSubscription? _realtimeSub;
  final List<Map<String, dynamic>> _realtimeLogs = [];

  @override
  void initState() {
    super.initState();
    _setupRealtime();
  }

  void _setupRealtime() {
    final supabase = ref.read(supabaseProvider);
    _realtimeSub = supabase
        .from('app_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() {
          _realtimeLogs.insert(0, data.first);
          if (_realtimeLogs.length > 50) _realtimeLogs.removeLast();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeSub?.cancel();
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
                    Text('Merkezi Log Kayitlari',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Tum uygulamalardan gelen sistem loglari',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exportLogs,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Disa Aktar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _realtimeLogs.clear());
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

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: statsAsync.when(
              loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('Hata: $e'),
              data: (stats) => Row(
                children: [
                  _buildStatCard('Bugun', stats['today'] ?? 0,
                      Icons.today, AppColors.primary,
                      tooltipText: 'Bugun toplam ${stats['today'] ?? 0} log kaydi olusturuldu. Tiklayin: tum loglari gorun'),
                  const SizedBox(width: 16),
                  _buildStatCard('Toplam', stats['total'] ?? 0,
                      Icons.list_alt, AppColors.info,
                      tooltipText: 'Veritabanindaki toplam log sayisi (son 30 gun). Eski loglar otomatik temizlenir'),
                  const SizedBox(width: 16),
                  _buildStatCard('Hatalar (7g)', stats['errors_week'] ?? 0,
                      Icons.error_outline, AppColors.error,
                      filterLevel: 'error',
                      tooltipText: 'Son 7 gunde ${stats['errors_week'] ?? 0} hata logu. Tiklayin: sadece hatalari filtreleyin'),
                  const SizedBox(width: 16),
                  _buildStatCard('Uyarilar (7g)', stats['warns_week'] ?? 0,
                      Icons.warning_amber, AppColors.warning,
                      filterLevel: 'warn',
                      tooltipText: 'Son 7 gunde ${stats['warns_week'] ?? 0} uyari logu. Tiklayin: sadece uyarilari filtreleyin'),
                  const SizedBox(width: 16),
                  _buildTopErrorCard(stats['top_error_app'],
                      stats['top_error_count'] ?? 0),
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
                          hintText: 'Mesaj, kaynak veya detay ara...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          ref.read(logsFilterProvider.notifier).state =
                              filter.copyWith(searchQuery: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // App Name Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: filter.appName,
                        decoration: InputDecoration(
                          labelText: 'Uygulama',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tumunu Goster')),
                          DropdownMenuItem(value: 'admin_panel', child: Text('Admin Panel')),
                          DropdownMenuItem(value: 'merchant_panel', child: Text('Isletme Paneli')),
                          DropdownMenuItem(value: 'super_app', child: Text('Super App')),
                          DropdownMenuItem(value: 'courier_app', child: Text('Kurye App')),
                          DropdownMenuItem(value: 'taxi_app', child: Text('Taksi App')),
                          DropdownMenuItem(value: 'emlakci_panel', child: Text('Emlakci Panel')),
                          DropdownMenuItem(value: 'arac_satis_panel', child: Text('Arac Satis')),
                          DropdownMenuItem(value: 'rent_a_car_panel', child: Text('Rent a Car')),
                          DropdownMenuItem(value: 'support_panel', child: Text('Destek Paneli')),
                          DropdownMenuItem(value: 'edge_function', child: Text('Edge Functions')),
                        ],
                        onChanged: (value) {
                          ref.read(logsFilterProvider.notifier).state = value == null
                              ? filter.copyWith(clearAppName: true)
                              : filter.copyWith(appName: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Level Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: filter.level,
                        decoration: InputDecoration(
                          labelText: 'Seviye',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tumunu Goster')),
                          DropdownMenuItem(value: 'error', child: Text('Error')),
                          DropdownMenuItem(value: 'warn', child: Text('Warn')),
                          DropdownMenuItem(value: 'info', child: Text('Info')),
                          DropdownMenuItem(value: 'debug', child: Text('Debug')),
                        ],
                        onChanged: (value) {
                          ref.read(logsFilterProvider.notifier).state = value == null
                              ? filter.copyWith(clearLevel: true)
                              : filter.copyWith(level: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Date range
                    IconButton(
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 90)),
                          lastDate: DateTime.now(),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (range != null) {
                          ref.read(logsFilterProvider.notifier).state =
                              filter.copyWith(
                                  startDate: range.start, endDate: range.end);
                        }
                      },
                      icon: Icon(Icons.date_range,
                          color: filter.startDate != null
                              ? AppColors.primary
                              : null),
                      tooltip: 'Tarih Araligi',
                    ),

                    // Clear
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        ref.read(logsFilterProvider.notifier).state = LogsFilter();
                      },
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Filtreleri Temizle',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Realtime indicator
          if (_realtimeLogs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('${_realtimeLogs.length} yeni log geldi',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _realtimeLogs.clear());
                        ref.invalidate(logsProvider);
                      },
                      child: const Text('Yenile', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Logs Table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                child: logsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
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
                              DataColumn2(label: Text('Tarih'), size: ColumnSize.S),
                              DataColumn2(label: Text('Seviye'), fixedWidth: 80),
                              DataColumn2(label: Text('Uygulama'), fixedWidth: 120),
                              DataColumn2(label: Text('Mesaj'), size: ColumnSize.L),
                              DataColumn2(label: Text('Kaynak'), size: ColumnSize.S),
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

  Widget _buildStatCard(String title, int value, IconData icon, Color color,
      {String? filterLevel, String? tooltipText}) {
    final tooltipMsg = tooltipText ?? '$title: $value adet log kaydi';
    return Expanded(
      child: Tooltip(
        message: tooltipMsg,
        preferBelow: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: filterLevel != null
              ? () {
                  ref.read(logsFilterProvider.notifier).state =
                      LogsFilter(level: filterLevel);
                }
              : null,
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
                    Text(title,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(value.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopErrorCard(String? appName, int count) {
    final tooltipMsg = appName != null
        ? 'Bugun en cok hata ureten uygulama: $appName ($count hata). Tiklayin: bu uygulamanin hatalarini gorun'
        : 'Bugun hic hata logu yok - harika!';
    return Expanded(
      child: Tooltip(
        message: tooltipMsg,
        preferBelow: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: appName != null
              ? () {
                  ref.read(logsFilterProvider.notifier).state =
                      LogsFilter(appName: appName, level: 'error');
                }
              : null,
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
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bug_report, color: AppColors.error, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('En Cok Hata',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        appName != null ? '$appName ($count)' : 'Hata yok',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow2 _buildLogRow(Map<String, dynamic> log) {
    final createdAt = DateTime.tryParse(log['created_at'] ?? '');
    final dateStr = createdAt != null
        ? DateFormat('dd.MM.yyyy HH:mm:ss').format(createdAt)
        : '-';
    final level = log['level'] ?? 'info';
    final appName = log['app_name'] ?? '-';
    final message = log['message'] ?? '-';
    final source = log['source'] ?? '-';
    final errorDetail = log['error_detail']?.toString() ?? '';
    final hasDetail = errorDetail.isNotEmpty || log['metadata'] != null;

    return DataRow2(
      onTap: () => _showLogDetails(log),
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return AppColors.primary.withValues(alpha: 0.05);
        }
        if (level == 'error') return AppColors.error.withValues(alpha: 0.03);
        return null;
      }),
      cells: [
        DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
        DataCell(_buildLevelBadge(level)),
        DataCell(_buildAppBadge(appName)),
        DataCell(
          Tooltip(
            richMessage: TextSpan(
              children: [
                TextSpan(
                  text: '$message\n',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (source != '-')
                  TextSpan(
                    text: 'Kaynak: $source\n',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                if (errorDetail.isNotEmpty)
                  TextSpan(
                    text: 'Detay: ${errorDetail.length > 200 ? '${errorDetail.substring(0, 200)}...' : errorDetail}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                if (!hasDetail)
                  const TextSpan(
                    text: 'Tiklayin: detay gorun',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
              ],
            ),
            waitDuration: const Duration(milliseconds: 400),
            child: Text(
              message.length > 60 ? '${message.substring(0, 60)}...' : message,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Tooltip(
            message: source != '-'
                ? 'Kaynak dosya/metod: $source'
                : 'Kaynak bilgisi yok',
            child: Text(source,
                style: TextStyle(
                    fontSize: 12,
                    color: source != '-' ? null : AppColors.textMuted)),
          ),
        ),
        DataCell(
          IconButton(
            icon: Icon(
              hasDetail ? Icons.visibility : Icons.visibility_outlined,
              size: 18,
              color: hasDetail ? AppColors.primary : AppColors.textMuted,
            ),
            onPressed: () => _showLogDetails(log),
            tooltip: hasDetail
                ? 'Hata detayi ve metadata mevcut - tiklayin'
                : 'Log detayini gorun',
          ),
        ),
      ],
    );
  }

  Widget _buildLevelBadge(String level) {
    Color color;
    String text;
    IconData icon;
    String tooltip;

    switch (level) {
      case 'error':
        color = AppColors.error;
        text = 'Error';
        icon = Icons.error_outline;
        tooltip = 'Hata: Uygulama hatasi veya yakalanmamis exception. Tiklayin: sadece hatalari filtreleyin';
        break;
      case 'warn':
        color = AppColors.warning;
        text = 'Warn';
        icon = Icons.warning_amber;
        tooltip = 'Uyari: Potansiyel sorun, uygulama calismaya devam etti. Tiklayin: sadece uyarilari filtreleyin';
        break;
      case 'info':
        color = AppColors.info;
        text = 'Info';
        icon = Icons.info_outline;
        tooltip = 'Bilgi: Normal islem kaydi (giris, basarili islem vb). Tiklayin: sadece bilgi loglarini filtreleyin';
        break;
      case 'debug':
        color = AppColors.textMuted;
        text = 'Debug';
        icon = Icons.bug_report;
        tooltip = 'Debug: Gelistirici icin detayli bilgi. Sadece debug modda gonderilir. Tiklayin: filtreleyin';
        break;
      default:
        color = AppColors.textMuted;
        text = level;
        icon = Icons.circle;
        tooltip = level;
    }

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          ref.read(logsFilterProvider.notifier).state =
              LogsFilter(level: level);
        },
        child: Container(
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
              Text(text,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBadge(String appName) {
    final colors = {
      'admin_panel': AppColors.primary,
      'merchant_panel': AppColors.success,
      'super_app': AppColors.info,
      'courier_app': AppColors.warning,
      'taxi_app': const Color(0xFF9C27B0),
      'emlakci_panel': const Color(0xFF009688),
      'arac_satis_panel': const Color(0xFFFF5722),
      'rent_a_car_panel': const Color(0xFF607D8B),
      'support_panel': const Color(0xFF795548),
    };
    final shortNames = {
      'admin_panel': 'Admin',
      'merchant_panel': 'Isletme',
      'super_app': 'SuperApp',
      'courier_app': 'Kurye',
      'taxi_app': 'Taksi',
      'emlakci_panel': 'Emlak',
      'arac_satis_panel': 'Arac',
      'rent_a_car_panel': 'Kiralama',
      'support_panel': 'Destek',
    };
    final fullNames = {
      'admin_panel': 'Admin Paneli - Yonetim uygulamasi',
      'merchant_panel': 'Isletme Paneli - Restoran/magaza yonetimi',
      'super_app': 'Super App - Musteri mobil uygulamasi',
      'courier_app': 'Kurye App - Kurye mobil uygulamasi',
      'taxi_app': 'Taksi App - Taksi surucu uygulamasi',
      'emlakci_panel': 'Emlakci Panel - Emlak danismani paneli',
      'arac_satis_panel': 'Arac Satis Panel - Galeri/bayi paneli',
      'rent_a_car_panel': 'Rent a Car Panel - Arac kiralama paneli',
      'support_panel': 'Destek Paneli - Musteri destek uygulamasi',
    };

    final color = colors[appName] ?? AppColors.textMuted;
    final label = shortNames[appName] ??
        (appName.startsWith('edge_') ? 'Edge' : appName);
    final fullName = fullNames[appName] ??
        (appName.startsWith('edge_function')
            ? 'Edge Function: ${appName.replaceFirst('edge_function_', '')} - Sunucu tarafli islem'
            : appName);

    return Tooltip(
      message: '$fullName\nTiklayin: bu uygulamanin loglarini filtreleyin',
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          ref.read(logsFilterProvider.notifier).state =
              LogsFilter(appName: appName);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    final metadata = log['metadata'];
    String metadataStr = '-';
    if (metadata != null) {
      try {
        if (metadata is Map) {
          metadataStr = const JsonEncoder.withIndent('  ').convert(metadata);
        } else {
          metadataStr = metadata.toString();
        }
      } catch (_) {
        metadataStr = metadata.toString();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _buildLevelBadge(log['level'] ?? 'info'),
            const SizedBox(width: 8),
            _buildAppBadge(log['app_name'] ?? ''),
            const SizedBox(width: 12),
            const Text('Log Detayi'),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Tarih', _formatDateTime(log['created_at'])),
                _buildDetailRow('Uygulama', log['app_name'] ?? '-'),
                _buildDetailRow('Seviye', log['level'] ?? '-'),
                _buildDetailRow('Mesaj', log['message'] ?? '-'),
                _buildDetailRow('Kaynak', log['source'] ?? '-'),
                _buildDetailRow('Kullanici ID', log['user_id'] ?? '-'),
                if (log['error_detail'] != null &&
                    log['error_detail'].toString().isNotEmpty) ...[
                  const Divider(),
                  const Text('Hata Detayi / Stack Trace:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: SelectableText(
                      log['error_detail'].toString(),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ],
                if (metadata != null) ...[
                  const SizedBox(height: 16),
                  const Text('Metadata:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      metadataStr,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
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
            child: Text(label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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

  Future<void> _exportLogs() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log kayitlari disa aktariliyor...'),
          backgroundColor: AppColors.info,
        ),
      );

      final supabase = ref.read(supabaseProvider);
      final allLogs = await supabase
          .from('app_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(5000);
      final logs = List<Map<String, dynamic>>.from(allLogs);
      final bytes = await InvoiceService.exportLogsToExcel(logs);
      downloadFile(
        Uint8List.fromList(bytes),
        'app_logs_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log kayitlari basariyla indirildi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disa aktarma hatasi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
