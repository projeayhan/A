import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../core/router/app_router.dart';

class GlobalSearchDialog extends ConsumerStatefulWidget {
  const GlobalSearchDialog({super.key});

  @override
  ConsumerState<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<GlobalSearchDialog> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<_SearchResult> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final supabase = ref.read(supabaseProvider);

    try {
      final results = await Future.wait([
        // Search tickets
        supabase
            .from('support_tickets')
            .select('id, subject, customer_name, status')
            .or('subject.ilike.%$query%,customer_name.ilike.%$query%,customer_phone.ilike.%$query%')
            .limit(5),
        // Search customers (profiles)
        supabase
            .from('profiles')
            .select('id, full_name, phone, email')
            .or('full_name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%')
            .limit(5),
        // Search knowledge base
        supabase
            .from('knowledge_base')
            .select('id, title, category')
            .eq('is_published', true)
            .ilike('title', '%$query%')
            .limit(5),
      ]);

      final List<_SearchResult> all = [];

      // Tickets
      for (final t in results[0]) {
        all.add(_SearchResult(
          type: 'ticket',
          id: t['id'],
          title: t['subject'] ?? '',
          subtitle: '${t['customer_name'] ?? ''} - ${t['status']}',
          icon: Icons.confirmation_number,
          color: AppColors.warning,
        ));
      }

      // Customers
      for (final c in results[1]) {
        all.add(_SearchResult(
          type: 'customer',
          id: c['id'],
          title: c['full_name'] ?? '',
          subtitle: c['phone'] ?? c['email'] ?? '',
          icon: Icons.person,
          color: AppColors.info,
        ));
      }

      // Knowledge base
      for (final k in results[2]) {
        all.add(_SearchResult(
          type: 'kb',
          id: k['id'],
          title: k['title'] ?? '',
          subtitle: k['category'] ?? '',
          icon: Icons.article,
          color: AppColors.success,
        ));
      }

      setState(() { _results = all; _isSearching = false; });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _navigateTo(_SearchResult result) {
    Navigator.pop(context);
    switch (result.type) {
      case 'ticket':
        context.go('${AppRoutes.tickets}/${result.id}');
        break;
      case 'customer':
        context.go('${AppRoutes.customers}/${result.id}');
        break;
      case 'kb':
        // KB articles open in settings/knowledge-base, just close for now
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search input
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ticket, musteri, makale ara... (Ctrl+K)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            if (_results.isNotEmpty) ...[
              Divider(height: 1, color: borderColor),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final r = _results[i];
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: r.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(r.icon, size: 16, color: r.color),
                      ),
                      title: Text(r.title, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(r.subtitle, style: TextStyle(color: textMuted, fontSize: 11)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: r.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _typeLabel(r.type),
                          style: TextStyle(color: r.color, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                      onTap: () => _navigateTo(r),
                    );
                  },
                ),
              ),
            ] else if (_searchCtrl.text.length >= 2 && !_isSearching) ...[
              Divider(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Sonuc bulunamadi', style: TextStyle(color: textMuted, fontSize: 13)),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.search, size: 40, color: textMuted.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    Text('Ticket, musteri veya bilgi bankasi makalesi arayin', style: TextStyle(color: textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'ticket': return 'Ticket';
      case 'customer': return 'Musteri';
      case 'kb': return 'Makale';
      default: return type;
    }
  }
}

class _SearchResult {
  final String type;
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
