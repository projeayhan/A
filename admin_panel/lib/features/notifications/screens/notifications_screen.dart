import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../services/notification_service.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final notificationHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(notificationServiceProvider);
  return service.getNotificationHistory();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(notificationHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bildirim Yönetimi',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kullanıcılara bildirim gönderin ve geçmişi görüntüleyin.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _openSendDialog(),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Yeni Bildirim Gönder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── History list ──
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Gönderim Geçmişi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceLight),
                    Expanded(
                      child: historyAsync.when(
                        data: (history) {
                          if (history.isEmpty) {
                            return const Center(
                              child: Text(
                                'Henüz bildirim gönderilmemiş.',
                                style:
                                    TextStyle(color: AppColors.textMuted),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: history.length,
                            separatorBuilder: (_, _) => const Divider(
                                height: 1, color: AppColors.surfaceLight),
                            itemBuilder: (context, index) {
                              final item = history[index];
                              return _HistoryTile(item: item);
                            },
                          );
                        },
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (err, _) =>
                            Center(child: Text('Hata: $err')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSendDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SendNotificationDialog(
        onSent: () => ref.invalidate(notificationHistoryProvider),
      ),
    );
  }
}

// ─── History tile ─────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = item['notification_type'] as String? ?? 'info';
    final targetType = item['target_type'] as String? ?? 'all';
    final status = item['status'] as String? ?? 'pending';
    final scheduledAt = item['scheduled_at'] != null
        ? DateTime.tryParse(item['scheduled_at'])
        : null;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      leading: CircleAvatar(
        backgroundColor: _typeColor(type).withValues(alpha: 0.15),
        child: Icon(_typeIcon(type), color: _typeColor(type), size: 20),
      ),
      title: Text(
        item['title'] ?? 'Başlıksız',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(item['body'] ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _badge(_targetLabel(targetType), Colors.blue),
              _badge(_typeLabel(type), _typeColor(type)),
              _badge(_statusLabel(status), _statusColor(status)),
              if (scheduledAt != null)
                _badge(
                  '📅 ${DateFormat('dd/MM/yy HH:mm').format(scheduledAt)}',
                  Colors.purple,
                ),
              Text(
                item['created_at'] != null
                    ? item['created_at'].toString().split('T')[0]
                    : '',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(
        status == 'sent'
            ? Icons.check_circle
            : status == 'scheduled'
                ? Icons.schedule
                : Icons.pending,
        color: _statusColor(status),
        size: 20,
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  String _targetLabel(String t) {
    const m = {
      'all': 'Herkes',
      'users': 'Müşteriler',
      'merchants': 'İşletmeler',
      'couriers': 'Kuryeler',
      'specific_user': 'Belirli Kullanıcı',
      'food_users': 'Yemek Kullanıcıları',
      'rental_users': 'Kiralama Kullanıcıları',
      'new_users': 'Yeni Kullanıcılar',
    };
    return m[t] ?? t;
  }

  String _typeLabel(String t) {
    const m = {
      'info': 'Bilgi',
      'warning': 'Uyarı',
      'promo': 'Promosyon',
      'system': 'Sistem',
    };
    return m[t] ?? t;
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'warning':
        return AppColors.warning;
      case 'promo':
        return Colors.purple;
      case 'system':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'promo':
        return Icons.local_offer;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'sent':
        return 'Gönderildi';
      case 'scheduled':
        return 'Planlandı';
      case 'failed':
        return 'Başarısız';
      default:
        return 'Bekliyor';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'sent':
        return AppColors.success;
      case 'scheduled':
        return Colors.blue;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }
}

// ─── Send Notification Dialog ─────────────────────────────────────────────────

class SendNotificationDialog extends ConsumerStatefulWidget {
  const SendNotificationDialog({super.key, required this.onSent});

  final VoidCallback onSent;

  @override
  ConsumerState<SendNotificationDialog> createState() =>
      _SendNotificationDialogState();
}

class _SendNotificationDialogState
    extends ConsumerState<SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();

  // Form state
  String _targetType = 'all';
  String _notifType = 'info';
  bool _scheduleEnabled = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _scheduledTime =
      TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));

  // Specific user state
  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _userSearchResults = [];
  bool _isSearchingUsers = false;

  bool _isSending = false;

  // Target audience options – split into groups for clarity
  static const _broadTargets = [
    {'value': 'all', 'label': 'Herkes', 'icon': Icons.people},
    {'value': 'users', 'label': 'Müşteriler', 'icon': Icons.person},
    {'value': 'merchants', 'label': 'İşletmeler', 'icon': Icons.store},
    {'value': 'couriers', 'label': 'Kuryeler', 'icon': Icons.delivery_dining},
  ];

  static const _segmentTargets = [
    {
      'value': 'food_users',
      'label': 'Yemek Kullanıcıları',
      'icon': Icons.restaurant
    },
    {
      'value': 'rental_users',
      'label': 'Kiralama Kullanıcıları',
      'icon': Icons.car_rental
    },
    {
      'value': 'new_users',
      'label': 'Yeni Kullanıcılar (30 gün)',
      'icon': Icons.fiber_new
    },
  ];

  static const _notifTypes = [
    {'value': 'info', 'label': 'Bilgi', 'color': AppColors.info},
    {'value': 'warning', 'label': 'Uyarı', 'color': AppColors.warning},
    {'value': 'promo', 'label': 'Promosyon', 'color': Colors.purple},
    {'value': 'system', 'label': 'Sistem', 'color': AppColors.error},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
          SizedBox(width: 10),
          Text('Yeni Bildirim Gönder'),
        ],
      ),
      content: SizedBox(
        width: 540,
        height: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Bildirim türü ──
                _sectionLabel('Bildirim Türü'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _notifTypes.map((t) {
                    final selected = _notifType == t['value'];
                    final color = t['color'] as Color;
                    return ChoiceChip(
                      label: Text(t['label'] as String),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _notifType = t['value'] as String),
                      selectedColor: color.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: selected ? color : AppColors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: selected
                            ? color
                            : AppColors.surfaceLight,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Başlık ──
                TextFormField(
                  controller: _titleCtrl,
                  enabled: !_isSending,
                  decoration: const InputDecoration(
                    labelText: 'Başlık *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Başlık gerekli' : null,
                ),
                const SizedBox(height: 12),

                // ── Mesaj ──
                TextFormField(
                  controller: _bodyCtrl,
                  enabled: !_isSending,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mesaj *',
                    border: OutlineInputBorder(),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 42),
                      child: Icon(Icons.message),
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Mesaj gerekli' : null,
                ),
                const SizedBox(height: 20),

                // ── Hedef kitle ──
                _sectionLabel('Hedef Kitle'),
                const SizedBox(height: 10),

                // Broad targets
                ..._broadTargets.map((t) => _targetTile(
                      value: t['value'] as String,
                      label: t['label'] as String,
                      icon: t['icon'] as IconData,
                    )),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Segmentler',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                ),

                // Segment targets
                ..._segmentTargets.map((t) => _targetTile(
                      value: t['value'] as String,
                      label: t['label'] as String,
                      icon: t['icon'] as IconData,
                    )),

                // Specific user option
                _targetTile(
                  value: 'specific_user',
                  label: 'Belirli Kullanıcı',
                  icon: Icons.person_search,
                ),

                // User search (visible when specific_user selected)
                if (_targetType == 'specific_user') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _userSearchCtrl,
                    enabled: !_isSending,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Ara (ad, e-posta, telefon)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearchingUsers
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onChanged: _onUserSearch,
                  ),
                  if (_selectedUser != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedUser!['full_name'] ?? 'İsimsiz',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                if (_selectedUser!['email'] != null)
                                  Text(
                                    _selectedUser!['email'],
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() {
                              _selectedUser = null;
                              _userSearchCtrl.clear();
                              _userSearchResults = [];
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_userSearchResults.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.surfaceLight),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _userSearchResults.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final u = _userSearchResults[i];
                          return ListTile(
                            dense: true,
                            leading: const CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.surfaceLight,
                              child: Icon(Icons.person,
                                  size: 16, color: AppColors.textSecondary),
                            ),
                            title: Text(u['full_name'] ?? 'İsimsiz',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(u['email'] ?? u['phone'] ?? '',
                                style: const TextStyle(fontSize: 11)),
                            onTap: () => setState(() {
                              _selectedUser = u;
                              _userSearchResults = [];
                              _userSearchCtrl.clear();
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 20),

                // ── Zamanlama ──
                _sectionLabel('Gönderim Zamanı'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _scheduleOption(
                        label: 'Hemen Gönder',
                        icon: Icons.send,
                        selected: !_scheduleEnabled,
                        onTap: () =>
                            setState(() => _scheduleEnabled = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _scheduleOption(
                        label: 'Zamanlı Gönder',
                        icon: Icons.schedule,
                        selected: _scheduleEnabled,
                        onTap: () =>
                            setState(() => _scheduleEnabled = true),
                      ),
                    ),
                  ],
                ),

                if (_scheduleEnabled) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _dateTap()),
                      const SizedBox(width: 10),
                      Expanded(child: _timeTap()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bildirim: ${DateFormat('dd/MM/yyyy HH:mm').format(_mergedSchedule())} itibarıyla gönderilir.',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _isSending ? null : _send,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 16),
          label: Text(_scheduleEnabled ? 'Planla' : 'Gönder'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary),
    );
  }

  Widget _targetTile({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _targetType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isSending
          ? null
          : () => setState(() {
                _targetType = value;
                if (value != 'specific_user') {
                  _selectedUser = null;
                  _userSearchCtrl.clear();
                  _userSearchResults = [];
                }
              }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceLight,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _scheduleOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isSending ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected ? AppColors.primary : AppColors.surfaceLight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTap() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _scheduledDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _scheduledDate = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tarih',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(_scheduledDate),
            style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _timeTap() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _scheduledTime,
        );
        if (picked != null) setState(() => _scheduledTime = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Saat',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.access_time, size: 16),
        ),
        child: Text(_scheduledTime.format(context),
            style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  // ── Logic ──────────────────────────────────────────────────────────────────

  DateTime _mergedSchedule() {
    return DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );
  }

  Future<void> _onUserSearch(String query) async {
    if (query.length < 2) {
      setState(() => _userSearchResults = []);
      return;
    }
    setState(() => _isSearchingUsers = true);
    final results =
        await ref.read(notificationServiceProvider).searchUsers(query);
    if (mounted) {
      setState(() {
        _userSearchResults = results;
        _isSearchingUsers = false;
      });
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate specific user selection
    if (_targetType == 'specific_user' && _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir kullanıcı seçin'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final scheduledAt =
        _scheduleEnabled ? _mergedSchedule() : null;

    try {
      await ref.read(notificationServiceProvider).sendNotification(
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            targetType: _targetType,
            targetId: _targetType == 'specific_user'
                ? _selectedUser!['id'] as String?
                : null,
            notificationType: _notifType,
            scheduledAt: scheduledAt,
          );

      widget.onSent();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(scheduledAt != null
                ? 'Bildirim planlandı: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledAt)}'
                : 'Bildirim başarıyla gönderildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }
}
