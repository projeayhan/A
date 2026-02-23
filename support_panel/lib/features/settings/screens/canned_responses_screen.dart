import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';

class CannedResponsesScreen extends ConsumerStatefulWidget {
  const CannedResponsesScreen({super.key});

  @override
  ConsumerState<CannedResponsesScreen> createState() => _CannedResponsesScreenState();
}

class _CannedResponsesScreenState extends ConsumerState<CannedResponsesScreen> {
  List<Map<String, dynamic>> _responses = [];
  bool _isLoading = true;
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    setState(() => _isLoading = true);
    try {
      var query = ref.read(supabaseProvider)
          .from('canned_responses')
          .select()
          .eq('is_active', true);

      if (_filterCategory != 'all') {
        query = query.eq('category', _filterCategory);
      }

      final data = await query.order('usage_count', ascending: false);
      setState(() { _responses = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(currentAgentProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final canManage = agent?.hasPermission('manage_canned_responses') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Text('Hazir Yanitlar', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              // Category filter
              DropdownButton<String>(
                value: _filterCategory,
                underline: const SizedBox.shrink(),
                style: TextStyle(color: textPrimary, fontSize: 13),
                dropdownColor: cardColor,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tum Kategoriler')),
                  DropdownMenuItem(value: 'greeting', child: Text('Selamlama')),
                  DropdownMenuItem(value: 'order', child: Text('Siparis')),
                  DropdownMenuItem(value: 'delivery', child: Text('Teslimat')),
                  DropdownMenuItem(value: 'payment', child: Text('Odeme')),
                  DropdownMenuItem(value: 'complaint', child: Text('Sikayet')),
                  DropdownMenuItem(value: 'closing', child: Text('Kapanis')),
                  DropdownMenuItem(value: 'general', child: Text('Genel')),
                ],
                onChanged: (v) {
                  _filterCategory = v ?? 'all';
                  _loadResponses();
                },
              ),
              if (canManage) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showEditDialog(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Yanit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _responses.isEmpty
                  ? Center(child: Text('Hazir yanit bulunamadi', style: TextStyle(color: textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _responses.length,
                      itemBuilder: (ctx, i) {
                        final r = _responses[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r['title'] ?? '',
                                      style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (r['shortcut'] != null && (r['shortcut'] as String).isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '/${r['shortcut']}',
                                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  if (r['category'] != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        r['category'],
                                        style: const TextStyle(color: AppColors.info, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                  if (canManage) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.edit, size: 16, color: textMuted),
                                      onPressed: () => _showEditDialog(r),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                      onPressed: () => _deleteResponse(r['id']),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                r['content'] ?? '',
                                style: TextStyle(color: textMuted, fontSize: 13),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 14, color: textMuted.withValues(alpha: 0.6)),
                                  const SizedBox(width: 4),
                                  Text('${r['usage_count'] ?? 0} kullanim', style: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic>? existing) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final contentCtrl = TextEditingController(text: existing?['content'] ?? '');
    final shortcutCtrl = TextEditingController(text: existing?['shortcut'] ?? '');
    String category = existing?['category'] ?? 'general';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Yeni Hazir Yanit' : 'Hazir Yaniti Duzenle'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Baslik', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(labelText: 'Icerik', border: OutlineInputBorder()),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: shortcutCtrl,
                  decoration: const InputDecoration(labelText: 'Kisayol (opsiyonel)', border: OutlineInputBorder(), hintText: 'ornegin: selamlama'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'greeting', child: Text('Selamlama')),
                    DropdownMenuItem(value: 'order', child: Text('Siparis')),
                    DropdownMenuItem(value: 'delivery', child: Text('Teslimat')),
                    DropdownMenuItem(value: 'payment', child: Text('Odeme')),
                    DropdownMenuItem(value: 'complaint', child: Text('Sikayet')),
                    DropdownMenuItem(value: 'closing', child: Text('Kapanis')),
                    DropdownMenuItem(value: 'general', child: Text('Genel')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v ?? 'general'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Iptal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? 'Olustur' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final agent = ref.read(currentAgentProvider).value;
    final supabase = ref.read(supabaseProvider);
    final data = {
      'title': titleCtrl.text,
      'content': contentCtrl.text,
      'shortcut': shortcutCtrl.text.isEmpty ? null : shortcutCtrl.text,
      'category': category,
    };

    if (existing == null) {
      data['created_by'] = agent?.id;
      await supabase.from('canned_responses').insert(data);
    } else {
      await supabase.from('canned_responses').update(data).eq('id', existing['id']);
    }

    _loadResponses();
  }

  Future<void> _deleteResponse(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hazir Yaniti Sil'),
        content: const Text('Bu hazir yaniti silmek istediginizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(supabaseProvider).from('canned_responses').update({'is_active': false}).eq('id', id);
    _loadResponses();
  }
}
