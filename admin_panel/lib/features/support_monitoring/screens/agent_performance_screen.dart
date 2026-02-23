import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/support_monitoring_service.dart';

class AgentPerformanceScreen extends ConsumerStatefulWidget {
  const AgentPerformanceScreen({super.key});

  @override
  ConsumerState<AgentPerformanceScreen> createState() => _AgentPerformanceScreenState();
}

class _AgentPerformanceScreenState extends ConsumerState<AgentPerformanceScreen> {
  List<Map<String, dynamic>> _agents = [];
  bool _loading = true;
  String? _error;
  String _period = '30d';
  String? _selectedAgentId;
  Map<String, dynamic>? _selectedAgent;
  List<Map<String, dynamic>>? _agentActions;
  List<Map<String, dynamic>>? _agentTickets;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final agents = await service.getAgentPerformance(startDate: _startDate, endDate: DateTime.now());
      setState(() { _agents = agents; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadAgentDetail(String agentId) async {
    setState(() { _selectedAgentId = agentId; _loadingDetail = true; });
    try {
      final service = ref.read(supportMonitoringServiceProvider);
      final agent = _agents.firstWhere((a) => a['agent_id'] == agentId, orElse: () => {});
      final results = await Future.wait([
        service.getAgentActions(agentId: agentId, limit: 30),
        service.getTickets(agentId: agentId, limit: 10),
      ]);
      setState(() {
        _selectedAgent = agent;
        _agentActions = results[0] as List<Map<String, dynamic>>;
        _agentTickets = results[1] as List<Map<String, dynamic>>;
        _loadingDetail = false;
      });
    } catch (e) {
      setState(() { _loadingDetail = false; });
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
      child: Row(
        children: [
          // Agent List
          Expanded(
            flex: _selectedAgentId != null ? 6 : 10,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Text('Temsilci Performans', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      _buildPeriodSelector(isDark, borderColor),
                      const SizedBox(width: 12),
                      IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), tooltip: 'Yenile'),
                    ],
                  ),
                ),

                // Agent Table
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!, style: TextStyle(color: AppColors.error)))
                          : _agents.isEmpty
                              ? Center(child: Text('Temsilci bulunamadi', style: TextStyle(color: textMuted)))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: _buildAgentTable(cardBg, borderColor, textPrimary, textMuted, isDark),
                                ),
                ),
              ],
            ),
          ),

          // Detail Panel
          if (_selectedAgentId != null) ...[
            Container(width: 1, color: borderColor),
            Expanded(
              flex: 4,
              child: _buildDetailPanel(cardBg, borderColor, textPrimary, textMuted, isDark),
            ),
          ],
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

  Widget _buildAgentTable(Color cardBg, Color borderColor, Color textPrimary, Color textMuted, bool isDark) {
    return Container(
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
                _tableHeader('Temsilci', flex: 3, textMuted: textMuted),
                _tableHeader('Durum', flex: 1, textMuted: textMuted),
                _tableHeader('Ticket', flex: 1, textMuted: textMuted),
                _tableHeader('Cozulen', flex: 1, textMuted: textMuted),
                _tableHeader('Ort. Yanit', flex: 1, textMuted: textMuted),
                _tableHeader('Ort. Cozum', flex: 1, textMuted: textMuted),
                _tableHeader('CSAT', flex: 1, textMuted: textMuted),
                _tableHeader('SLA', flex: 1, textMuted: textMuted),
                _tableHeader('Mesaj', flex: 1, textMuted: textMuted),
              ],
            ),
          ),
          // Table Rows
          ..._agents.asMap().entries.map((entry) {
            final agent = entry.value;
            final isSelected = _selectedAgentId == agent['agent_id'];
            return Material(
              color: isSelected
                  ? (isDark ? AppColors.primary.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.06))
                  : Colors.transparent,
              child: InkWell(
                onTap: () => _loadAgentDetail(agent['agent_id']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      // Agent info
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                (agent['full_name']?.toString() ?? 'A').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(agent['full_name'] ?? '', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text(agent['permission_level'] ?? '', style: TextStyle(color: textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status
                      Expanded(
                        flex: 1,
                        child: _buildStatusBadge(agent['status']?.toString() ?? 'offline'),
                      ),
                      // Tickets handled
                      _tableCell('${agent['tickets_handled'] ?? 0}', flex: 1, textPrimary: textPrimary),
                      // Tickets resolved
                      _tableCell('${agent['tickets_resolved'] ?? 0}', flex: 1, textPrimary: textPrimary,
                          color: (agent['tickets_resolved'] ?? 0) > 0 ? AppColors.success : null),
                      // Avg first response
                      _tableCell(SupportMonitoringService.formatDuration(agent['avg_first_response_seconds'] ?? 0),
                          flex: 1, textPrimary: textPrimary),
                      // Avg resolution
                      _tableCell(SupportMonitoringService.formatDuration(agent['avg_resolution_seconds'] ?? 0),
                          flex: 1, textPrimary: textPrimary),
                      // CSAT
                      _tableCell('${agent['csat_average'] ?? 0}', flex: 1, textPrimary: textPrimary,
                          color: _csatColor(agent['csat_average'])),
                      // SLA breaches
                      _tableCell('${agent['sla_breaches'] ?? 0}', flex: 1, textPrimary: textPrimary,
                          color: (agent['sla_breaches'] ?? 0) > 0 ? AppColors.error : null),
                      // Messages
                      _tableCell('${agent['messages_sent'] ?? 0}', flex: 1, textPrimary: textPrimary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _tableHeader(String label, {required int flex, required Color textMuted}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _tableCell(String value, {required int flex, required Color textPrimary, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(value, style: TextStyle(color: color ?? textPrimary, fontSize: 13, fontWeight: color != null ? FontWeight.w600 : FontWeight.w400)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'online' ? AppColors.success
        : status == 'busy' ? AppColors.warning
        : status == 'break' ? const Color(0xFFF97316)
        : AppColors.textMuted;
    final label = status == 'online' ? 'Online'
        : status == 'busy' ? 'Mesgul'
        : status == 'break' ? 'Mola'
        : 'Offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Color? _csatColor(dynamic csat) {
    if (csat == null || csat == 0) return null;
    final val = csat is num ? csat.toDouble() : double.tryParse(csat.toString()) ?? 0;
    if (val >= 4.0) return AppColors.success;
    if (val >= 3.0) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildDetailPanel(Color cardBg, Color borderColor, Color textPrimary, Color textMuted, bool isDark) {
    if (_loadingDetail) return const Center(child: CircularProgressIndicator());
    if (_selectedAgent == null) return Center(child: Text('Temsilci secin', style: TextStyle(color: textMuted)));

    final agent = _selectedAgent!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Agent Header
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                (agent['full_name']?.toString() ?? 'A').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agent['full_name'] ?? '', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${agent['email'] ?? ''} | ${agent['permission_level'] ?? ''}',
                      style: TextStyle(color: textMuted, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() { _selectedAgentId = null; _selectedAgent = null; }),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Performance Summary Cards
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _miniCard(cardBg, borderColor, textPrimary, textMuted,
                'Ticket', '${agent['tickets_handled'] ?? 0}', Icons.confirmation_number_outlined, AppColors.info),
            _miniCard(cardBg, borderColor, textPrimary, textMuted,
                'Cozulen', '${agent['tickets_resolved'] ?? 0}', Icons.check_circle_outline, AppColors.success),
            _miniCard(cardBg, borderColor, textPrimary, textMuted,
                'CSAT', '${agent['csat_average'] ?? 0}/5', Icons.star_outline, const Color(0xFFF59E0B)),
            _miniCard(cardBg, borderColor, textPrimary, textMuted,
                'SLA Ihlal', '${agent['sla_breaches'] ?? 0}', Icons.warning_amber_outlined, AppColors.error),
            _miniCard(cardBg, borderColor, textPrimary, textMuted,
                'Ort. Yanit', SupportMonitoringService.formatDuration(agent['avg_first_response_seconds'] ?? 0),
                Icons.timer_outlined, AppColors.warning),
            _miniCard(cardBg, borderColor, textPrimary, textMuted,
                'Mesaj', '${agent['messages_sent'] ?? 0}', Icons.message_outlined, AppColors.primary),
          ],
        ),
        const SizedBox(height: 24),

        // Recent Tickets
        Text('Son Ticketlar', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_agentTickets == null || _agentTickets!.isEmpty)
          Text('Ticket yok', style: TextStyle(color: textMuted, fontSize: 12))
        else
          ..._agentTickets!.map((ticket) {
            final status = ticket['status']?.toString() ?? '';
            final createdAt = DateTime.tryParse(ticket['created_at']?.toString() ?? '');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceLight.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Text('#${ticket['ticket_number'] ?? ''}', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ticket['subject'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  _buildBadge(SupportMonitoringService.statusLabel(status), SupportMonitoringService.statusColor(status)),
                  const SizedBox(width: 8),
                  Text(createdAt != null ? DateFormat('dd/MM').format(createdAt.toLocal()) : '', style: TextStyle(color: textMuted, fontSize: 11)),
                ],
              ),
            );
          }),
        const SizedBox(height: 24),

        // Actions Log
        Text('Son Aksiyonlar', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_agentActions == null || _agentActions!.isEmpty)
          Text('Aksiyon yok', style: TextStyle(color: textMuted, fontSize: 12))
        else
          ..._agentActions!.take(20).map((action) {
            final createdAt = DateTime.tryParse(action['created_at']?.toString() ?? '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      createdAt != null ? DateFormat('dd/MM HH:mm').format(createdAt.toLocal()) : '',
                      style: TextStyle(color: textMuted, fontSize: 10),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(action['action_type'] ?? '', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(action['action_description'] ?? '', style: TextStyle(color: textPrimary, fontSize: 11),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _miniCard(Color cardBg, Color borderColor, Color textPrimary, Color textMuted,
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
