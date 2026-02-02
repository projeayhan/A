import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/supabase_service.dart';

// Tab index provider
final securityTabProvider = StateProvider<int>((ref) => 0);

// Security events provider
final securityEventsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('security_events')
      .select('*')
      .order('created_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(response);
});

// Failed logins provider
final failedLoginsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('failed_login_attempts')
      .select('*')
      .order('last_attempt_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(response);
});

// System errors provider
final systemErrorsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('system_errors')
      .select('*')
      .order('last_occurred_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(response);
});

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(securityStatsProvider);
    final currentTab = ref.watch(securityTabProvider);

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
                      'Güvenlik Merkezi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sistem güvenliği ve hata izleme',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        ref.invalidate(securityStatsProvider);
                        ref.invalidate(securityEventsProvider);
                        ref.invalidate(failedLoginsProvider);
                        ref.invalidate(systemErrorsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Yenile',
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            statsAsync.when(
              data: (stats) => _buildStatsCards(stats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Hata: $e'),
            ),

            const SizedBox(height: 24),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTab(ref, 0, 'Güvenlik Olayları', Icons.security),
                  _buildTab(ref, 1, 'Başarısız Girişler', Icons.login),
                  _buildTab(ref, 2, 'Sistem Hataları', Icons.error_outline),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildTabContent(ref, currentTab),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Güvenlik Olayları',
            '${stats['total_security_events'] ?? 0}',
            Icons.shield,
            AppColors.primary,
            subtitle: 'Son 24 saat',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Kritik Olaylar',
            '${stats['critical_events'] ?? 0}',
            Icons.warning_amber,
            AppColors.error,
            subtitle: 'Acil müdahale',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Aktif Bloklar',
            '${stats['active_blocks'] ?? 0}',
            Icons.block,
            AppColors.warning,
            subtitle: 'Engellenen IP/Email',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Sistem Hataları',
            '${stats['system_errors'] ?? 0}',
            Icons.bug_report,
            AppColors.info,
            subtitle: '${stats['unresolved_errors'] ?? 0} çözülmemiş',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(WidgetRef ref, int index, String label, IconData icon) {
    final currentTab = ref.watch(securityTabProvider);
    final isSelected = currentTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(securityTabProvider.notifier).state = index,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(WidgetRef ref, int tab) {
    switch (tab) {
      case 0:
        return _buildSecurityEventsTab(ref);
      case 1:
        return _buildFailedLoginsTab(ref);
      case 2:
        return _buildSystemErrorsTab(ref);
      default:
        return const SizedBox();
    }
  }

  Widget _buildSecurityEventsTab(WidgetRef ref) {
    final eventsAsync = ref.watch(securityEventsProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: AppColors.success),
                SizedBox(height: 16),
                Text(
                  'Güvenlik olayı yok',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return DataTable2(
          columnSpacing: 12,
          horizontalMargin: 16,
          minWidth: 800,
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          columns: const [
            DataColumn2(
              label: Text(
                'Tarih',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text('Tür', style: TextStyle(fontWeight: FontWeight.w600)),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text(
                'Önem',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 100,
            ),
            DataColumn2(
              label: Text(
                'Açıklama',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              size: ColumnSize.L,
            ),
            DataColumn2(
              label: Text('IP', style: TextStyle(fontWeight: FontWeight.w600)),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text(
                'Uygulama',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 120,
            ),
            DataColumn2(
              label: Text(
                'Durum',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 100,
            ),
          ],
          rows: events.map((event) {
            final createdAt = DateTime.tryParse(event['created_at'] ?? '');
            final eventType = event['event_type'] ?? '';
            final severity = event['severity'] ?? 'info';
            final description = event['description'] ?? '';
            final ip = event['source_ip'] ?? '-';
            final appSource = event['app_source'] ?? 'admin_panel';
            final resolved = event['resolved'] == true;

            return DataRow2(
              cells: [
                DataCell(
                  Text(
                    createdAt != null
                        ? DateFormat('dd.MM HH:mm').format(createdAt)
                        : '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataCell(_buildEventTypeBadge(eventType)),
                DataCell(_buildSeverityBadge(severity)),
                DataCell(
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Text(
                    ip,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                DataCell(_buildAppSourceBadge(appSource)),
                DataCell(
                  Row(
                    children: [
                      _buildStatusBadge(resolved),
                      if (!resolved) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          color: AppColors.success,
                          tooltip: 'Çözüldü olarak işaretle',
                          onPressed: () =>
                              _resolveSecurityEvent(ref, event['id']),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Future<void> _resolveSecurityEvent(WidgetRef ref, String eventId) async {
    try {
      final service = ref.read(securityServiceProvider);
      await service.resolveSecurityEvent(eventId, 'Admin tarafından çözüldü');
      ref.invalidate(securityEventsProvider);
      ref.invalidate(securityStatsProvider);
    } catch (e) {
      // Handle error silently
    }
  }

  Widget _buildFailedLoginsTab(WidgetRef ref) {
    final loginsAsync = ref.watch(failedLoginsProvider);

    return loginsAsync.when(
      data: (logins) {
        if (logins.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: AppColors.success),
                SizedBox(height: 16),
                Text(
                  'Başarısız giriş denemesi yok',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return DataTable2(
          columnSpacing: 12,
          horizontalMargin: 16,
          minWidth: 700,
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          columns: const [
            DataColumn2(
              label: Text(
                'Son Deneme',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              size: ColumnSize.L,
            ),
            DataColumn2(
              label: Text('IP', style: TextStyle(fontWeight: FontWeight.w600)),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text(
                'Uygulama',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 100,
            ),
            DataColumn2(
              label: Text(
                'Deneme',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 80,
            ),
            DataColumn2(
              label: Text(
                'Durum',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 120,
            ),
          ],
          rows: logins.map((login) {
            final lastAttempt = DateTime.tryParse(
              login['last_attempt_at'] ?? '',
            );
            final email = login['email'] ?? '-';
            final ip = login['ip_address'] ?? '-';
            final loginAppSource = login['app_source'] ?? 'admin_panel';
            final count = login['attempt_count'] ?? 0;
            final isBlocked = login['is_blocked'] == true;
            final blockedUntil = DateTime.tryParse(
              login['blocked_until'] ?? '',
            );

            return DataRow2(
              color: isBlocked
                  ? WidgetStateProperty.all(
                      AppColors.error.withValues(alpha: 0.05),
                    )
                  : null,
              cells: [
                DataCell(
                  Text(
                    lastAttempt != null
                        ? DateFormat('dd.MM HH:mm').format(lastAttempt)
                        : '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataCell(Text(email, style: const TextStyle(fontSize: 13))),
                DataCell(
                  Text(
                    ip,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                DataCell(_buildAppSourceBadge(loginAppSource)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: count >= 5
                          ? AppColors.error.withValues(alpha: 0.15)
                          : AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: count >= 5 ? AppColors.error : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      if (isBlocked)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Engellendi',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (blockedUntil != null)
                              Text(
                                "${DateFormat('HH:mm').format(blockedUntil)}'e kadar",
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        )
                      else
                        const Text(
                          'Aktif',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                          ),
                        ),
                      if (isBlocked) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.lock_open, size: 18),
                          color: AppColors.warning,
                          tooltip: 'Engeli Kaldır',
                          onPressed: () => _unblockLogin(ref, login['id']),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Future<void> _unblockLogin(WidgetRef ref, String attemptId) async {
    try {
      final service = ref.read(securityServiceProvider);
      await service.unblockLogin(attemptId);
      ref.invalidate(failedLoginsProvider);
      ref.invalidate(securityStatsProvider);
    } catch (e) {
      // Handle error silently
    }
  }

  Widget _buildSystemErrorsTab(WidgetRef ref) {
    final errorsAsync = ref.watch(systemErrorsProvider);

    return errorsAsync.when(
      data: (errors) {
        if (errors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: AppColors.success),
                SizedBox(height: 16),
                Text(
                  'Sistem hatası yok',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return DataTable2(
          columnSpacing: 12,
          horizontalMargin: 16,
          minWidth: 800,
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          columns: const [
            DataColumn2(
              label: Text(
                'Son Görülme',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text('Tür', style: TextStyle(fontWeight: FontWeight.w600)),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text(
                'Önem',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 100,
            ),
            DataColumn2(
              label: Text(
                'Mesaj',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              size: ColumnSize.L,
            ),
            DataColumn2(
              label: Text(
                'Sayı',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 70,
            ),
            DataColumn2(
              label: Text(
                'Durum',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              fixedWidth: 100,
            ),
          ],
          rows: errors.map((error) {
            final lastOccurred = DateTime.tryParse(
              error['last_occurred_at'] ?? '',
            );
            final errorType = error['error_type'] ?? '';
            final severity = error['severity'] ?? 'error';
            final message = error['error_message'] ?? '';
            final count = error['occurrence_count'] ?? 1;
            final resolved = error['resolved'] == true;

            return DataRow2(
              cells: [
                DataCell(
                  Text(
                    lastOccurred != null
                        ? DateFormat('dd.MM HH:mm').format(lastOccurred)
                        : '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataCell(_buildErrorTypeBadge(errorType)),
                DataCell(_buildSeverityBadge(severity)),
                DataCell(
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Text(
                    'x$count',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: count > 5
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      _buildStatusBadge(resolved),
                      if (!resolved) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          color: AppColors.success,
                          tooltip: 'Çözüldü olarak işaretle',
                          onPressed: () =>
                              _resolveSystemError(ref, error['id']),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Future<void> _resolveSystemError(WidgetRef ref, String errorId) async {
    try {
      final service = ref.read(securityServiceProvider);
      await service.resolveSystemError(errorId);
      ref.invalidate(systemErrorsProvider);
      ref.invalidate(securityStatsProvider);
    } catch (e) {
      // Handle error silently
    }
  }

  Widget _buildEventTypeBadge(String type) {
    IconData icon;
    Color color;
    String label;

    switch (type) {
      case 'brute_force':
        icon = Icons.gpp_bad;
        color = AppColors.error;
        label = 'Brute Force';
        break;
      case 'failed_login':
        icon = Icons.login;
        color = AppColors.warning;
        label = 'Başarısız Giriş';
        break;
      case 'unauthorized_access':
        icon = Icons.block;
        color = AppColors.error;
        label = 'Yetkisiz Erişim';
        break;
      case 'rate_limit':
        icon = Icons.speed;
        color = AppColors.warning;
        label = 'Rate Limit';
        break;
      case 'sql_injection':
        icon = Icons.bug_report;
        color = AppColors.error;
        label = 'SQL Injection';
        break;
      case 'xss_attempt':
        icon = Icons.code;
        color = AppColors.error;
        label = 'XSS Denemesi';
        break;
      default:
        icon = Icons.info;
        color = AppColors.info;
        label = type;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildErrorTypeBadge(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'database':
        icon = Icons.storage;
        color = AppColors.error;
        break;
      case 'api':
        icon = Icons.api;
        color = AppColors.warning;
        break;
      case 'auth':
        icon = Icons.lock;
        color = AppColors.error;
        break;
      case 'storage':
        icon = Icons.cloud;
        color = AppColors.info;
        break;
      default:
        icon = Icons.error;
        color = AppColors.textMuted;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(type, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildAppSourceBadge(String appSource) {
    String label;
    Color color;
    IconData icon;

    switch (appSource) {
      case 'super_app':
        label = 'Müşteri';
        color = AppColors.primary;
        icon = Icons.phone_android;
        break;
      case 'courier_app':
        label = 'Kurye';
        color = AppColors.warning;
        icon = Icons.delivery_dining;
        break;
      case 'taxi_app':
        label = 'Taksi';
        color = AppColors.info;
        icon = Icons.local_taxi;
        break;
      case 'merchant_panel':
        label = 'İşletme';
        color = AppColors.success;
        icon = Icons.store;
        break;
      case 'admin_panel':
        label = 'Admin';
        color = AppColors.error;
        icon = Icons.admin_panel_settings;
        break;
      default:
        label = appSource;
        color = AppColors.textMuted;
        icon = Icons.apps;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    String label;

    switch (severity) {
      case 'critical':
        color = const Color(0xFFB71C1C);
        label = 'KRİTİK';
        break;
      case 'alert':
        color = AppColors.error;
        label = 'UYARI';
        break;
      case 'warning':
        color = AppColors.warning;
        label = 'DİKKAT';
        break;
      case 'error':
        color = AppColors.error;
        label = 'HATA';
        break;
      default:
        color = AppColors.info;
        label = 'BİLGİ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool resolved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: resolved
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        resolved ? 'Çözüldü' : 'Bekliyor',
        style: TextStyle(
          color: resolved ? AppColors.success : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
