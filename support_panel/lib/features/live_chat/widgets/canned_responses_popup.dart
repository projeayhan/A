import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/providers/chat_providers.dart';

class CannedResponsesPopup extends ConsumerStatefulWidget {
  final void Function(String content) onSelect;
  const CannedResponsesPopup({super.key, required this.onSelect});

  @override
  ConsumerState<CannedResponsesPopup> createState() => _CannedResponsesPopupState();
}

class _CannedResponsesPopupState extends ConsumerState<CannedResponsesPopup> {
  String _search = '';
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final responsesAsync = ref.watch(cannedResponsesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Dialog(
      child: Container(
        width: 500,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hazır Yanıtlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            // Search
            TextField(
              decoration: InputDecoration(
                hintText: 'Ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                filled: true,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
            const SizedBox(height: 12),
            // Category filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('Tümü', null),
                  _buildCategoryChip('Genel', 'genel'),
                  _buildCategoryChip('Sipariş', 'siparis'),
                  _buildCategoryChip('Teslimat', 'teslimat'),
                  _buildCategoryChip('Taksi', 'taksi'),
                  _buildCategoryChip('Kiralama', 'kiralama'),
                  _buildCategoryChip('İlan', 'ilan'),
                  _buildCategoryChip('Hesap', 'hesap'),
                  _buildCategoryChip('Teknik', 'teknik'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // List
            Expanded(
              child: responsesAsync.when(
                data: (responses) {
                  var filtered = responses;
                  if (_categoryFilter != null) {
                    filtered = filtered.where((r) => r['category'] == _categoryFilter).toList();
                  }
                  if (_search.isNotEmpty) {
                    filtered = filtered.where((r) {
                      final title = (r['title'] as String? ?? '').toLowerCase();
                      final content = (r['content'] as String? ?? '').toLowerCase();
                      final shortcut = (r['shortcut'] as String? ?? '').toLowerCase();
                      return title.contains(_search) || content.contains(_search) || shortcut.contains(_search);
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(child: Text('Sonuç bulunamadı', style: TextStyle(color: textMuted)));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              if (item['shortcut'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['shortcut'],
                                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontFamily: 'monospace'),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item['content'] ?? '',
                              style: TextStyle(color: textMuted, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onTap: () {
                            ref.read(chatServiceProvider).incrementCannedResponseUsage(item['id']);
                            widget.onSelect(item['content'] ?? '');
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isActive = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _categoryFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isActive ? AppColors.primary : Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primary : null,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
