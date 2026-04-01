import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/support_monitoring_service.dart';

class TicketReviewScreen extends ConsumerStatefulWidget {
  const TicketReviewScreen({super.key});

  @override
  ConsumerState<TicketReviewScreen> createState() => _TicketReviewScreenState();
}

class _TicketReviewScreenState extends ConsumerState<TicketReviewScreen> {
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _agents = [];
  bool _loading = true;
  String? _error;
  int _totalCount = 0;
  int _page = 0;
  static const _pageSize = 20;

  // Filters
  String _statusFilter = '';
  String _priorityFilter = '';
  String _serviceFilter = '';
  String _agentFilter = '';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Detail panel
  String? _selectedTicketId;
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>>? _selectedMessages;
  List<Map<String, dynamic>>? _selectedActions;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(supportMonitoringServiceProvider);
      final results = await Future.wait([
        service.getTickets(
          status: _statusFilter,
          priority: _priorityFilter,
          serviceType: _serviceFilter,
          agentId: _agentFilter,
          search: _searchQuery,
          limit: _pageSize,
          offset: _page * _pageSize,
        ),
        service.getTicketCount(
          status: _statusFilter,
          priority: _priorityFilter,
          serviceType: _serviceFilter,
          agentId: _agentFilter,
          search: _searchQuery,
        ),
        service.getAgents(),
      ]);
      setState(() {
        _tickets = results[0] as List<Map<String, dynamic>>;
        _totalCount = results[1] as int;
        _agents = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadTicketDetail(String ticketId) async {
    setState(() {
      _selectedTicketId = ticketId;
      _loadingDetail = true;
    });
    try {
      final service = ref.read(supportMonitoringServiceProvider);
      final results = await Future.wait([
        service.getTicketMessages(ticketId),
        service.getAgentActions(ticketId: ticketId),
      ]);
      final ticket = _tickets.firstWhere(
        (t) => t['id'] == ticketId,
        orElse: () => {},
      );
      setState(() {
        _selectedTicket = ticket;
        _selectedMessages = results[0];
        _selectedActions = results[1];
        _loadingDetail = false;
      });
    } catch (e) {
      setState(() {
        _loadingDetail = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _statusFilter = '';
      _priorityFilter = '';
      _serviceFilter = '';
      _agentFilter = '';
      _searchQuery = '';
      _searchController.clear();
      _page = 0;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppColors.surface : Colors.white;
    final borderColor = isDark
        ? AppColors.surfaceLight
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? AppColors.textPrimary
        : const Color(0xFF0F172A);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);

    return Container(
      color: bgColor,
      child: Row(
        children: [
          // Ticket List
          Expanded(
            flex: _selectedTicketId != null ? 5 : 10,
            child: Column(
              children: [
                // Header + Filters
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Ticket Inceleme',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$_totalCount ticket',
                            style: TextStyle(color: textMuted, fontSize: 13),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Yenile',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filters
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Ara (isim, konu, #)',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                filled: true,
                                fillColor: cardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                isDense: true,
                              ),
                              onSubmitted: (v) {
                                setState(() {
                                  _searchQuery = v;
                                  _page = 0;
                                });
                                _loadData();
                              },
                            ),
                          ),
                          _buildDropdown(
                            cardBg,
                            borderColor,
                            'Durum',
                            _statusFilter,
                            {
                              '': 'Tumunu',
                              'open': 'Acik',
                              'assigned': 'Atanmis',
                              'in_progress': 'Islemde',
                              'waiting_customer': 'Musteri Bekleniyor',
                              'resolved': 'Cozuldu',
                              'closed': 'Kapandi',
                            },
                            (v) {
                              setState(() {
                                _statusFilter = v ?? '';
                                _page = 0;
                              });
                              _loadData();
                            },
                          ),
                          _buildDropdown(
                            cardBg,
                            borderColor,
                            'Oncelik',
                            _priorityFilter,
                            {
                              '': 'Tumunu',
                              'low': 'Dusuk',
                              'normal': 'Normal',
                              'high': 'Yuksek',
                              'urgent': 'Acil',
                            },
                            (v) {
                              setState(() {
                                _priorityFilter = v ?? '';
                                _page = 0;
                              });
                              _loadData();
                            },
                          ),
                          _buildDropdown(
                            cardBg,
                            borderColor,
                            'Servis',
                            _serviceFilter,
                            {
                              '': 'Tumunu',
                              'food': 'Yemek',
                              'taxi': 'Taksi',
                              'rental': 'Kiralama',
                              'emlak': 'Emlak',
                              'car_sales': 'Arac Satis',
                              'general': 'Genel',
                            },
                            (v) {
                              setState(() {
                                _serviceFilter = v ?? '';
                                _page = 0;
                              });
                              _loadData();
                            },
                          ),
                          if (_agents.isNotEmpty)
                            _buildDropdown(
                              cardBg,
                              borderColor,
                              'Temsilci',
                              _agentFilter,
                              {
                                '': 'Tumunu',
                                ..._agents.fold<Map<String, String>>({}, (
                                  map,
                                  a,
                                ) {
                                  map[a['id']] = a['full_name'] ?? '';
                                  return map;
                                }),
                              },
                              (v) {
                                setState(() {
                                  _agentFilter = v ?? '';
                                  _page = 0;
                                });
                                _loadData();
                              },
                            ),
                          if (_statusFilter.isNotEmpty ||
                              _priorityFilter.isNotEmpty ||
                              _serviceFilter.isNotEmpty ||
                              _agentFilter.isNotEmpty ||
                              _searchQuery.isNotEmpty)
                            TextButton.icon(
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Temizle'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Ticket Table
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: TextStyle(color: AppColors.error),
                          ),
                        )
                      : _tickets.isEmpty
                      ? Center(
                          child: Text(
                            'Ticket bulunamadi',
                            style: TextStyle(color: textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _tickets.length,
                          itemBuilder: (context, index) {
                            final ticket = _tickets[index];
                            final isSelected =
                                _selectedTicketId == ticket['id'];
                            return _buildTicketRow(
                              ticket,
                              isSelected,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textMuted,
                              isDark,
                            );
                          },
                        ),
                ),

                // Pagination
                if (_totalCount > _pageSize)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _page > 0
                              ? () {
                                  setState(() => _page--);
                                  _loadData();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${_page + 1} / ${(_totalCount / _pageSize).ceil()}',
                          style: TextStyle(color: textPrimary),
                        ),
                        IconButton(
                          onPressed: (_page + 1) * _pageSize < _totalCount
                              ? () {
                                  setState(() => _page++);
                                  _loadData();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Detail Panel
          if (_selectedTicketId != null)
            Container(width: 1, color: borderColor),
          if (_selectedTicketId != null)
            Expanded(
              flex: 5,
              child: _buildDetailPanel(
                cardBg,
                borderColor,
                textPrimary,
                textMuted,
                isDark,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    Color bg,
    Color border,
    String hint,
    String value,
    Map<String, String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          isDense: true,
          items: items.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTicketRow(
    Map<String, dynamic> ticket,
    bool isSelected,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    bool isDark,
  ) {
    final status = ticket['status']?.toString() ?? '';
    final priority = ticket['priority']?.toString() ?? '';
    final serviceType = ticket['service_type']?.toString() ?? '';
    final agentData = ticket['support_agents'];
    final agentName = agentData is Map ? agentData['full_name'] : null;
    final createdAt = DateTime.tryParse(ticket['created_at']?.toString() ?? '');
    final ticketNumber = ticket['ticket_number'];

    return Material(
      color: isSelected
          ? (isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.08))
          : Colors.transparent,
      child: InkWell(
        onTap: () => _loadTicketDetail(ticket['id']),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              // Ticket number + Service icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SupportMonitoringService.serviceColor(
                    serviceType,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  SupportMonitoringService.serviceIcon(serviceType),
                  color: SupportMonitoringService.serviceColor(serviceType),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // Main info
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$ticketNumber',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ticket['subject'] ?? '-',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket['customer_name'] ?? 'Anonim',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status
              _buildBadge(
                SupportMonitoringService.statusLabel(status),
                SupportMonitoringService.statusColor(status),
              ),
              const SizedBox(width: 8),
              // Priority
              _buildBadge(
                SupportMonitoringService.priorityLabel(priority),
                SupportMonitoringService.priorityColor(priority),
              ),
              const SizedBox(width: 12),
              // Agent
              SizedBox(
                width: 100,
                child: Text(
                  agentName ?? 'Atanmamis',
                  style: TextStyle(
                    color: agentName != null ? textPrimary : textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              // Date
              SizedBox(
                width: 80,
                child: Text(
                  createdAt != null
                      ? DateFormat('dd/MM HH:mm').format(createdAt.toLocal())
                      : '-',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ),
              // SLA warning
              if (_isSlaBreached(ticket, status))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SLA',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSlaBreached(Map<String, dynamic> ticket, String status) {
    if (ticket['sla_due_at'] == null) return false;
    if (['resolved', 'closed'].contains(status)) return false;
    final sla = DateTime.tryParse(ticket['sla_due_at'].toString());
    return sla != null && sla.isBefore(DateTime.now());
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailPanel(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    bool isDark,
  ) {
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedTicket == null) {
      return Center(
        child: Text('Ticket secin', style: TextStyle(color: textMuted)),
      );
    }

    final ticket = _selectedTicket!;
    final status = ticket['status']?.toString() ?? '';
    final priority = ticket['priority']?.toString() ?? '';
    final serviceType = ticket['service_type']?.toString() ?? '';

    return Column(
      children: [
        // Detail Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${ticket['ticket_number']}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildBadge(
                          SupportMonitoringService.statusLabel(status),
                          SupportMonitoringService.statusColor(status),
                        ),
                        const SizedBox(width: 6),
                        _buildBadge(
                          SupportMonitoringService.priorityLabel(priority),
                          SupportMonitoringService.priorityColor(priority),
                        ),
                        const SizedBox(width: 6),
                        _buildBadge(
                          SupportMonitoringService.serviceLabel(serviceType),
                          SupportMonitoringService.serviceColor(serviceType),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket['subject'] ?? '-',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Musteri: ${ticket['customer_name'] ?? 'Anonim'} | ${ticket['customer_phone'] ?? '-'}',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _selectedTicketId = null;
                  _selectedTicket = null;
                }),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _selectedMessages == null || _selectedMessages!.isEmpty
              ? Center(
                  child: Text('Mesaj yok', style: TextStyle(color: textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _selectedMessages!.length,
                  itemBuilder: (context, index) {
                    final msg = _selectedMessages![index];
                    return _buildMessageBubble(
                      msg,
                      textPrimary,
                      textMuted,
                      isDark,
                    );
                  },
                ),
        ),

        // Actions Log
        if (_selectedActions != null && _selectedActions!.isNotEmpty)
          Container(
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.background : const Color(0xFFF1F5F9),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aksiyon Logu',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    itemCount: _selectedActions!.length,
                    itemBuilder: (context, index) {
                      final action = _selectedActions![index];
                      final createdAt = DateTime.tryParse(
                        action['created_at']?.toString() ?? '',
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              createdAt != null
                                  ? DateFormat(
                                      'HH:mm',
                                    ).format(createdAt.toLocal())
                                  : '',
                              style: TextStyle(color: textMuted, fontSize: 10),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              action['agent_name'] ?? '',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                action['action_description'] ??
                                    action['action_type'] ??
                                    '',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    Color textPrimary,
    Color textMuted,
    bool isDark,
  ) {
    final senderType = msg['sender_type']?.toString() ?? '';
    final isAgent = senderType == 'agent';
    final isSystem = senderType == 'system' || senderType == 'system_action';
    final isWhisper = msg['message_type'] == 'whisper';
    final createdAt = DateTime.tryParse(msg['created_at']?.toString() ?? '');

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              msg['message'] ?? '',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isAgent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isWhisper
                ? const Color(0xFFFEF3C7)
                : isAgent
                ? AppColors.primary.withValues(alpha: 0.12)
                : (isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: isWhisper
                ? Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isWhisper
                        ? '(Fisildama) ${msg['sender_name'] ?? ''}'
                        : msg['sender_name'] ??
                              (isAgent ? 'Temsilci' : 'Musteri'),
                    style: TextStyle(
                      color: isWhisper
                          ? const Color(0xFFF59E0B)
                          : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(createdAt.toLocal()),
                      style: TextStyle(color: textMuted, fontSize: 10),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                msg['message'] ?? '',
                style: TextStyle(color: textPrimary, fontSize: 13),
              ),
              if (msg['attachment_url'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file, size: 14, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Ek dosya',
                        style: TextStyle(color: AppColors.info, fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
