import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/ticket_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/support_auth_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/pagination_controls.dart';

final _ticketListProvider = StateNotifierProvider<_TicketListNotifier, _TicketListState>((ref) {
  return _TicketListNotifier(ref);
});

class _TicketListState {
  final List<Map<String, dynamic>> tickets;
  final int totalCount;
  final bool isLoading;
  final String? error;
  final int page;
  final int pageSize;
  final String? statusFilter;
  final String? priorityFilter;
  final String? serviceTypeFilter;
  final bool myTicketsOnly;
  final String sortColumn;
  final bool sortAscending;

  const _TicketListState({
    this.tickets = const [],
    this.totalCount = 0,
    this.isLoading = false,
    this.error,
    this.page = 0,
    this.pageSize = 20,
    this.statusFilter,
    this.priorityFilter,
    this.serviceTypeFilter,
    this.myTicketsOnly = false,
    this.sortColumn = 'created_at',
    this.sortAscending = false,
  });

  _TicketListState copyWith({
    List<Map<String, dynamic>>? tickets,
    int? totalCount,
    bool? isLoading,
    String? error,
    int? page,
    int? pageSize,
    String? statusFilter,
    String? priorityFilter,
    String? serviceTypeFilter,
    bool? myTicketsOnly,
    String? sortColumn,
    bool? sortAscending,
  }) {
    return _TicketListState(
      tickets: tickets ?? this.tickets,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      serviceTypeFilter: serviceTypeFilter ?? this.serviceTypeFilter,
      myTicketsOnly: myTicketsOnly ?? this.myTicketsOnly,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

class _TicketListNotifier extends StateNotifier<_TicketListState> {
  final Ref _ref;
  RealtimeChannel? _channel;

  _TicketListNotifier(this._ref) : super(const _TicketListState()) {
    fetch();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final supabase = SupabaseService.client;
    _channel = supabase.channel('tickets_screen_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_tickets',
          callback: (_) => fetch(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> fetch() async {
    state = state.copyWith(isLoading: state.tickets.isEmpty, error: null);
    try {
      final service = _ref.read(ticketServiceProvider);
      final agent = _ref.read(currentAgentProvider).value;
      final result = await service.fetchTickets(
        page: state.page,
        pageSize: state.pageSize,
        statusFilter: state.statusFilter,
        priorityFilter: state.priorityFilter,
        serviceTypeFilter: state.serviceTypeFilter,
        assignedAgentFilter: state.myTicketsOnly ? agent?.id : null,
        sortColumn: state.sortColumn,
        sortAscending: state.sortAscending,
      );
      state = state.copyWith(
        tickets: List<Map<String, dynamic>>.from(result['data']),
        totalCount: result['count'] as int,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setPage(int page) { state = state.copyWith(page: page); fetch(); }
  void setStatusFilter(String? v) { state = state.copyWith(statusFilter: v, page: 0); fetch(); }
  void setPriorityFilter(String? v) { state = state.copyWith(priorityFilter: v, page: 0); fetch(); }
  void setServiceTypeFilter(String? v) { state = state.copyWith(serviceTypeFilter: v, page: 0); fetch(); }
  void toggleMyTickets() { state = state.copyWith(myTicketsOnly: !state.myTicketsOnly, page: 0); fetch(); }
  void setSort(String col, bool asc) { state = state.copyWith(sortColumn: col, sortAscending: asc); fetch(); }
}

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_ticketListProvider);
    final notifier = ref.read(_ticketListProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final totalPages = (s.totalCount / s.pageSize).ceil().clamp(1, 9999);
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return Column(
      children: [
        // Filters bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              // My tickets toggle
              FilterChip(
                label: const Text('Benim Ticketlarım'),
                selected: s.myTicketsOnly,
                onSelected: (_) => notifier.toggleMyTickets(),
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(color: s.myTicketsOnly ? AppColors.primary : textMuted, fontSize: 12),
                side: BorderSide(color: s.myTicketsOnly ? AppColors.primary : borderColor),
              ),
              const SizedBox(width: 12),

              // Status filter
              _buildDropdown(
                value: s.statusFilter,
                hint: 'Durum',
                items: const {'open': 'Açık', 'assigned': 'Atanmış', 'pending': 'Beklemede', 'waiting_customer': 'Müşteri Bekleniyor', 'resolved': 'Çözüldü', 'closed': 'Kapalı'},
                onChanged: notifier.setStatusFilter,
                textMuted: textMuted,
                borderColor: borderColor,
                cardColor: cardColor,
              ),
              const SizedBox(width: 8),

              // Priority filter
              _buildDropdown(
                value: s.priorityFilter,
                hint: 'Öncelik',
                items: const {'low': 'Düşük', 'normal': 'Normal', 'high': 'Yüksek', 'urgent': 'Acil'},
                onChanged: notifier.setPriorityFilter,
                textMuted: textMuted,
                borderColor: borderColor,
                cardColor: cardColor,
              ),
              const SizedBox(width: 8),

              // Service type filter
              _buildDropdown(
                value: s.serviceTypeFilter,
                hint: 'Hizmet',
                items: const {'food': 'Yemek', 'market': 'Market', 'store': 'Mağaza', 'taxi': 'Taksi', 'rental': 'Kiralama', 'emlak': 'Emlak', 'car_sales': 'Araç Satış', 'general': 'Genel', 'account': 'Hesap'},
                onChanged: notifier.setServiceTypeFilter,
                textMuted: textMuted,
                borderColor: borderColor,
                cardColor: cardColor,
              ),

              const Spacer(),

              // Refresh
              IconButton(
                icon: Icon(Icons.refresh, color: textMuted, size: 20),
                onPressed: notifier.fetch,
                tooltip: 'Yenile',
              ),

              const SizedBox(width: 8),

              // New ticket
              ElevatedButton.icon(
                onPressed: () => _showCreateTicketDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yeni Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: s.isLoading
              ? const Center(child: CircularProgressIndicator())
              : s.error != null
                  ? Center(child: Text('Hata: ${s.error}', style: TextStyle(color: AppColors.error)))
                  : s.tickets.isEmpty
                      ? Center(child: Text('Ticket bulunamadı', style: TextStyle(color: textMuted)))
                      : DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 16,
                          headingRowColor: WidgetStateProperty.all(cardColor),
                          dataRowColor: WidgetStateProperty.all(Colors.transparent),
                          border: TableBorder(horizontalInside: BorderSide(color: borderColor, width: 0.5)),
                          sortColumnIndex: _getSortIndex(s.sortColumn),
                          sortAscending: s.sortAscending,
                          columns: [
                            DataColumn2(label: Text('#', style: TextStyle(color: textMuted, fontSize: 12)), fixedWidth: 60),
                            DataColumn2(
                              label: Text('Konu', style: TextStyle(color: textMuted, fontSize: 12)),
                              size: ColumnSize.L,
                              onSort: (_, asc) => notifier.setSort('subject', asc),
                            ),
                            DataColumn2(label: Text('Müşteri', style: TextStyle(color: textMuted, fontSize: 12)), size: ColumnSize.M),
                            DataColumn2(label: Text('Hizmet', style: TextStyle(color: textMuted, fontSize: 12)), fixedWidth: 100),
                            DataColumn2(label: Text('Durum', style: TextStyle(color: textMuted, fontSize: 12)), fixedWidth: 130),
                            DataColumn2(label: Text('Öncelik', style: TextStyle(color: textMuted, fontSize: 12)), fixedWidth: 90),
                            DataColumn2(
                              label: Text('Tarih', style: TextStyle(color: textMuted, fontSize: 12)),
                              fixedWidth: 140,
                              onSort: (_, asc) => notifier.setSort('created_at', asc),
                            ),
                          ],
                          rows: s.tickets.map((t) {
                            final createdAt = DateTime.tryParse(t['created_at'] ?? '');
                            return DataRow2(
                              onTap: () => context.go('${AppRoutes.tickets}/${t['id']}'),
                              cells: [
                                DataCell(Text('${t['ticket_number'] ?? '-'}', style: TextStyle(color: textMuted, fontSize: 12))),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          if ((t['metadata'] as Map<String, dynamic>?)?['is_live_chat'] == true) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                              child: const Text('CANLI', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                          Flexible(child: Text(t['subject'] ?? '', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                      if (t['assigned_agent'] != null)
                                        Text('→ ${t['assigned_agent']['full_name'] ?? ''}', style: TextStyle(color: textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(t['customer_name'] ?? t['customer_phone'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 12))),
                                DataCell(StatusBadge.serviceType(t['service_type'] ?? 'general')),
                                DataCell(StatusBadge.ticketStatus(t['status'] ?? 'open')),
                                DataCell(StatusBadge.priority(t['priority'] ?? 'normal')),
                                DataCell(Text(createdAt != null ? df.format(createdAt.toLocal()) : '-', style: TextStyle(color: textMuted, fontSize: 12))),
                              ],
                            );
                          }).toList(),
                        ),
        ),

        // Pagination
        PaginationControls(
          currentPage: s.page,
          totalPages: totalPages,
          totalCount: s.totalCount,
          pageSize: s.pageSize,
          onPrevious: () => notifier.setPage(s.page - 1),
          onNext: () => notifier.setPage(s.page + 1),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
    required Color textMuted,
    required Color borderColor,
    required Color cardColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: textMuted, fontSize: 12)),
          icon: Icon(Icons.arrow_drop_down, color: textMuted, size: 18),
          style: TextStyle(color: textMuted, fontSize: 12),
          dropdownColor: cardColor,
          items: [
            DropdownMenuItem<String>(value: null, child: Text('Tümü', style: TextStyle(color: textMuted, fontSize: 12))),
            ...items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: TextStyle(fontSize: 12)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  int? _getSortIndex(String col) {
    switch (col) {
      case 'subject': return 1;
      case 'created_at': return 6;
      default: return null;
    }
  }

  Future<void> _showCreateTicketDialog(BuildContext context, WidgetRef ref) async {
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String serviceType = 'general';
    String priority = 'normal';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Yeni Ticket Oluştur'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Müşteri Telefonu', hintText: '5xx xxx xx xx', prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Konu *', prefixIcon: Icon(Icons.subject)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Açıklama', prefixIcon: Icon(Icons.description)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: serviceType,
                        decoration: const InputDecoration(labelText: 'Hizmet Tipi'),
                        items: const [
                          DropdownMenuItem(value: 'general', child: Text('Genel')),
                          DropdownMenuItem(value: 'food', child: Text('Yemek')),
                          DropdownMenuItem(value: 'market', child: Text('Market')),
                          DropdownMenuItem(value: 'store', child: Text('Mağaza')),
                          DropdownMenuItem(value: 'taxi', child: Text('Taksi')),
                          DropdownMenuItem(value: 'rental', child: Text('Kiralama')),
                          DropdownMenuItem(value: 'emlak', child: Text('Emlak')),
                          DropdownMenuItem(value: 'car_sales', child: Text('Araç Satış')),
                          DropdownMenuItem(value: 'account', child: Text('Hesap')),
                        ],
                        onChanged: (v) => setState(() => serviceType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: priority,
                        decoration: const InputDecoration(labelText: 'Öncelik'),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Düşük')),
                          DropdownMenuItem(value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'high', child: Text('Yüksek')),
                          DropdownMenuItem(value: 'urgent', child: Text('Acil')),
                        ],
                        onChanged: (v) => setState(() => priority = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );

    if (result == true && subjectCtrl.text.isNotEmpty) {
      final agent = ref.read(currentAgentProvider).value;
      if (agent == null) return;
      final service = ref.read(ticketServiceProvider);
      final client = SupabaseService.client;

      // Try to find customer by phone
      String? customerId;
      String? customerName;
      if (phoneCtrl.text.isNotEmpty) {
        final users = await client
            .from('users')
            .select('id, first_name, last_name')
            .eq('phone', phoneCtrl.text.trim())
            .limit(1);
        if (users.isNotEmpty) {
          customerId = users[0]['id'];
          final fn = users[0]['first_name'] ?? '';
          final ln = users[0]['last_name'] ?? '';
          customerName = '$fn $ln'.trim();
        }
      }

      await service.createTicket(
        subject: subjectCtrl.text.trim(),
        description: descCtrl.text.trim(),
        serviceType: serviceType,
        priority: priority,
        customerUserId: customerId,
        customerName: customerName,
        customerPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
      );

      ref.read(_ticketListProvider.notifier).fetch();
    }
  }
}
