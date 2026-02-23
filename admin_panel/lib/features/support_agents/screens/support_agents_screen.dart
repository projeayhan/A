import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pagination_controls.dart';

final _agentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('support_agents')
      .select()
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class SupportAgentsScreen extends ConsumerStatefulWidget {
  const SupportAgentsScreen({super.key});

  @override
  ConsumerState<SupportAgentsScreen> createState() => _SupportAgentsScreenState();
}

class _SupportAgentsScreenState extends ConsumerState<SupportAgentsScreen> {
  int _currentPage = 0;
  static const _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(_agentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Destek Agentları', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Müşteri temsilcisi hesaplarını yönetin', style: TextStyle(color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Yeni Agent'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: agentsAsync.when(
              data: (agents) {
                if (agents.isEmpty) {
                  return const Center(child: Text('Henüz destek agentı bulunmuyor'));
                }
                final totalPages = (agents.length / _pageSize).ceil();
                final pageData = agents.skip(_currentPage * _pageSize).take(_pageSize).toList();

                return Column(
                  children: [
                    Expanded(
                      child: Card(
                        child: DataTable2(
                          columnSpacing: 16,
                          horizontalMargin: 16,
                          minWidth: 800,
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? AppColors.surfaceLight.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                          ),
                          columns: const [
                            DataColumn2(label: Text('Ad Soyad', style: TextStyle(fontWeight: FontWeight.w600)), size: ColumnSize.L),
                            DataColumn2(label: Text('E-posta', style: TextStyle(fontWeight: FontWeight.w600)), size: ColumnSize.L),
                            DataColumn2(label: Text('Telefon', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn2(label: Text('Yetki', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn2(label: Text('Durum', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn2(label: Text('Maks Chat', style: TextStyle(fontWeight: FontWeight.w600)), fixedWidth: 90),
                            DataColumn2(label: Text('İşlem', style: TextStyle(fontWeight: FontWeight.w600)), fixedWidth: 100),
                          ],
                          rows: pageData.map((agent) {
                            return DataRow2(
                              cells: [
                                DataCell(Text(agent['full_name'] ?? '-')),
                                DataCell(Text(agent['email'] ?? '-')),
                                DataCell(Text(agent['phone'] ?? '-')),
                                DataCell(_buildPermissionBadge(agent['permission_level'] ?? 'L1')),
                                DataCell(_buildStatusBadge(agent['status'] ?? 'offline')),
                                DataCell(Text('${agent['max_concurrent_chats'] ?? 5}')),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _showEditDialog(context, agent),
                                      tooltip: 'Düzenle',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                                      onPressed: () => _confirmDelete(context, agent),
                                      tooltip: 'Sil',
                                    ),
                                  ],
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: PaginationControls(
                          currentPage: _currentPage,
                          totalPages: totalPages,
                          totalCount: agents.length,
                          pageSize: _pageSize,
                          onPrevious: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                          onNext: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBadge(String level) {
    Color color;
    String label;
    switch (level) {
      case 'L1': color = AppColors.info; label = 'Seviye 1'; break;
      case 'L2': color = AppColors.primary; label = 'Seviye 2'; break;
      case 'supervisor': color = AppColors.warning; label = 'Supervisor'; break;
      case 'manager': color = AppColors.error; label = 'Yönetici'; break;
      default: color = AppColors.textMuted; label = level;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'online': color = AppColors.success; label = 'Çevrimiçi'; break;
      case 'busy': color = AppColors.warning; label = 'Meşgul'; break;
      case 'break': color = AppColors.info; label = 'Mola'; break;
      default: color = AppColors.textMuted; label = 'Çevrimdışı';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String permissionLevel = 'L1';
    int maxChats = 5;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Destek Agentı'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ad Soyad *')),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-posta *')),
                const SizedBox(height: 12),
                TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre *')),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: permissionLevel,
                  decoration: const InputDecoration(labelText: 'Yetki Seviyesi'),
                  items: const [
                    DropdownMenuItem(value: 'L1', child: Text('Seviye 1')),
                    DropdownMenuItem(value: 'L2', child: Text('Seviye 2')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'manager', child: Text('Yönetici')),
                  ],
                  onChanged: (v) => setDialogState(() => permissionLevel = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$maxChats',
                  decoration: const InputDecoration(labelText: 'Maks Eşzamanlı Chat'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => maxChats = int.tryParse(v) ?? 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
        _showSnack('Ad, e-posta ve şifre zorunludur', isError: true);
        return;
      }
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) throw Exception('Oturum bulunamadı');

        final response = await Supabase.instance.client.functions.invoke(
          'create-support-agent',
          body: {
            'email': emailCtrl.text.trim(),
            'password': passwordCtrl.text,
            'full_name': nameCtrl.text.trim(),
            'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
            'permission_level': permissionLevel,
            'max_concurrent_chats': maxChats,
          },
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        );

        final data = response.data;
        if (data is Map && data['error'] != null) {
          throw Exception(data['error']);
        }

        ref.invalidate(_agentsProvider);
        _showSnack('Agent başarıyla oluşturuldu');
      } catch (e) {
        _showSnack('Hata: $e', isError: true);
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context, Map<String, dynamic> agent) async {
    final nameCtrl = TextEditingController(text: agent['full_name']);
    final phoneCtrl = TextEditingController(text: agent['phone'] ?? '');
    String permissionLevel = agent['permission_level'] ?? 'L1';
    int maxChats = agent['max_concurrent_chats'] ?? 5;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Agent Düzenle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ad Soyad')),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: permissionLevel,
                  decoration: const InputDecoration(labelText: 'Yetki Seviyesi'),
                  items: const [
                    DropdownMenuItem(value: 'L1', child: Text('Seviye 1')),
                    DropdownMenuItem(value: 'L2', child: Text('Seviye 2')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'manager', child: Text('Yönetici')),
                  ],
                  onChanged: (v) => setDialogState(() => permissionLevel = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$maxChats',
                  decoration: const InputDecoration(labelText: 'Maks Eşzamanlı Chat'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => maxChats = int.tryParse(v) ?? 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        await Supabase.instance.client.from('support_agents').update({
          'full_name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
          'permission_level': permissionLevel,
          'max_concurrent_chats': maxChats,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', agent['id']);

        ref.invalidate(_agentsProvider);
        _showSnack('Agent güncellendi');
      } catch (e) {
        _showSnack('Hata: $e', isError: true);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> agent) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agent Sil'),
        content: Text('${agent['full_name']} adlı agentı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await Supabase.instance.client.from('support_agents').delete().eq('id', agent['id']);
        ref.invalidate(_agentsProvider);
        _showSnack('Agent silindi');
      } catch (e) {
        _showSnack('Hata: $e', isError: true);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }
}
