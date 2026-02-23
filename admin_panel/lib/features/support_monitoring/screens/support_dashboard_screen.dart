import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/support_monitoring_service.dart';

class SupportDashboardScreen extends ConsumerStatefulWidget {
  const SupportDashboardScreen({super.key});

  @override
  ConsumerState<SupportDashboardScreen> createState() => _SupportDashboardScreenState();
}

class _SupportDashboardScreenState extends ConsumerState<SupportDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _agents;
  bool _loading = true;
  String? _error;
  String _period = '7d'; // 1d, 7d, 30d, 90d

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime get _startDate {
    switch (_period) {
      case '1d': return DateTime.now().subtract(const Duration(days: 1));
      case '7d': return DateTime.now().subtract(const Duration(days: 7));
      case '30d': return DateTime.now().subtract(const Duration(days: 30));
      case '90d': return DateTime.now().subtract(const Duration(days: 90));
      default: return DateTime.now().subtract(const Duration(days: 7));
    }
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(supportMonitoringServiceProvider);
      final results = await Future.wait([
        service.getDashboardStats(startDate: _startDate, endDate: DateTime.now()),
        service.getAgents(),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _agents = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppColors.surface : Colors.white;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);

    return Container(
      color: bgColor,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: textMuted)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadData, child: const Text('Tekrar Dene')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(Icons.dashboard_rounded, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Text('Destek Dashboard', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          _buildPeriodSelector(isDark, borderColor),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Yenile',
                            style: IconButton.styleFrom(
                              backgroundColor: cardBg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // KPI Cards
                      _buildKPICards(cardBg, borderColor, textPrimary, textMuted),
                      const SizedBox(height: 24),

                      // Charts Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildTrendChart(cardBg, borderColor, textPrimary, textMuted)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildServiceChart(cardBg, borderColor, textPrimary, textMuted)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Bottom Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: _buildStatusChart(cardBg, borderColor, textPrimary, textMuted)),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: _buildPriorityChart(cardBg, borderColor, textPrimary, textMuted)),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: _buildActiveAgents(cardBg, borderColor, textPrimary, textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPeriodSelector(bool isDark, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _periodChip('1G', '1d'),
          _periodChip('7G', '7d'),
          _periodChip('30G', '30d'),
          _periodChip('90G', '90d'),
        ],
      ),
    );
  }

  Widget _periodChip(String label, String value) {
    final isActive = _period == value;
    return GestureDetector(
      onTap: () {
        setState(() => _period = value);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : null,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildKPICards(Color cardBg, Color borderColor, Color textPrimary, Color textMuted) {
    final s = _stats!;
    final openTickets = (s['open_tickets'] ?? 0) as int;
    final resolvedToday = (s['resolved_today'] ?? 0) as int;
    final avgFirstResponse = (s['avg_first_response_seconds'] ?? 0) as int;
    final avgResolution = (s['avg_resolution_seconds'] ?? 0) as int;
    final slaBreaches = (s['sla_breaches'] ?? 0) as int;
    final csatAvg = (s['csat_average'] ?? 0);
    final activeAgents = (s['active_agents'] ?? 0) as int;
    final totalAgents = (s['total_agents'] ?? 0) as int;
    final unassigned = (s['unassigned_tickets'] ?? 0) as int;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _kpiCard(cardBg, borderColor, textPrimary, textMuted,
            icon: Icons.confirmation_number_outlined, color: AppColors.info,
            title: 'Acik Ticket', value: '$openTickets', subtitle: '$unassigned atanmamis'),
        _kpiCard(cardBg, borderColor, textPrimary, textMuted,
            icon: Icons.check_circle_outline, color: AppColors.success,
            title: 'Bugun Cozulen', value: '$resolvedToday', subtitle: '${s['resolved_period'] ?? 0} donemde'),
        _kpiCard(cardBg, borderColor, textPrimary, textMuted,
            icon: Icons.timer_outlined, color: AppColors.warning,
            title: 'Ort. Ilk Yanit', value: SupportMonitoringService.formatDuration(avgFirstResponse), subtitle: 'ilk yanit suresi'),
        _kpiCard(cardBg, borderColor, textPrimary, textMuted,
            icon: Icons.schedule_outlined, color: const Color(0xFF8B5CF6),
            title: 'Ort. Cozum', value: SupportMonitoringService.formatDuration(avgResolution), subtitle: 'cozum suresi'),
        _kpiCard(cardBg, borderColor, textPrimary, textMuted,
            icon: Icons.warning_amber_outlined, color: AppColors.error,
            title: 'SLA Ihlal', value: '$slaBreaches', subtitle: 'aktif ihlal'),
        _kpiCard(cardBg, borderColor, textPrimary, textMuted,
            icon: Icons.star_outline, color: const Color(0xFFF59E0B),
            title: 'CSAT', value: '$csatAvg/5', subtitle: '${s['csat_count'] ?? 0} degerlendirme'),
        _kpiCard(cardBg, borderColor, textPrimary, textMuted,
            icon: Icons.headset_mic_outlined, color: AppColors.primary,
            title: 'Aktif Temsilci', value: '$activeAgents/$totalAgents', subtitle: 'online'),
        _kpiCard(cardBg, borderColor, textPrimary, textMuted,
            icon: Icons.inventory_2_outlined, color: const Color(0xFFF97316),
            title: 'Toplam Ticket', value: '${s['total_tickets_all'] ?? 0}', subtitle: '${s['total_tickets_period'] ?? 0} donemde'),
      ],
    );
  }

  Widget _kpiCard(Color cardBg, Color borderColor, Color textPrimary, Color textMuted, {
    required IconData icon, required Color color, required String title, required String value, required String subtitle,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(subtitle, style: TextStyle(color: textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTrendChart(Color cardBg, Color borderColor, Color textPrimary, Color textMuted) {
    final trend = (_stats!['daily_ticket_trend'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ticket Trendi', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          Text('Olusturulan vs Cozulen', style: TextStyle(color: textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(AppColors.primary, 'Olusturulan'),
              const SizedBox(width: 16),
              _legendDot(AppColors.success, 'Cozulen'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: trend.isEmpty
                ? Center(child: Text('Veri yok', style: TextStyle(color: textMuted)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: borderColor.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (trend.length / 7).ceilToDouble().clamp(1, double.infinity),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                              final dateStr = trend[idx]['date']?.toString() ?? '';
                              if (dateStr.isEmpty) return const SizedBox.shrink();
                              try {
                                final date = DateTime.parse(dateStr);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(DateFormat('dd/MM').format(date), style: TextStyle(color: textMuted, fontSize: 10)),
                                );
                              } catch (_) {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
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
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: trend.asMap().entries.map((e) =>
                              FlSpot(e.key.toDouble(), (e.value['created'] ?? 0).toDouble())).toList(),
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 2.5,
                          dotData: FlDotData(show: trend.length < 15),
                          belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.08)),
                        ),
                        LineChartBarData(
                          spots: trend.asMap().entries.map((e) =>
                              FlSpot(e.key.toDouble(), (e.value['resolved'] ?? 0).toDouble())).toList(),
                          isCurved: true,
                          color: AppColors.success,
                          barWidth: 2.5,
                          dotData: FlDotData(show: trend.length < 15),
                          belowBarData: BarAreaData(show: true, color: AppColors.success.withValues(alpha: 0.08)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildServiceChart(Color cardBg, Color borderColor, Color textPrimary, Color textMuted) {
    final data = (_stats!['tickets_by_service'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Servis Dagilimi', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          Text('Ticket sayisina gore', style: TextStyle(color: textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: data.isEmpty
                ? Center(child: Text('Veri yok', style: TextStyle(color: textMuted)))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: data.map((d) {
                        final type = d['service_type']?.toString() ?? 'other';
                        final count = (d['count'] ?? 0) as int;
                        final color = SupportMonitoringService.serviceColor(type);
                        return PieChartSectionData(
                          value: count.toDouble(),
                          color: color,
                          radius: 50,
                          title: '$count',
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          ...data.map((d) {
            final type = d['service_type']?.toString() ?? 'other';
            final count = d['count'] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(
                    color: SupportMonitoringService.serviceColor(type),
                    borderRadius: BorderRadius.circular(3),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: Text(SupportMonitoringService.serviceLabel(type), style: const TextStyle(fontSize: 12))),
                  Text('$count', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusChart(Color cardBg, Color borderColor, Color textPrimary, Color textMuted) {
    final data = (_stats!['tickets_by_status'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Durum Dagilimi', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...data.map((d) {
            final status = d['status']?.toString() ?? '';
            final count = (d['count'] ?? 0) as int;
            final color = SupportMonitoringService.statusColor(status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(SupportMonitoringService.statusLabel(status), style: const TextStyle(fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }),
          if (data.isEmpty) Text('Veri yok', style: TextStyle(color: textMuted)),
        ],
      ),
    );
  }

  Widget _buildPriorityChart(Color cardBg, Color borderColor, Color textPrimary, Color textMuted) {
    final data = (_stats!['tickets_by_priority'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Oncelik Dagilimi', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...data.map((d) {
            final priority = d['priority']?.toString() ?? '';
            final count = (d['count'] ?? 0) as int;
            final color = SupportMonitoringService.priorityColor(priority);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(SupportMonitoringService.priorityLabel(priority), style: const TextStyle(fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }),
          if (data.isEmpty) Text('Veri yok', style: TextStyle(color: textMuted)),
        ],
      ),
    );
  }

  Widget _buildActiveAgents(Color cardBg, Color borderColor, Color textPrimary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Temsilciler', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (_agents == null || _agents!.isEmpty)
            Text('Temsilci yok', style: TextStyle(color: textMuted))
          else
            ..._agents!.map((agent) {
              final status = agent['status']?.toString() ?? 'offline';
              final statusColor = status == 'online' ? AppColors.success
                  : status == 'busy' ? AppColors.warning
                  : status == 'break' ? const Color(0xFFF97316)
                  : AppColors.textMuted;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(agent['full_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(
                            '${agent['active_chat_count'] ?? 0}/${agent['max_concurrent_chats'] ?? 0} chat',
                            style: TextStyle(color: textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'online' ? 'Online' : status == 'busy' ? 'Mesgul' : status == 'break' ? 'Mola' : 'Offline',
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
