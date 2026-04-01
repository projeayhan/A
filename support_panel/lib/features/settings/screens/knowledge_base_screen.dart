import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:support_panel/core/services/log_service.dart';
import 'kb_article_screen.dart';

class KnowledgeBaseScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  ConsumerState<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends ConsumerState<KnowledgeBaseScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = true;
  String _filterCategory = 'all';
  String _filterServiceType = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);

      if (_searchQuery.isNotEmpty) {
        // Full-text search
        final data = await supabase
            .from('knowledge_base')
            .select()
            .eq('is_published', true)
            .textSearch('search_vector', _searchQuery, type: TextSearchType.plain)
            .order('view_count', ascending: false)
            .limit(50);
        setState(() { _articles = List<Map<String, dynamic>>.from(data); _isLoading = false; });
        return;
      }

      var query = supabase
          .from('knowledge_base')
          .select()
          .eq('is_published', true);

      if (_filterCategory != 'all') {
        query = query.eq('category', _filterCategory);
      }
      if (_filterServiceType != 'all') {
        query = query.eq('service_type', _filterServiceType);
      }

      final data = await query.order('view_count', ascending: false).limit(100);
      setState(() { _articles = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e, st) {
      LogService.error('Failed to load articles', error: e, stackTrace: st, source: 'KnowledgeBaseScreen:_loadArticles');
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
    final canEdit = agent?.hasPermission('edit_knowledge_base') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Bilgi Bankasi', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (canEdit)
                    ElevatedButton.icon(
                      onPressed: () => _showArticleEditor(null),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Makale'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Search + filters row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Makale ara...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                  _loadArticles();
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (v) {
                        _searchQuery = v.trim();
                        _loadArticles();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filterCategory,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    dropdownColor: cardColor,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tum Kategoriler')),
                      DropdownMenuItem(value: 'faq', child: Text('SSS')),
                      DropdownMenuItem(value: 'policy', child: Text('Politika')),
                      DropdownMenuItem(value: 'procedure', child: Text('Prosedur')),
                      DropdownMenuItem(value: 'troubleshooting', child: Text('Sorun Giderme')),
                      DropdownMenuItem(value: 'guide', child: Text('Kilavuz')),
                    ],
                    onChanged: (v) {
                      _filterCategory = v ?? 'all';
                      _loadArticles();
                    },
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filterServiceType,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    dropdownColor: cardColor,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tum Servisler')),
                      DropdownMenuItem(value: 'food', child: Text('Yemek')),
                      DropdownMenuItem(value: 'grocery', child: Text('Market')),
                      DropdownMenuItem(value: 'taxi', child: Text('Taksi')),
                      DropdownMenuItem(value: 'courier', child: Text('Kurye')),
                      DropdownMenuItem(value: 'rental', child: Text('Kiralama')),
                      DropdownMenuItem(value: 'emlak', child: Text('Emlak')),
                      DropdownMenuItem(value: 'car_sales', child: Text('Arac Satis')),
                    ],
                    onChanged: (v) {
                      _filterServiceType = v ?? 'all';
                      _loadArticles();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Articles grid
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _articles.isEmpty
                  ? Center(child: Text('Makale bulunamadi', style: TextStyle(color: textMuted)))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 180,
                      ),
                      itemCount: _articles.length,
                      itemBuilder: (ctx, i) {
                        final a = _articles[i];
                        final tags = (a['tags'] as List?)?.cast<String>() ?? [];

                        return InkWell(
                          onTap: () => _showArticleEditor(a),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
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
                                    Icon(Icons.article_outlined, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a['title'] ?? '',
                                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Text(
                                    a['content'] ?? '',
                                    style: TextStyle(color: textMuted, fontSize: 12),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (a['service_type'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.info.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(a['service_type'], style: const TextStyle(color: AppColors.info, fontSize: 10)),
                                      ),
                                    if (tags.isNotEmpty)
                                      ...tags.take(2).map((t) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(t, style: TextStyle(color: AppColors.primary, fontSize: 10)),
                                      )),
                                    const Spacer(),
                                    Icon(Icons.visibility, size: 12, color: textMuted.withValues(alpha: 0.5)),
                                    const SizedBox(width: 4),
                                    Text('${a['view_count'] ?? 0}', style: TextStyle(color: textMuted.withValues(alpha: 0.5), fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _showArticleEditor(Map<String, dynamic>? existing) async {
    // Increment view count if viewing existing article
    if (existing != null) {
      try {
        await ref.read(supabaseProvider).rpc('', params: {});
        // Simple view count increment
        await ref.read(supabaseProvider)
            .from('knowledge_base')
            .update({'view_count': (existing['view_count'] ?? 0) + 1})
            .eq('id', existing['id']);
      } catch (e, st) {
        LogService.error('Error incrementing view count', error: e, stackTrace: st, source: 'KnowledgeBaseScreen:_showArticleEditor');
      }
    }

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => KbArticleDialog(existing: existing),
    );

    if (result == null) return;

    final agent = ref.read(currentAgentProvider).value;
    final canEdit = agent?.hasPermission('edit_knowledge_base') ?? false;
    if (!canEdit) return;

    final supabase = ref.read(supabaseProvider);

    if (existing == null) {
      result['author_id'] = agent?.id;
      await supabase.from('knowledge_base').insert(result);
    } else {
      await supabase.from('knowledge_base').update(result).eq('id', existing['id']);
    }

    _loadArticles();
  }
}
