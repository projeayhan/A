import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/macro_builder.dart';

class MacrosScreen extends ConsumerStatefulWidget {
  const MacrosScreen({super.key});

  @override
  ConsumerState<MacrosScreen> createState() => _MacrosScreenState();
}

class _MacrosScreenState extends ConsumerState<MacrosScreen> {
  List<Map<String, dynamic>> _macros = [];
  bool _isLoading = true;
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadMacros();
  }

  Future<void> _loadMacros() async {
    setState(() => _isLoading = true);
    try {
      var query = ref.read(supabaseProvider)
          .from('support_macros')
          .select()
          .eq('is_active', true);

      if (_filterCategory != 'all') {
        query = query.eq('category', _filterCategory);
      }

      final data = await query.order('usage_count', ascending: false);
      setState(() { _macros = List<Map<String, dynamic>>.from(data); _isLoading = false; });
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
    final canManage = agent?.hasPermission('manage_macros') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Text('Makrolar', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
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
                  DropdownMenuItem(value: 'complaint', child: Text('Sikayet')),
                  DropdownMenuItem(value: 'general', child: Text('Genel')),
                ],
                onChanged: (v) {
                  _filterCategory = v ?? 'all';
                  _loadMacros();
                },
              ),
              if (canManage) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showMacroBuilder(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Makro'),
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
              : _macros.isEmpty
                  ? Center(child: Text('Makro bulunamadi', style: TextStyle(color: textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _macros.length,
                      itemBuilder: (ctx, i) {
                        final m = _macros[i];
                        final actions = (m['actions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
                                  Icon(Icons.bolt, size: 18, color: AppColors.warning),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      m['name'] ?? '',
                                      style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (m['category'] != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        m['category'],
                                        style: const TextStyle(color: AppColors.info, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                  if (canManage) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.edit, size: 16, color: textMuted),
                                      onPressed: () => _showMacroBuilder(m),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                      onPressed: () => _deleteMacro(m['id']),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ],
                              ),
                              if (m['description'] != null && (m['description'] as String).isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(m['description'], style: TextStyle(color: textMuted, fontSize: 13)),
                              ],
                              const SizedBox(height: 10),
                              // Action chips
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: actions.map((a) {
                                  final type = a['type'] as String? ?? '';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _actionColor(type).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _actionColor(type).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_actionIcon(type), size: 12, color: _actionColor(type)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _actionLabel(type),
                                          style: TextStyle(color: _actionColor(type), fontSize: 11, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 14, color: textMuted.withValues(alpha: 0.6)),
                                  const SizedBox(width: 4),
                                  Text('${m['usage_count'] ?? 0} kullanim', style: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 11)),
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

  Future<void> _showMacroBuilder(Map<String, dynamic>? existing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => MacroBuilderDialog(existing: existing),
    );

    if (result == null) return;

    final agent = ref.read(currentAgentProvider).value;
    final supabase = ref.read(supabaseProvider);

    if (existing == null) {
      result['created_by'] = agent?.id;
      await supabase.from('support_macros').insert(result);
    } else {
      await supabase.from('support_macros').update(result).eq('id', existing['id']);
    }

    _loadMacros();
  }

  Future<void> _deleteMacro(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Makroyu Sil'),
        content: const Text('Bu makroyu silmek istediginizden emin misiniz?'),
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
    await ref.read(supabaseProvider).from('support_macros').update({'is_active': false}).eq('id', id);
    _loadMacros();
  }

  Color _actionColor(String type) {
    switch (type) {
      case 'send_message': return AppColors.primary;
      case 'change_status': return AppColors.success;
      case 'change_priority': return AppColors.warning;
      case 'add_tag': return AppColors.info;
      case 'add_note': return AppColors.textMuted;
      default: return AppColors.textMuted;
    }
  }

  IconData _actionIcon(String type) {
    switch (type) {
      case 'send_message': return Icons.message;
      case 'change_status': return Icons.swap_horiz;
      case 'change_priority': return Icons.flag;
      case 'add_tag': return Icons.label;
      case 'add_note': return Icons.note;
      default: return Icons.circle;
    }
  }

  String _actionLabel(String type) {
    switch (type) {
      case 'send_message': return 'Mesaj Gonder';
      case 'change_status': return 'Durum Degistir';
      case 'change_priority': return 'Oncelik Degistir';
      case 'add_tag': return 'Tag Ekle';
      case 'add_note': return 'Not Ekle';
      default: return type;
    }
  }
}
