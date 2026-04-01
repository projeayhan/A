import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/router/app_router.dart';
import 'package:support_panel/core/services/log_service.dart';

class CustomerSearchScreen extends ConsumerStatefulWidget {
  const CustomerSearchScreen({super.key});

  @override
  ConsumerState<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends ConsumerState<CustomerSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      final service = ref.read(customerServiceProvider);
      final results = await service.searchCustomers(query: q);
      setState(() { _results = results; _isLoading = false; });
    } catch (e, st) {
      LogService.error('Customer search failed', error: e, stackTrace: st, source: 'CustomerSearchScreen:_search');
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final df = DateFormat('dd.MM.yyyy');

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'İsim, telefon veya e-posta ile ara...',
                    hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search, color: textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text('Ara'),
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_hasSearched
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search, size: 64, color: textMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('Müşteri aramak için yukarıdaki alanı kullanın', style: TextStyle(color: textMuted)),
                        ],
                      ),
                    )
                  : _results.isEmpty
                      ? Center(child: Text('Sonuç bulunamadı', style: TextStyle(color: textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final user = _results[index];
                            final createdAt = DateTime.tryParse(user['created_at'] ?? '');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => context.go('${AppRoutes.customers}/${user['id']}'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                        child: Text(
                                          (user['full_name'] ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(user['full_name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            Text('${user['phone'] ?? '-'} • ${user['email'] ?? '-'}', style: TextStyle(color: textMuted, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      if (createdAt != null)
                                        Text('Kayıt: ${df.format(createdAt.toLocal())}', style: TextStyle(color: textMuted, fontSize: 11)),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chevron_right, color: textMuted, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
