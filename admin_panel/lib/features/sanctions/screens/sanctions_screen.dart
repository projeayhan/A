import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../services/sanction_service.dart';

class SanctionsScreen extends ConsumerStatefulWidget {
  const SanctionsScreen({super.key});

  @override
  ConsumerState<SanctionsScreen> createState() => _SanctionsScreenState();
}

class _SanctionsScreenState extends ConsumerState<SanctionsScreen> {
  @override
  Widget build(BuildContext context) {
    final sanctionsAsync = ref.watch(sanctionsListProvider);

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
                      'Yaptırımlar ve Cezalar',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kural ihlali yapan kullanıcıları ve işletmeleri yönetin.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showBanDialog(context),
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: const Text('Yeni Yaptırım Uygula'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
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

            // Sanctions List
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
                        'Aktif Yaptırımlar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceLight),
                    Expanded(
                      child: sanctionsAsync.when(
                        data: (sanctions) {
                          if (sanctions.isEmpty) {
                            return const Center(
                              child: Text(
                                'Şu anda aktif bir yaptırım bulunmuyor.',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: sanctions.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: AppColors.surfaceLight,
                            ),
                            itemBuilder: (context, index) {
                              final item = sanctions[index];
                              final user =
                                  item['users'] ?? {'full_name': 'Bilinmiyor'};
                              final expiry = DateTime.parse(item['expires_at']);
                              final daysLeft = expiry
                                  .difference(DateTime.now())
                                  .inDays;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.error.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: const Icon(
                                    Icons.block,
                                    color: AppColors.error,
                                  ),
                                ),
                                title: Text(
                                  user['full_name'] ?? 'Kullanıcı',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Sebep: ${item['reason']}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bitiş: ${expiry.toString().split('T')[0]} ($daysLeft gün kaldı)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: TextButton(
                                  onPressed: () => _liftSanction(
                                    item['id'],
                                    item['user_id'],
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                  ),
                                  child: const Text('Yasağı Kaldır'),
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Hata: $err')),
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

  void _showBanDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const BanUserDialog());
  }

  Future<void> _liftSanction(String id, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: const Text('Bu kullanıcının yasağını kaldırmak üzeresiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(sanctionServiceProvider).liftSanction(id, userId);
      ref.invalidate(sanctionsListProvider);
    }
  }
}

// Provider
final sanctionsListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.read(sanctionServiceProvider).getActiveSanctions();
});

class BanUserDialog extends ConsumerStatefulWidget {
  const BanUserDialog({super.key});

  @override
  ConsumerState<BanUserDialog> createState() => _BanUserDialogState();
}

class _BanUserDialogState extends ConsumerState<BanUserDialog> {
  final _searchController = TextEditingController();
  final _reasonController = TextEditingController();
  final _daysController = TextEditingController(text: '7');

  Map<String, dynamic>? _foundUser;
  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Yaptırım Uygula'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Area
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı Ara (Email/Tel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _searchUser,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                ),
              ],
            ),

            if (_foundUser != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _foundUser!['full_name'] ?? 'İsimsiz',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _foundUser!['email'] ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Sebep',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _daysController,
                decoration: const InputDecoration(
                  labelText: 'Süre (Gün)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: (_foundUser != null && !_isSubmitting) ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Yasakla'),
        ),
      ],
    );
  }

  Future<void> _searchUser() async {
    setState(() => _isSearching = true);
    try {
      final user = await ref
          .read(sanctionServiceProvider)
          .searchUser(_searchController.text.trim());
      if (!mounted) return;
      setState(() {
        _foundUser = user;
        if (user == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kullanıcı bulunamadı')));
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _submit() async {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sebep giriniz')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(sanctionServiceProvider)
          .imposeSanction(
            userId: _foundUser!['id'],
            reason: _reasonController.text,
            durationDays: int.parse(_daysController.text),
            type: 'ban',
          );
      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(sanctionsListProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kullanıcı yasaklandı')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
