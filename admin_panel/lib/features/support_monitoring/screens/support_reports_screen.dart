import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/support_monitoring_service.dart';

class SupportReportsScreen extends ConsumerStatefulWidget {
  const SupportReportsScreen({super.key});

  @override
  ConsumerState<SupportReportsScreen> createState() => _SupportReportsScreenState();
}

class _SupportReportsScreenState extends ConsumerState<SupportReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _agents;
  bool _loading = true;
  String? _error;
  String _period = '30d';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime get _startDate {
    switch (_period) {
      case '7d': return DateTime.now().subtract(const Duration(days: 7));
      case '30d': return DateTime.now().subtract(const Duration(days: 30));
      case '90d': return DateTime.now().subtract(const Duration(days: 90));
      default: return DateTime.now().subtract(const Duration(days: 30));
    }
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(supportMonitoringServiceProvider);
      final results = await Future.wait([
        service.getDashboardStats(startDate: _startDate, endDate: DateTime.now()),
        service.getAgentPerformance(startDate: _startDate, endDate: DateTime.now()),
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
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Icon(Icons.analytics_outlined, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Text('Raporlar & Analitik', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                const Spacer(),
                _buildPeriodSelector(isDark, borderColor),
                const SizedBox(width: 12),
                IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), tooltip: 'Yenile'),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceLight.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: textMuted,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Genel Rapor'),
                Tab(text: 'CSAT Raporu'),
                Tab(text: 'SLA Raporu'),
                Tab(text: 'Temsilci Raporu'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: AppColors.error)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildGeneralReport(cardBg, borderColor, textPrimary, textMuted, isDark),
                          _buildCSATReport(cardBg, borderColor, textPrimary, textMuted, isDark),
                          _buildSLAReport(cardBg, borderColor, textPrimary, textMuted, isDark),
                          _buildAgentReport(cardBg, borderColor, textPrimary, textMuted, isDark),
                        ],
                      ),
          ),
        ],
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
      onTap: () { setState(() => _period = value); _loadData(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
          color: isActive ? Colors.white : null,
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }

  // === General Report ===
  Widget _buildGeneralReport(Color cardBg, Color borderColor, Color textPrimary, Color textMuted, bool isDark) {
    final s = _stats!;
    final trend = (s['daily_ticket_trend'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Summary Cards
        Row(
          children: [
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Toplam Ticket', '${s['total_tickets_period'] ?? 0}', AppColors.info),
            const SizedBox(width: 16),
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Cozulen', '${s['resolved_period'] ?? 0}', AppColors.success),
            const SizedBox(width: 16),
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Acik', '${s['open_tickets'] ?? 0}', AppColors.warning),
            const SizedBox(width: 16),
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Ort. Cozum',
                SupportMonitoringService.formatDuration(s['avg_resolution_seconds'] ?? 0), const Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: 24),

        // Trend Chart
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gunluk Ticket Trendi', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: trend.isEmpty
                    ? Center(child: Text('Veri yok', style: TextStyle(color: textMuted)))
                    : BarChart(
                        BarChartData(
                          barGroups: trend.asMap().entries.map((e) {
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: (e.value['created'] ?? 0).toDouble(),
                                  color: AppColors.primary,
                                  width: 8,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                                BarChartRodData(
                                  toY: (e.value['resolved'] ?? 0).toDouble(),
                                  color: AppColors.success,
                                  width: 8,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            );
                          }).toList(),
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
                                  try {
                                    final date = DateTime.parse(trend[idx]['date'].toString());
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(DateFormat('dd/MM').format(date), style: TextStyle(color: textMuted, fontSize: 10)),
                                    );
                                  } catch (_) { return const SizedBox.shrink(); }
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
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(color: borderColor.withValues(alpha: 0.5), strokeWidth: 1),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(AppColors.primary, 'Olusturulan'),
                  const SizedBox(width: 20),
                  _legendDot(AppColors.success, 'Cozulen'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Service & Priority Distribution
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDistributionTable(cardBg, borderColor, textPrimary, textMuted,
                'Servis Dagilimi', (s['tickets_by_service'] as List?) ?? [],
                'service_type', SupportMonitoringService.serviceLabel, SupportMonitoringService.serviceColor)),
            const SizedBox(width: 24),
            Expanded(child: _buildDistributionTable(cardBg, borderColor, textPrimary, textMuted,
                'Oncelik Dagilimi', (s['tickets_by_priority'] as List?) ?? [],
                'priority', SupportMonitoringService.priorityLabel, SupportMonitoringService.priorityColor)),
          ],
        ),
      ],
    );
  }

  // === CSAT Report ===
  Widget _buildCSATReport(Color cardBg, Color borderColor, Color textPrimary, Color textMuted, bool isDark) {
    final s = _stats!;
    final csatAvg = s['csat_average'] ?? 0;
    final csatCount = s['csat_count'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // CSAT Summary
        Row(
          children: [
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Ortalama CSAT', '$csatAvg/5',
                _csatColor(csatAvg) ?? AppColors.textMuted),
            const SizedBox(width: 16),
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Degerlendirme', '$csatCount', AppColors.info),
          ],
        ),
        const SizedBox(height: 24),

        // Agent CSAT Comparison
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Temsilci Bazli CSAT', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (_agents == null || _agents!.isEmpty)
                Text('Veri yok', style: TextStyle(color: textMuted))
              else
                ..._agents!.map((agent) {
                  final csat = agent['csat_average'] ?? 0;
                  final csatVal = csat is num ? csat.toDouble() : double.tryParse(csat.toString()) ?? 0;
                  final count = agent['csat_count'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 150, child: Text(agent['full_name'] ?? '', style: TextStyle(color: textPrimary, fontSize: 13))),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: borderColor.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: (csatVal / 5).clamp(0, 1),
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: (_csatColor(csat) ?? AppColors.textMuted).withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('$csat', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(width: 60, child: Text('$count oy', style: TextStyle(color: textMuted, fontSize: 11))),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // === SLA Report ===
  Widget _buildSLAReport(Color cardBg, Color borderColor, Color textPrimary, Color textMuted, bool isDark) {
    final s = _stats!;
    final slaBreaches = s['sla_breaches'] ?? 0;
    final totalTickets = s['total_tickets_all'] ?? 0;
    final complianceRate = totalTickets > 0 ? ((totalTickets - slaBreaches) / totalTickets * 100).toStringAsFixed(1) : '100.0';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // SLA Summary
        Row(
          children: [
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'SLA Uyum', '$complianceRate%',
                double.parse(complianceRate) >= 95 ? AppColors.success : AppColors.error),
            const SizedBox(width: 16),
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Aktif Ihlal', '$slaBreaches', AppColors.error),
            const SizedBox(width: 16),
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Ort. Ilk Yanit',
                SupportMonitoringService.formatDuration(s['avg_first_response_seconds'] ?? 0), AppColors.warning),
            const SizedBox(width: 16),
            _reportCard(cardBg, borderColor, textPrimary, textMuted, 'Ort. Cozum',
                SupportMonitoringService.formatDuration(s['avg_resolution_seconds'] ?? 0), const Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: 24),

        // Agent SLA Performance
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Temsilci Bazli SLA', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (_agents == null || _agents!.isEmpty)
                Text('Veri yok', style: TextStyle(color: textMuted))
              else
                ..._agents!.map((agent) {
                  final handled = agent['tickets_handled'] ?? 0;
                  final breaches = agent['sla_breaches'] ?? 0;
                  final rate = handled > 0 ? ((handled - breaches) / handled * 100).toStringAsFixed(1) : '100.0';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 150, child: Text(agent['full_name'] ?? '', style: TextStyle(color: textPrimary, fontSize: 13))),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: borderColor.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: (double.parse(rate) / 100).clamp(0, 1),
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: double.parse(rate) >= 95 ? AppColors.success.withValues(alpha: 0.7) : AppColors.error.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('$rate%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(width: 80, child: Text('$breaches ihlal', style: TextStyle(
                            color: breaches > 0 ? AppColors.error : textMuted, fontSize: 11, fontWeight: breaches > 0 ? FontWeight.w600 : FontWeight.w400))),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // === Agent Report ===
  Widget _buildAgentReport(Color cardBg, Color borderColor, Color textPrimary, Color textMuted, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceLight.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    _th('Temsilci', 3, textMuted),
                    _th('Ticket', 1, textMuted),
                    _th('Cozulen', 1, textMuted),
                    _th('Cozum %', 1, textMuted),
                    _th('Ort. Yanit', 1, textMuted),
                    _th('Ort. Cozum', 1, textMuted),
                    _th('Mesaj', 1, textMuted),
                    _th('CSAT', 1, textMuted),
                    _th('SLA Ihlal', 1, textMuted),
                  ],
                ),
              ),
              if (_agents == null || _agents!.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Veri yok', style: TextStyle(color: textMuted)),
                )
              else
                ..._agents!.map((agent) {
                  final handled = agent['tickets_handled'] ?? 0;
                  final resolved = agent['tickets_resolved'] ?? 0;
                  final resRate = handled > 0 ? (resolved / handled * 100).toStringAsFixed(0) : '-';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(agent['full_name'] ?? '', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
                        _td('$handled', 1, textPrimary),
                        _td('$resolved', 1, textPrimary, color: resolved > 0 ? AppColors.success : null),
                        _td('$resRate%', 1, textPrimary),
                        _td(SupportMonitoringService.formatDuration(agent['avg_first_response_seconds'] ?? 0), 1, textPrimary),
                        _td(SupportMonitoringService.formatDuration(agent['avg_resolution_seconds'] ?? 0), 1, textPrimary),
                        _td('${agent['messages_sent'] ?? 0}', 1, textPrimary),
                        _td('${agent['csat_average'] ?? 0}', 1, textPrimary, color: _csatColor(agent['csat_average'])),
                        _td('${agent['sla_breaches'] ?? 0}', 1, textPrimary,
                            color: (agent['sla_breaches'] ?? 0) > 0 ? AppColors.error : null),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helpers ---

  Widget _reportCard(Color cardBg, Color borderColor, Color textPrimary, Color textMuted,
      String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionTable(Color cardBg, Color borderColor, Color textPrimary, Color textMuted,
      String title, List data, String keyField, String Function(String) labelFn, Color Function(String) colorFn) {
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
          Text(title, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (data.isEmpty)
            Text('Veri yok', style: TextStyle(color: textMuted))
          else
            ...data.map((d) {
              final key = d[keyField]?.toString() ?? '';
              final count = (d['count'] ?? 0) as int;
              final total = data.fold<int>(0, (sum, item) => sum + ((item['count'] ?? 0) as int));
              final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colorFn(key), borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(labelFn(key), style: TextStyle(color: textPrimary, fontSize: 13))),
                    Text('$count', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    SizedBox(width: 50, child: Text('$pct%', style: TextStyle(color: textMuted, fontSize: 12), textAlign: TextAlign.right)),
                  ],
                ),
              );
            }),
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

  Widget _th(String label, int flex, Color color) {
    return Expanded(flex: flex, child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)));
  }

  Widget _td(String value, int flex, Color textPrimary, {Color? color}) {
    return Expanded(flex: flex, child: Text(value, style: TextStyle(
        color: color ?? textPrimary, fontSize: 13, fontWeight: color != null ? FontWeight.w600 : FontWeight.w400)));
  }

  Color? _csatColor(dynamic csat) {
    if (csat == null || csat == 0) return null;
    final val = csat is num ? csat.toDouble() : double.tryParse(csat.toString()) ?? 0;
    if (val >= 4.0) return AppColors.success;
    if (val >= 3.0) return AppColors.warning;
    return AppColors.error;
  }
}
