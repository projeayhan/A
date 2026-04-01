import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/ticket_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/audit_service.dart';
import 'package:support_panel/core/services/log_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/status_badge.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _messageCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final FocusNode _messageFocus = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _sendMessage();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  bool _isWhisper = false;
  String? _error;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _loadTicket();
    _subscribeMessages();
  }

  void _subscribeMessages() {
    final supabase = SupabaseService.client;
    _messagesChannel = supabase.channel('ticket_detail_msgs_${widget.ticketId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ticket_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: widget.ticketId,
          ),
          callback: (_) => _refreshMessages(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _messageCtrl.dispose();
    _noteCtrl.dispose();
    _scrollCtrl.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.client;
      final ticket = await client
          .from('support_tickets')
          .select('*, assigned_agent:support_agents!support_tickets_assigned_agent_id_fkey(id, full_name)')
          .eq('id', widget.ticketId)
          .single();

      final messages = await client
          .from('ticket_messages')
          .select('*')
          .eq('ticket_id', widget.ticketId)
          .order('created_at');

      final notes = await client
          .from('internal_notes')
          .select('*, agent:support_agents!internal_notes_agent_id_fkey(full_name)')
          .eq('target_type', 'ticket')
          .eq('target_id', widget.ticketId)
          .order('created_at', ascending: false);

      setState(() {
        _ticket = ticket;
        _messages = List<Map<String, dynamic>>.from(messages);
        _notes = List<Map<String, dynamic>>.from(notes);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e, st) {
      LogService.error('Failed to load ticket detail', error: e, stackTrace: st, source: 'TicketDetailScreen:_loadTicket');
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _refreshMessages() async {
    try {
      final client = SupabaseService.client;
      final messages = await client
          .from('ticket_messages')
          .select('*')
          .eq('ticket_id', widget.ticketId)
          .order('created_at');
      if (mounted) {
        setState(() => _messages = List<Map<String, dynamic>>.from(messages));
        _scrollToBottom();
      }
    } catch (e, st) {
      LogService.error('Error refreshing messages', error: e, stackTrace: st, source: 'TicketDetailScreen:_refreshMessages');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final df = DateFormat('dd.MM.yyyy HH:mm');

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Hata: $_error', style: TextStyle(color: AppColors.error)));
    if (_ticket == null) return Center(child: Text('Ticket bulunamadı', style: TextStyle(color: textMuted)));

    final t = _ticket!;
    final agent = ref.watch(currentAgentProvider).value;

    return Row(
      children: [
        // Left: Messages
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Ticket header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () => context.go(AppRoutes.tickets),
                      tooltip: 'Geri',
                    ),
                    const SizedBox(width: 8),
                    Text('#${t['ticket_number']}', style: TextStyle(color: textMuted, fontSize: 13)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t['subject'] ?? '', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    StatusBadge.ticketStatus(t['status'] ?? 'open'),
                    const SizedBox(width: 8),
                    StatusBadge.priority(t['priority'] ?? 'normal'),
                    const SizedBox(width: 8),
                    StatusBadge.serviceType(t['service_type'] ?? 'general'),
                  ],
                ),
              ),

              // Messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg, textPrimary, textMuted, cardColor, borderColor, isDark, df);
                  },
                ),
              ),

              // Message input
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    // Whisper toggle
                    Tooltip(
                      message: _isWhisper ? 'Fısıltı (sadece temsilciler görür)' : 'Normal mesaj',
                      child: IconButton(
                        icon: Icon(_isWhisper ? Icons.visibility_off : Icons.visibility, color: _isWhisper ? AppColors.warning : textMuted, size: 20),
                        onPressed: () => setState(() => _isWhisper = !_isWhisper),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageCtrl,
                        focusNode: _messageFocus,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: _isWhisper ? 'Fısıltı mesajı (sadece temsilciler)...' : 'Mesaj yazın... (/ ile hazır yanıt)',
                          hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.primary),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Right sidebar: Ticket info + actions
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(left: BorderSide(color: borderColor)),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Ticket info
              _buildSidebarSection('Ticket Bilgileri', textPrimary),
              const SizedBox(height: 8),
              _buildInfoRow('Müşteri', t['customer_name'] ?? t['customer_phone'] ?? '-', textPrimary, textMuted),
              if (t['customer_phone'] != null)
                _buildInfoRow('Telefon', t['customer_phone'], textPrimary, textMuted),
              _buildInfoRow('Oluşturulma', t['created_at'] != null ? df.format(DateTime.parse(t['created_at']).toLocal()) : '-', textPrimary, textMuted),
              if (t['sla_due_at'] != null)
                _buildInfoRow('SLA Bitiş', df.format(DateTime.parse(t['sla_due_at']).toLocal()), textPrimary, textMuted,
                  valueColor: DateTime.parse(t['sla_due_at']).isBefore(DateTime.now()) ? AppColors.error : null),
              if (t['assigned_agent'] != null)
                _buildInfoRow('Atanan', t['assigned_agent']['full_name'] ?? '-', textPrimary, textMuted),
              if (t['description'] != null && (t['description'] as String).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Açıklama:', style: TextStyle(color: textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Text(t['description'], style: TextStyle(color: textPrimary, fontSize: 12)),
              ],

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Actions
              _buildSidebarSection('İşlemler', textPrimary),
              const SizedBox(height: 8),

              // Assign to me
              if (t['assigned_agent_id'] != agent?.id)
                _buildActionButton('Bana Ata', Icons.person_add, AppColors.primary, () => _assignToMe()),

              // Status changes
              if (t['status'] != 'resolved' && t['status'] != 'closed') ...[
                _buildActionButton('Beklemede', Icons.hourglass_empty, AppColors.warning, () => _updateStatus('pending')),
                _buildActionButton('Müşteri Bekleniyor', Icons.schedule, const Color(0xFF8B5CF6), () => _updateStatus('waiting_customer')),
                _buildActionButton('Çözüldü', Icons.check_circle, AppColors.success, () => _updateStatus('resolved')),
              ],
              if (t['status'] == 'resolved')
                _buildActionButton('Kapat', Icons.close, AppColors.textMuted, () => _updateStatus('closed')),

              // Priority changes
              const SizedBox(height: 12),
              _buildSidebarSection('Öncelik Değiştir', textPrimary),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPriorityChip('low', 'Düşük', t['priority']),
                  _buildPriorityChip('normal', 'Normal', t['priority']),
                  _buildPriorityChip('high', 'Yüksek', t['priority']),
                  _buildPriorityChip('urgent', 'Acil', t['priority']),
                ],
              ),

              // Customer link
              if (t['customer_id'] != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildActionButton('Müşteri 360°', Icons.person_search, AppColors.info, () {
                  context.go('${AppRoutes.customers}/${t['customer_id']}');
                }),
              ],

              // Internal notes
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildSidebarSection('İç Notlar', textPrimary),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Not ekle...',
                  hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  contentPadding: const EdgeInsets.all(10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: _addNote,
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              ..._notes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(n['agent']?['full_name'] ?? '-', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(n['created_at'] != null ? df.format(DateTime.parse(n['created_at']).toLocal()) : '', style: TextStyle(color: textMuted, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(n['note'] ?? '', style: TextStyle(color: textPrimary, fontSize: 12)),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, Color textPrimary, Color textMuted, Color cardColor, Color borderColor, bool isDark, DateFormat df) {
    final senderType = msg['sender_type'] ?? 'system';
    final isAgent = senderType == 'agent';
    final isWhisper = senderType == 'whisper';
    final isSystem = senderType == 'system';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');

    Color bgColor;
    Color textColor;
    if (isWhisper) {
      bgColor = AppColors.warning.withValues(alpha: 0.12);
      textColor = textPrimary;
    } else if (isSystem) {
      bgColor = AppColors.info.withValues(alpha: 0.1);
      textColor = textMuted;
    } else if (isAgent) {
      bgColor = AppColors.primary.withValues(alpha: 0.12);
      textColor = textPrimary;
    } else {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      textColor = textPrimary;
    }

    return Align(
      alignment: isAgent || isWhisper ? Alignment.centerRight : isSystem ? Alignment.center : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isWhisper ? Border.all(color: AppColors.warning.withValues(alpha: 0.3)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWhisper)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_off, size: 12, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text('Fısıltı', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(msg['sender_name'] ?? senderType, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (createdAt != null)
                  Text(df.format(createdAt.toLocal()), style: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Text(msg['message'] ?? '', style: TextStyle(color: textColor, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarSection(String title, Color textPrimary) {
    return Text(title, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600));
  }

  Widget _buildInfoRow(String label, String value, Color textPrimary, Color textMuted, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: textMuted, fontSize: 12))),
          Expanded(child: Text(value, style: TextStyle(color: valueColor ?? textPrimary, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label, String? currentPriority) {
    final isActive = currentPriority == value;
    final color = StatusBadge.priority(value).color ?? AppColors.textMuted;
    return InkWell(
      onTap: isActive ? null : () => _updatePriority(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isActive ? 0.5 : 0.2)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    final agent = ref.read(currentAgentProvider).value;
    if (agent == null) return;

    _messageCtrl.clear();
    final service = ref.read(ticketServiceProvider);
    await service.sendMessage(
      ticketId: widget.ticketId,
      message: text,
      senderType: _isWhisper ? 'whisper' : 'agent',
    );
    await _refreshMessages();
  }

  Future<void> _assignToMe() async {
    final agent = ref.read(currentAgentProvider).value;
    if (agent == null) return;
    final service = ref.read(ticketServiceProvider);
    await service.assignTicket(widget.ticketId, agent.id);
    ref.read(auditServiceProvider).logTicketAction(
      ticketId: widget.ticketId,
      action: 'assign_ticket',
      newData: {'assigned_agent_id': agent.id},
    );
    await _loadTicket();
  }

  Future<void> _updateStatus(String status) async {
    final agent = ref.read(currentAgentProvider).value;
    if (agent == null) return;
    final oldStatus = _ticket?['status'];
    final service = ref.read(ticketServiceProvider);
    await service.updateTicketStatus(widget.ticketId, status);
    ref.read(auditServiceProvider).logTicketAction(
      ticketId: widget.ticketId,
      action: 'update_status',
      oldData: {'status': oldStatus},
      newData: {'status': status},
    );
    await _loadTicket();
  }

  Future<void> _updatePriority(String priority) async {
    final agent = ref.read(currentAgentProvider).value;
    if (agent == null) return;
    final oldPriority = _ticket?['priority'];
    final service = ref.read(ticketServiceProvider);
    await service.updateTicketPriority(widget.ticketId, priority);
    ref.read(auditServiceProvider).logTicketAction(
      ticketId: widget.ticketId,
      action: 'update_priority',
      oldData: {'priority': oldPriority},
      newData: {'priority': priority},
    );
    await _loadTicket();
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    final agent = ref.read(currentAgentProvider).value;
    if (agent == null) return;

    _noteCtrl.clear();
    await SupabaseService.client.from('internal_notes').insert({
      'agent_id': agent.id,
      'agent_name': agent.fullName,
      'target_type': 'ticket',
      'target_id': widget.ticketId,
      'note': text,
    });
    await _loadTicket();
  }
}
