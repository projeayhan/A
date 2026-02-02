import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../services/notification_service.dart';

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
            // Header
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
                      'Kullanıcılara toplu bildirim gönderin ve geçmişi görüntüleyin.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showSendNotificationDialog(context),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Yeni Bildirim Gönder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // History List
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
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: history.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: AppColors.surfaceLight,
                            ),
                            itemBuilder: (context, index) {
                              final item = history[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.notifications,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  item['title'] ?? 'Başlıksız',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(item['body'] ?? ''),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        _buildBadge(
                                          item['target_type'] ?? 'all',
                                        ),
                                        Text(
                                          item['created_at'] != null
                                              ? item['created_at']
                                                    .toString()
                                                    .split('T')[0]
                                              : '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) =>
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

  Widget _buildBadge(String type) {
    Color color;
    String text;

    switch (type) {
      case 'users':
        color = Colors.blue;
        text = 'Müşteriler';
        break;
      case 'merchants':
        color = Colors.orange;
        text = 'İşletmeler';
        break;
      case 'couriers':
        color = Colors.purple;
        text = 'Kuryeler';
        break;
      default:
        color = Colors.green;
        text = 'Herkes';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showSendNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SendNotificationDialog(),
    );
  }
}

// Stats Provider
final notificationHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.read(notificationServiceProvider);
  return service.getNotificationHistory();
});

class SendNotificationDialog extends ConsumerStatefulWidget {
  const SendNotificationDialog({super.key});

  @override
  ConsumerState<SendNotificationDialog> createState() =>
      _SendNotificationDialogState();
}

class _SendNotificationDialogState
    extends ConsumerState<SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _selectedTarget = 'all';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Bildirim Gönder'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedTarget,
                decoration: const InputDecoration(
                  labelText: 'Hedef Kitle',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Herkes')),
                  DropdownMenuItem(value: 'users', child: Text('Müşteriler')),
                  DropdownMenuItem(
                    value: 'merchants',
                    child: Text('İşletmeler'),
                  ),
                  DropdownMenuItem(value: 'couriers', child: Text('Kuryeler')),
                ],
                onChanged: (value) => setState(() => _selectedTarget = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Başlık gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Mesaj',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Mesaj gerekli' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Gönder'),
        ),
      ],
    );
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(notificationServiceProvider)
          .sendNotification(
            title: _titleController.text,
            body: _bodyController.text,
            targetType: _selectedTarget,
          );

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(notificationHistoryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim başarıyla gönderildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
