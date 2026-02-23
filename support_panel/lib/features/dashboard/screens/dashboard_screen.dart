import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/ticket_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/metrics_service.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/status_badge.dart';
import '../widgets/stat_card.dart';
import '../widgets/ticket_queue_card.dart';
import '../widgets/sla_breach_card.dart';
import '../widgets/active_chats_card.dart';
import '../widgets/agent_status_card.dart';

// Dashboard-specific providers
final _ticketDistributionProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(metricsServiceProvider).getTicketsByServiceType();
});

final _weeklyTrendProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(metricsServiceProvider).getWeeklyTrend();
});

final _recentActivityProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(metricsServiceProvider).getRecentActivity(limit: 8);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(ticketStatsProvider);
    final agent = ref.watch(currentAgentProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome
          Text(
            'Hos geldin, ${agent?.fullName ?? 'Temsilci'}',
            style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Bugunku destek durumun asagida.',
            style: TextStyle(color: textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Stat cards row
          stats.when(
            data: (data) => _buildStatsRow(context, data),
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
          ),

          const SizedBox(height: 24),

          // Quick actions
          Text('Hizli Islemler', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickAction(context, Icons.add_circle_outline, 'Yeni Ticket', AppColors.primary, () => context.go(AppRoutes.tickets)),
              _buildQuickAction(context, Icons.search, 'Musteri Ara', AppColors.info, () => context.go(AppRoutes.customers)),
              _buildQuickAction(context, Icons.store, 'Isletme Ara', AppColors.warning, () => context.go(AppRoutes.businesses)),
            ],
          ),

          const SizedBox(height: 24),

          // Charts row: Pie + Line
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDistributionChart(ref, cardColor, borderColor, textPrimary, textMuted, isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildWeeklyTrendChart(ref, cardColor, borderColor, textPrimary, textMuted, isDark)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildDistributionChart(ref, cardColor, borderColor, textPrimary, textMuted, isDark),
                  const SizedBox(height: 16),
                  _buildWeeklyTrendChart(ref, cardColor, borderColor, textPrimary, textMuted, isDark),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Bottom panels: Queue + SLA + ActiveChats + AgentStatus
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildBottomColumn([
                      const TicketQueueCard(),
                      const SizedBox(height: 16),
                      const SlaBreachCard(),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(child: _buildBottomColumn([
                      const ActiveChatsCard(),
                      const SizedBox(height: 16),
                      const AgentStatusCard(),
                    ])),
                  ],
                );
              }
              return Column(
                children: const [
                  TicketQueueCard(),
                  SizedBox(height: 16),
                  SlaBreachCard(),
                  SizedBox(height: 16),
                  ActiveChatsCard(),
                  SizedBox(height: 16),
                  AgentStatusCard(),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Recent activity
          _buildRecentActivity(ref, cardColor, borderColor, textPrimary, textMuted, context),

          const SizedBox(height: 24),

          // Recent tickets
          stats.when(
            data: (data) {
              final recentTickets = data['recent_tickets'] as List<dynamic>? ?? [];
              if (recentTickets.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Son Ticketlar', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.tickets),
                        child: const Text('Tumunu Gor'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...recentTickets.take(5).map((t) => _buildRecentTicketItem(context, t, cardColor, borderColor, textPrimary, textMuted)),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomColumn(List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  // Stats row using StatCard widgets
  Widget _buildStatsRow(BuildContext context, Map<String, int> data) {
    final items = [
      _StatDef('Acik Ticketlar', '${data['open'] ?? 0}', Icons.confirmation_number_outlined, AppColors.warning),
      _StatDef('Bana Atanan', '${data['my_tickets'] ?? 0}', Icons.person_outline, AppColors.info),
      _StatDef('SLA Asimi', '${data['sla_breached'] ?? 0}', Icons.warning_amber_rounded, AppColors.error),
      _StatDef('Atanmamis', '${data['unassigned'] ?? 0}', Icons.inbox_outlined, AppColors.primary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) => SizedBox(
            width: (constraints.maxWidth - 12 * (cols - 1)) / cols,
            child: StatCard(
              label: item.label,
              value: item.value,
              icon: item.icon,
              color: item.color,
            ),
          )).toList(),
        );
      },
    );
  }

  // Pie chart: ticket distribution by service type
  Widget _buildDistributionChart(WidgetRef ref, Color cardColor, Color borderColor, Color textPrimary, Color textMuted, bool isDark) {
    final distribution = ref.watch(_ticketDistributionProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Servis Dagilimi', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          distribution.when(
            data: (data) {
              if (data.isEmpty) {
                return SizedBox(
                  height: 200,
                  child: Center(child: Text('Veri yok', style: TextStyle(color: textMuted))),
                );
              }
              return SizedBox(
                height: 220,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: PieChart(
                        PieChartData(
                          sections: _buildPieSections(data),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: data.take(6).map((item) {
                          final type = item['service_type'] as String;
                          final count = item['count'] as int;
                          final color = _serviceColor(type);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_serviceLabel(type), style: TextStyle(color: textMuted, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                Text('$count', style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => SizedBox(height: 220, child: Center(child: Text('Yuklenemedi', style: TextStyle(color: textMuted)))),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(List<Map<String, dynamic>> data) {
    final total = data.fold<int>(0, (sum, item) => sum + (item['count'] as int));
    return data.take(6).map((item) {
      final type = item['service_type'] as String;
      final count = item['count'] as int;
      final percentage = total > 0 ? (count / total * 100) : 0.0;
      return PieChartSectionData(
        color: _serviceColor(type),
        value: count.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      );
    }).toList();
  }

  // Line chart: weekly trend
  Widget _buildWeeklyTrendChart(WidgetRef ref, Color cardColor, Color borderColor, Color textPrimary, Color textMuted, bool isDark) {
    final trend = ref.watch(_weeklyTrendProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Haftalik Trend', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              _buildLegendDot(AppColors.warning, 'Olusturulan', textMuted),
              const SizedBox(width: 12),
              _buildLegendDot(AppColors.success, 'Cozulen', textMuted),
            ],
          ),
          const SizedBox(height: 20),
          trend.when(
            data: (data) {
              if (data.isEmpty) {
                return SizedBox(
                  height: 200,
                  child: Center(child: Text('Veri yok', style: TextStyle(color: textMuted))),
                );
              }
              return SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: (isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0)).withValues(alpha: 0.5),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value == value.roundToDouble()) {
                              return Text('${value.toInt()}', style: TextStyle(color: textMuted, fontSize: 10));
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < data.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(data[idx]['day_label'] ?? '', style: TextStyle(color: textMuted, fontSize: 10)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      // Created line
                      LineChartBarData(
                        spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), (data[i]['created'] as int).toDouble())),
                        isCurved: true,
                        color: AppColors.warning,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 3, color: AppColors.warning, strokeWidth: 0),
                        ),
                        belowBarData: BarAreaData(show: true, color: AppColors.warning.withValues(alpha: 0.08)),
                      ),
                      // Resolved line
                      LineChartBarData(
                        spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), (data[i]['resolved'] as int).toDouble())),
                        isCurved: true,
                        color: AppColors.success,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 3, color: AppColors.success, strokeWidth: 0),
                        ),
                        belowBarData: BarAreaData(show: true, color: AppColors.success.withValues(alpha: 0.08)),
                      ),
                    ],
                    minY: 0,
                  ),
                ),
              );
            },
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => SizedBox(height: 200, child: Center(child: Text('Yuklenemedi', style: TextStyle(color: textMuted)))),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, Color textMuted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: textMuted, fontSize: 11)),
      ],
    );
  }

  // Recent activity feed
  Widget _buildRecentActivity(WidgetRef ref, Color cardColor, Color borderColor, Color textPrimary, Color textMuted, BuildContext context) {
    final activity = ref.watch(_recentActivityProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Son Aktiviteler', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          activity.when(
            data: (items) {
              if (items.isEmpty) {
                return Text('Henuz aktivite yok', style: TextStyle(color: textMuted, fontSize: 13));
              }
              return Column(
                children: items.map((item) {
                  final icon = _actionIcon(item['action_type'] as String?);
                  final color = _actionColor(item['action_type'] as String?);
                  final time = _formatTime(item['created_at'] as String?);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: item['ticket_id'] != null ? () => context.go('${AppRoutes.tickets}/${item['ticket_id']}') : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: color, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['action_description'] ?? item['action_type'] ?? '',
                                    style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    item['agent_name'] ?? '',
                                    style: TextStyle(color: textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(time, style: TextStyle(color: textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Text('Yuklenemedi', style: TextStyle(color: textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTicketItem(BuildContext context, dynamic ticket, Color cardColor, Color borderColor, Color textPrimary, Color textMuted) {
    final t = ticket as Map<String, dynamic>;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.go('${AppRoutes.tickets}/${t['id']}'),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['subject'] ?? '', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(t['customer_name'] ?? '', style: TextStyle(color: textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge.ticketStatus(t['status'] ?? 'open'),
              const SizedBox(width: 8),
              StatusBadge.priority(t['priority'] ?? 'normal'),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers
  Color _serviceColor(String type) {
    switch (type) {
      case 'food': return const Color(0xFFEF4444);
      case 'market': return const Color(0xFFF59E0B);
      case 'store': return const Color(0xFF8B5CF6);
      case 'taxi': return const Color(0xFF3B82F6);
      case 'rental': return const Color(0xFF10B981);
      case 'emlak': return const Color(0xFF06B6D4);
      case 'car_sales': return const Color(0xFFEC4899);
      case 'general': return const Color(0xFF6B7280);
      case 'account': return const Color(0xFF14B8A6);
      default: return const Color(0xFF64748B);
    }
  }

  String _serviceLabel(String type) {
    switch (type) {
      case 'food': return 'Yemek';
      case 'market': return 'Market';
      case 'store': return 'Magaza';
      case 'taxi': return 'Taksi';
      case 'rental': return 'Kiralama';
      case 'emlak': return 'Emlak';
      case 'car_sales': return 'Arac';
      case 'general': return 'Genel';
      case 'account': return 'Hesap';
      default: return type;
    }
  }

  IconData _actionIcon(String? type) {
    switch (type) {
      case 'ticket_create': return Icons.add_circle_outline;
      case 'ticket_assign': return Icons.person_add_outlined;
      case 'ticket_status_change': return Icons.swap_horiz;
      case 'ticket_resolve': return Icons.check_circle_outline;
      case 'message_send': return Icons.chat_bubble_outline;
      case 'login': return Icons.login;
      case 'business_action': return Icons.store;
      default: return Icons.circle_outlined;
    }
  }

  Color _actionColor(String? type) {
    switch (type) {
      case 'ticket_create': return AppColors.primary;
      case 'ticket_assign': return AppColors.info;
      case 'ticket_status_change': return AppColors.warning;
      case 'ticket_resolve': return AppColors.success;
      case 'message_send': return AppColors.info;
      case 'login': return AppColors.primary;
      case 'business_action': return const Color(0xFF8B5CF6);
      default: return AppColors.textMuted;
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    final dt = DateTime.tryParse(isoTime);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'simdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}s';
    return '${diff.inDays}g';
  }
}

class _StatDef {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatDef(this.label, this.value, this.icon, this.color);
}
