import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// System health overview provider
final systemHealthProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.rpc('get_system_health_overview');
  return Map<String, dynamic>.from(response ?? {});
});

// Recovery rules provider
final recoveryRulesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('auto_recovery_rules')
      .select('*')
      .order('priority');
  return List<Map<String, dynamic>>.from(response);
});

// Recovery logs provider
final recoveryLogsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('recovery_logs')
      .select('*, auto_recovery_rules(name)')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(response);
});

// Alerts provider
final alertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('alert_history')
      .select('*')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(response);
});

// Tab provider
final healthTabProvider = StateProvider<int>((ref) => 0);

class SystemHealthScreen extends ConsumerWidget {
  const SystemHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(systemHealthProvider);
    final currentTab = ref.watch(healthTabProvider);

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
                      'Sistem Sağlığı',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Otomatik kurtarma ve sistem izleme',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _runHealthCheck(ref, context),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Sağlık Kontrolü'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        ref.invalidate(systemHealthProvider);
                        ref.invalidate(recoveryLogsProvider);
                        ref.invalidate(alertsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Yenile',
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Overall Status & Stats
            healthAsync.when(
              data: (health) => _buildHealthOverview(health),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Hata: $e'),
            ),

            const SizedBox(height: 24),

            // Service Status Cards
            healthAsync.when(
              data: (health) => _buildServiceCards(health),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
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
                  _buildTab(ref, 0, 'Kurtarma İşlemleri', Icons.healing),
                  _buildTab(ref, 1, 'Uyarılar', Icons.notifications_active),
                  _buildTab(ref, 2, 'Kurtarma Kuralları', Icons.rule),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Content
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

  Widget _buildHealthOverview(Map<String, dynamic> health) {
    final overallStatus = health['overall_status'] ?? 'unknown';
    final stats = health['stats'] ?? {};
    final pendingAlerts = health['pending_alerts'] ?? 0;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (overallStatus) {
      case 'healthy':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusText = 'Sistem Sağlıklı';
        break;
      case 'degraded':
        statusColor = AppColors.warning;
        statusIcon = Icons.warning;
        statusText = 'Performans Düşük';
        break;
      case 'unhealthy':
        statusColor = AppColors.error;
        statusIcon = Icons.error;
        statusText = 'Sistem Sorunlu';
        break;
      default:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.help;
        statusText = 'Bilinmiyor';
    }

    return Row(
      children: [
        // Overall Status
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Genel sistem durumu',
                      style: TextStyle(
                        color: statusColor.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Stats
        Expanded(
          child: _buildStatCard(
            'Hatalar (24s)',
            '${stats['total_errors_24h'] ?? 0}',
            Icons.bug_report,
            AppColors.error,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Kurtarmalar',
            '${stats['successful_recoveries_24h'] ?? 0}/${stats['total_recoveries_24h'] ?? 0}',
            Icons.healing,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Bekleyen Uyarı',
            '$pendingAlerts',
            Icons.notifications,
            pendingAlerts > 0 ? AppColors.warning : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCards(Map<String, dynamic> health) {
    final services = (health['services'] as List<dynamic>?) ?? [];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final service = services[index] as Map<String, dynamic>;
          return _buildServiceCard(service);
        },
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final name = service['name'] ?? '';
    final status = service['status'] ?? 'unknown';
    final responseTime = service['response_time_ms'];
    final errorCount = service['error_count_1h'] ?? 0;

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'healthy':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'degraded':
        statusColor = AppColors.warning;
        statusIcon = Icons.warning;
        break;
      case 'unhealthy':
        statusColor = AppColors.error;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.help;
    }

    IconData serviceIcon;
    switch (name) {
      case 'database':
        serviceIcon = Icons.storage;
        break;
      case 'auth':
        serviceIcon = Icons.lock;
        break;
      case 'storage':
        serviceIcon = Icons.cloud;
        break;
      case 'realtime':
        serviceIcon = Icons.sync;
        break;
      case 'edge_functions':
        serviceIcon = Icons.functions;
        break;
      case 'api':
        serviceIcon = Icons.api;
        break;
      default:
        serviceIcon = Icons.miscellaneous_services;
    }

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(serviceIcon, color: AppColors.textSecondary, size: 20),
              Icon(statusIcon, color: statusColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name.toString().toUpperCase(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (responseTime != null) ...[
                Text(
                  '${responseTime}ms',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (errorCount > 0)
                Text(
                  '$errorCount hata',
                  style: const TextStyle(color: AppColors.error, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(WidgetRef ref, int index, String label, IconData icon) {
    final currentTab = ref.watch(healthTabProvider);
    final isSelected = currentTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(healthTabProvider.notifier).state = index,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
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
        return _buildRecoveryLogsTab(ref);
      case 1:
        return _buildAlertsTab(ref);
      case 2:
        return _buildRecoveryRulesTab(ref);
      default:
        return const SizedBox();
    }
  }

  Widget _buildRecoveryLogsTab(WidgetRef ref) {
    final logsAsync = ref.watch(recoveryLogsProvider);

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.healing, size: 64, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text(
                  'Kurtarma işlemi yok',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppColors.surfaceLight),
          itemBuilder: (context, index) {
            final log = logs[index];
            final createdAt = DateTime.tryParse(log['created_at'] ?? '');
            final status = log['status'] ?? 'unknown';
            final action = log['action_taken'] ?? '';
            final ruleName =
                log['auto_recovery_rules']?['name'] ?? 'Bilinmeyen Kural';

            Color statusColor;
            IconData statusIcon;
            switch (status) {
              case 'success':
                statusColor = AppColors.success;
                statusIcon = Icons.check_circle;
                break;
              case 'failed':
                statusColor = AppColors.error;
                statusIcon = Icons.cancel;
                break;
              case 'running':
                statusColor = AppColors.info;
                statusIcon = Icons.sync;
                break;
              default:
                statusColor = AppColors.textMuted;
                statusIcon = Icons.help;
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              title: Text(
                ruleName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('$action • ${log['result_message'] ?? ''}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    createdAt != null
                        ? DateFormat('dd.MM HH:mm').format(createdAt)
                        : '',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (log['execution_time_ms'] != null)
                    Text(
                      '${log['execution_time_ms']}ms',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Widget _buildAlertsTab(WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return alertsAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                SizedBox(height: 16),
                Text('Uyarı yok', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: alerts.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppColors.surfaceLight),
          itemBuilder: (context, index) {
            final alert = alerts[index];
            final createdAt = DateTime.tryParse(alert['created_at'] ?? '');
            final severity = alert['severity'] ?? 'info';
            final acknowledged = alert['acknowledged'] == true;

            Color severityColor;
            switch (severity) {
              case 'critical':
                severityColor = const Color(0xFFB71C1C);
                break;
              case 'alert':
                severityColor = AppColors.error;
                break;
              case 'warning':
                severityColor = AppColors.warning;
                break;
              default:
                severityColor = AppColors.info;
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: severityColor.withValues(alpha: 0.15),
                child: Icon(
                  acknowledged ? Icons.check : Icons.notifications_active,
                  color: severityColor,
                  size: 20,
                ),
              ),
              title: Text(
                alert['title'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: acknowledged ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(alert['message'] ?? ''),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    createdAt != null
                        ? DateFormat('dd.MM HH:mm').format(createdAt)
                        : '',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: acknowledged
                  ? null
                  : () => _acknowledgeAlert(ref, alert['id'], context),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Widget _buildRecoveryRulesTab(WidgetRef ref) {
    final rulesAsync = ref.watch(recoveryRulesProvider);

    return rulesAsync.when(
      data: (rules) {
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rules.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppColors.surfaceLight),
          itemBuilder: (context, index) {
            final rule = rules[index];
            final isActive = rule['is_active'] == true;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isActive
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.textMuted.withValues(alpha: 0.15),
                child: Icon(
                  Icons.rule,
                  color: isActive ? AppColors.success : AppColors.textMuted,
                  size: 20,
                ),
              ),
              title: Text(
                rule['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule['description'] ?? ''),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildRuleChip('Aksiyon: ${rule['recovery_action']}'),
                      const SizedBox(width: 8),
                      _buildRuleChip('Öncelik: ${rule['priority']}'),
                      const SizedBox(width: 8),
                      _buildRuleChip(
                        'Başarı: ${rule['success_count']}',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _buildRuleChip(
                        'Başarısız: ${rule['failure_count']}',
                        color: rule['failure_count'] > 0
                            ? AppColors.error
                            : AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Switch(
                value: isActive,
                onChanged: (value) =>
                    _toggleRule(ref, rule['id'], value, context),
                activeThumbColor: AppColors.success,
              ),
              isThreeLine: true,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Widget _buildRuleChip(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textMuted).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color ?? AppColors.textMuted, fontSize: 10),
      ),
    );
  }

  Future<void> _runHealthCheck(WidgetRef ref, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sağlık kontrolü başlatılıyor...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.functions.invoke('system-health-check');

      ref.invalidate(systemHealthProvider);
      ref.invalidate(recoveryLogsProvider);
      ref.invalidate(alertsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sağlık kontrolü tamamlandı'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _acknowledgeAlert(
    WidgetRef ref,
    String alertId,
    BuildContext context,
  ) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('alert_history')
          .update({
            'acknowledged': true,
            'acknowledged_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alertId);

      ref.invalidate(alertsProvider);
      ref.invalidate(systemHealthProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _toggleRule(
    WidgetRef ref,
    String ruleId,
    bool value,
    BuildContext context,
  ) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('auto_recovery_rules')
          .update({
            'is_active': value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ruleId);

      ref.invalidate(recoveryRulesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
