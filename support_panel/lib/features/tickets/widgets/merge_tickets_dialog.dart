import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/ticket_service.dart';
import '../../../core/providers/auth_provider.dart';

class MergeTicketsDialog extends ConsumerStatefulWidget {
  final String primaryTicketId;
  final String? customerUserId;
  const MergeTicketsDialog({super.key, required this.primaryTicketId, this.customerUserId});

  @override
  ConsumerState<MergeTicketsDialog> createState() => _MergeTicketsDialogState();
}

class _MergeTicketsDialogState extends ConsumerState<MergeTicketsDialog> {
  List<Map<String, dynamic>> _candidates = [];
  final Set<String> _selected = {};
  bool _isLoading = true;
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      var query = supabase
          .from('support_tickets')
          .select('id, subject, status, priority, created_at, customer_name')
          .neq('id', widget.primaryTicketId)
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer']);

      if (widget.customerUserId != null) {
        query = query.eq('customer_user_id', widget.customerUserId!);
      }

      final data = await query.order('created_at', ascending: false).limit(20);
      setState(() { _candidates = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _mergTickets() async {
    if (_selected.isEmpty) return;
    setState(() => _isMerging = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final agent = ref.read(currentAgentProvider).value;
      final ticketService = ref.read(ticketServiceProvider);

      for (final ticketId in _selected) {
        // Copy messages from merged ticket to primary
        final messages = await supabase
            .from('ticket_messages')
            .select()
            .eq('ticket_id', ticketId)
            .order('created_at');

        for (final msg in messages) {
          await supabase.from('ticket_messages').insert({
            'ticket_id': widget.primaryTicketId,
            'sender_type': msg['sender_type'],
            'sender_id': msg['sender_id'],
            'sender_name': msg['sender_name'],
            'message': '[Birlestirilen #${ticketId.substring(0, 8)}] ${msg['message']}',
            'message_type': msg['message_type'],
          });
        }

        // Mark merged ticket
        await supabase.from('support_tickets').update({
          'status': 'closed',
          'is_merged': true,
          'merged_into_id': widget.primaryTicketId,
          'closed_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', ticketId);
      }

      // Add system message to primary ticket
      await ticketService.sendMessage(
        ticketId: widget.primaryTicketId,
        message: '${_selected.length} ticket bu ticket ile birlestirildi.',
        senderType: 'system',
        messageType: 'system',
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isMerging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Birlestirme hatasi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return AlertDialog(
      title: const Text('Ticket Birlestir'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Secilen ticketlar bu ticket ile birlestirilecek. Mesajlar kopyalanacak ve birlestirilen ticketlar kapatilacak.',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _candidates.isEmpty
                      ? Center(child: Text('Birlestirilebilecek ticket bulunamadi', style: TextStyle(color: textMuted)))
                      : ListView.builder(
                          itemCount: _candidates.length,
                          itemBuilder: (ctx, i) {
                            final t = _candidates[i];
                            final id = t['id'] as String;
                            final isSelected = _selected.contains(id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : borderColor,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  });
                                },
                                activeColor: AppColors.primary,
                                title: Text(
                                  t['subject'] ?? '',
                                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${t['customer_name'] ?? ''} - ${t['status']} - #${id.substring(0, 8)}',
                                  style: TextStyle(color: textMuted, fontSize: 11),
                                ),
                                dense: true,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Iptal')),
        ElevatedButton(
          onPressed: _selected.isEmpty || _isMerging ? null : _mergTickets,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _isMerging
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('${_selected.length} Ticket Birlestir'),
        ),
      ],
    );
  }
}
